#!/bin/sh
#
# bash scripts/local_db/run_local_db_docker.sh
# 2023-05-21 | CR
#

exit_abort() {
    echo ""
    echo "Aborting..."
    echo ""
    bash ${SCRIPTS_DIR}/../show_date_time.sh
    exit 1
}

load_envs() {
    if ! cd "${REPO_BASEDIR}"
    then
        echo "Could not change directory to: ${REPO_BASEDIR}"
        exit_abort
    fi
    echo ""
    echo "Reading '${REPO_BASEDIR}/.env'..."
    echo ""
    if [ -f "${REPO_BASEDIR}/.env" ]; then
        set -o allexport; . "${REPO_BASEDIR}/.env"; set +o allexport ;
    fi
    if [ "${APP_NAME}" = "" ]; then
        echo "APP_NAME environment variable must be set"
        exit_abort
    fi
    if [ "${CURRENT_FRAMEWORK}" = "" ]; then
        echo "CURRENT_FRAMEWORK environment variable must be set"
        exit_abort
    fi
    if [ "${APP_DB_ENGINE_DEV}" = "" ]; then
        echo "APP_DB_ENGINE_DEV environment variable must be set"
        exit_abort
    fi
}

docker_dependencies() {
    if ! source "${SCRIPTS_DIR}/../container_engine_manager.sh" start "${CONTAINERS_ENGINE}" "${OPEN_CONTAINERS_ENGINE_APP}"
    then
        echo ""
        echo "Could not run container engine '${CONTAINERS_ENGINE}' automatically"
        exit_abort
    fi

    if [ "${DOCKER_WAS_NOT_RUNNING}" = "1" ]; then
        # If docker is not running, the tables must be created
        CREATE_TABLES="1"
    fi

    if [ -z "${DOCKER_CMD}" ]; then
        echo ""
        echo "DOCKER_CMD is not set"
        echo ""
        exit_abort
    fi
}

set_all_profiles() {
    DOCKER_COMPOSE_PROFILE="--profile mongodb --profile dynamodb --profile postgres --profile mysql"
}

unmount_databases() {
    echo "Starting MongoDb local docker container unmount..."
    set_all_profiles
    echo "${DOCKER_COMPOSE_CMD} ${DOCKER_COMPOSE_PROFILE} -f ${SCRIPTS_DIR}/local_db_stack.yml down"
    if ${DOCKER_COMPOSE_CMD} ${DOCKER_COMPOSE_PROFILE} -f "${SCRIPTS_DIR}/local_db_stack.yml" down
    then
        echo "Databases local docker containers UNMOUNTED successfully"
    else
        echo "ERROR: could not unmount the databases local docker containers"
        exit_abort
    fi
}

database_docker_shut_down() {
    echo ""
    echo "Shutting down the database containers to fix errors on the next run"
    echo ""
    unmount_databases
}

check_docker_compose_is_running() {
    DOCKER_COMPOSE_RUNNING="0"
    set_all_profiles
    if ${DOCKER_COMPOSE_CMD} ${DOCKER_COMPOSE_PROFILE} -f ${SCRIPTS_DIR}/local_db_stack.yml ps
    then
        DOCKER_COMPOSE_RUNNING="1"
    fi
}

check_database_container_is_running() {
    set_all_profiles
    RESTART_DOCKER_COMPOSE="0"
    if [ "${APP_DB_ENGINE_DEV}" == "MONGODB" ]; then
        if ! ${DOCKER_COMPOSE_CMD} ${DOCKER_COMPOSE_PROFILE} -f ${SCRIPTS_DIR}/local_db_stack.yml ps | grep mongo-db
        then
            echo "MongoDb docker container is not running..."
            RESTART_DOCKER_COMPOSE="1"
        fi
    fi
    if [ "${APP_DB_ENGINE_DEV}" == "DYNAMODB" ]; then
        if ! ${DOCKER_COMPOSE_CMD} ${DOCKER_COMPOSE_PROFILE} -f ${SCRIPTS_DIR}/local_db_stack.yml ps | grep dynamodb-local
        then
            echo "DynamoDB docker container is not running..."
            RESTART_DOCKER_COMPOSE="1"
        fi
    fi
    if [ "${APP_DB_ENGINE_DEV}" == "POSTGRES" ]; then
        if ! ${DOCKER_COMPOSE_CMD} ${DOCKER_COMPOSE_PROFILE} -f ${SCRIPTS_DIR}/local_db_stack.yml ps | grep postgres-local
        then
            echo "Posgres docker container is not running..."
            RESTART_DOCKER_COMPOSE="1"
        fi
    fi
    if [ "${APP_DB_ENGINE_DEV}" == "MYSQL" ]; then
        if ! ${DOCKER_COMPOSE_CMD} ${DOCKER_COMPOSE_PROFILE} -f ${SCRIPTS_DIR}/local_db_stack.yml ps | grep mysql-local
        then
            echo "MySQL docker container is not running..."
            RESTART_DOCKER_COMPOSE="1"
        fi
    fi
}

set_profiles() {
    DOCKER_COMPOSE_PROFILE=""
    if [ "${APP_DB_ENGINE_DEV}" == "MONGODB" ]; then
        DOCKER_COMPOSE_PROFILE="--profile mongodb"
    elif [ "${APP_DB_ENGINE_DEV}" == "DYNAMODB" ]; then
        DOCKER_COMPOSE_PROFILE="--profile dynamodb"
    elif [ "${APP_DB_ENGINE_DEV}" == "POSTGRES" ]; then
        DOCKER_COMPOSE_PROFILE="--profile postgres"
    elif [ "${APP_DB_ENGINE_DEV}" == "MYSQL" ]; then
        DOCKER_COMPOSE_PROFILE="--profile mysql"
    else
        echo "APP_DB_ENGINE_DEV environment variable must be set to 'MONGODB', 'DYNAMODB', 'POSTGRES' or 'MYSQL'. Now it is set to '${APP_DB_ENGINE_DEV}'"
        exit_abort
    fi
}

run_docker_compose() {
    echo ""
    echo "Starting docker compose..."
    echo ""
    set_profiles
    if ! ${DOCKER_COMPOSE_CMD} ${DOCKER_COMPOSE_PROFILE} -f ${SCRIPTS_DIR}/local_db_stack.yml up -d
    then
        echo "ERROR: could not start database docker compose"
        exit_abort
    fi
}

start_docker_containers() {
    check_docker_compose_is_running

    if [ "${DOCKER_COMPOSE_RUNNING}" = "0" ]; then
        run_docker_compose
        CREATE_TABLES="1"
    fi

    check_database_container_is_running

    if [ "${RESTART_DOCKER_COMPOSE}" = "1" ]; then
        database_docker_shut_down
        run_docker_compose
        CREATE_TABLES="1"
    fi

    echo ""
    echo "Database docker container started successfully."
    echo ""
}

database_docker_restart() {
    database_docker_shut_down
    start_docker_containers
}

verify_docker_containers() {
    # Verify if MongoDB local container is running to avoid re-loading

    if [ "${APP_DB_ENGINE_DEV}" == "MONGODB" ]; then
        if ! ${DOCKER_CMD} ps | grep mongo-db -q
        then
            ERROR="ERROR: Failed to start the local Docker MongoDB database container"
            echo ""
            echo "For some reason, the local Docker MongoDB database container is not running."
            echo "The logs are:"
            ${DOCKER_CMD} logs mongo-db
            database_docker_restart
        fi
    fi
    
    # Verify local DynamoDb container is started

    if [ "${APP_DB_ENGINE_DEV}" == "DYNAMODB" ]; then
        if ! ${DOCKER_CMD} ps | grep dynamodb-local -q
        then
            ERROR="ERROR: Failed to start the local Docker DynamoDB database container"
            echo ""
            echo "For some reason, the local Docker DynamoDB database container is not running."
            echo "The logs are:"
            ${DOCKER_CMD} logs dynamodb-local
            database_docker_restart
        fi
    fi

    # Verify local Postgres container is started

    if [ "${APP_DB_ENGINE_DEV}" == "POSTGRES" ]; then
        if ! ${DOCKER_CMD} ps | grep postgres-local -q
        then
            ERROR="ERROR: Failed to start the local Docker Postgres database container"
            echo ""
            echo "For some reason, the local Docker Postgres database container is not running."
            echo "The logs are:"
            ${DOCKER_CMD} logs postgres-local
            database_docker_restart
        fi
    fi

    # Verify local MySQL container is started

    if [ "${APP_DB_ENGINE_DEV}" == "MYSQL" ]; then
        if ! ${DOCKER_CMD} ps | grep mysql-local -q
        then
            ERROR="ERROR: Failed to start the local Docker MySQL database container"
            echo ""
            echo "For some reason, the local Docker MySQL database container is not running."
            echo "The logs are:"
            ${DOCKER_CMD} logs mysql-local
            database_docker_restart
        fi
    fi
}

create_tables() {
    if [ "${APP_DB_ENGINE_DEV}" == "MONGODB" ]; then
        echo ""
        echo "MongoDB does not need to create tables"
        echo ""
    fi
    if [ "${APP_DB_ENGINE_DEV}" == "DYNAMODB" ]; then
        echo ""
        echo "Creating DynamoDB tables on the Dev environment..."
        echo ""
        if ! bash ${SCRIPTS_DIR}/../aws_dynamodb/generate_dynamodb_cf/generate_dynamodb_cf.sh create_tables dev
        then
            echo "ERROR: running 'bash ${SCRIPTS_DIR}/../aws_dynamodb/generate_dynamodb_cf/generate_dynamodb_cf.sh create_tables dev'"
            exit_abort
        fi
    fi
    if [ "${APP_DB_ENGINE_DEV}" == "POSTGRES" ] || [ "${APP_DB_ENGINE_DEV}" == "MYSQL" ]; then
        echo ""
        echo "Creating Postgres tables on the Dev environment..."
        echo ""
        if ! DB_TYPE=${APP_DB_ENGINE_DEV} bash ${SCRIPTS_DIR}/../sql_db/generate_sql_db_cf/generate_sql_db_cf.sh create_tables dev
        then
            echo "ERROR: running 'DB_TYPE=${APP_DB_ENGINE_DEV} bash ${SCRIPTS_DIR}/../sql_db/generate_sql_db_cf/generate_sql_db_cf.sh create_tables dev'"
            exit_abort
        fi
    fi
}

show_docker_logs() {
    echo "Starting MongoDb local docker container logs..."
    echo "${DOCKER_COMPOSE_CMD} -f ${SCRIPTS_DIR}/local_db_stack.yml logs"
    ${DOCKER_COMPOSE_CMD} -f "${SCRIPTS_DIR}/local_db_stack.yml" logs -f
}

run_app() {
    export APP_DB_NAME=mongo
    export APP_DB_URI=mongodb://root:example@127.0.0.1:27017/
    ${DOCKER_CMD} ps ;

    echo ""
    echo "Starting Lambda configuration for local database on docker..."
    echo ""
    if bash ${SCRIPTS_DIR}/../aws/set_chalice_cnf.sh local_db_docker
    then
        echo ""
        echo "Lambda configuration for local database on docker ran successfully."
        echo ""
    else
        echo "ERROR: running 'bash ${SCRIPTS_DIR}/../aws/set_chalice_cnf.sh'"
        exit_abort
    fi

    if [ "${RUN_LOCAL_APP}" = "1" ]; then
        echo "Starting ${APP_NAME} API over local database on docker..."
        echo ""
        if [ "${CREATE_TABLES}" = "1" ]; then
            echo ""
            echo "--------------------------------------------------------------------"
            echo "WARNING:"
            echo ""
            echo "Once the app startup finishes, please remember to perform the Super"
            echo "Admin user creation by opening a different terminal and running:"
            echo "  STAGE=${STAGE} make create-supad"
            echo ""
            echo "Press Enter to continue the app startup..."
            echo "--------------------------------------------------------------------"
            read
        fi
        # make run
        bash ${SCRIPTS_DIR}/../aws/run_aws.sh run_local
    fi
}

# Main

ERROR=""

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"

ACTION="$1"

if [ "${RUN_LOCAL_APP}" = "" ]; then
    RUN_LOCAL_APP="$2"
fi
if [ "${RUN_LOCAL_APP}" = "" ]; then
    # The local app needs to be started by the tests with "make run"
    # to use the local docker mongo database, so RUN_LOCAL_APP
    # or $2 parameter must be "1". Defaults to "0"
    RUN_LOCAL_APP="0"
fi

if [ "${STAGE}" = "" ]; then
    STAGE="$3"
fi

echo ""
echo "ACTION: ${ACTION}"
echo "RUN_LOCAL_APP: ${RUN_LOCAL_APP}"
echo "STAGE: ${STAGE}"

load_envs

CREATE_TABLES="0"

if [ "${ACTION}" == "" ] || [ "${ACTION}" == "up" ] || [ "${ACTION}" == "run" ]; then
    docker_dependencies
    start_docker_containers
    verify_docker_containers
    if [ "${STAGE}" == "dev" ]; then
        if [ "${CREATE_TABLES}" == "1" ]; then
            create_tables
        fi
    fi
    run_app

elif [ "${ACTION}" == "logs" ]; then
    docker_dependencies
    show_docker_logs

elif [ "${ACTION}" == "down" ]; then
    docker_dependencies
    unmount_databases

else
    echo "ERROR: Invalid action: ${ACTION}"
    exit_abort
fi

echo "Database docker container processing done"
bash ${SCRIPTS_DIR}/../show_date_time.sh
