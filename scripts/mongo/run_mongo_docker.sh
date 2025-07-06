#!/bin/sh
#
# sh scripts/mongo/run_mongo_docker.sh
# 2023-05-21 | CR
#

exit_abort() {
    echo ""
    echo "Aborting..."
    echo ""
    sh ${SCRIPTS_DIR}/../show_date_time.sh
    exit 1
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

    if [ "${DOCKER_CMD}" = "" ]; then
        echo ""
        echo "DOCKER_CMD is not set"
        echo ""
        exit 1
    fi
}

ERROR=""

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
#
ACTION="$1"
#
if [ "${RUN_LOCAL_APP}" = "" ]; then
    RUN_LOCAL_APP="$2"
fi
if [ "${RUN_LOCAL_APP}" = "" ]; then
    # The local app needs to be started by the tests with "make run"
    # to use the local docker mongo database, so RUN_LOCAL_APP
    # or $2 parameter must be "1". Defaults to "0"
    RUN_LOCAL_APP="0"
fi
#
if [ "${STAGE}" = "" ]; then
    STAGE="$3"
fi
#
echo ""
echo "ACTION: ${ACTION}"
echo "RUN_LOCAL_APP: ${RUN_LOCAL_APP}"
echo "STAGE: ${STAGE}"
#
if cd "${REPO_BASEDIR}"
then
    # REPO_BASEDIR="`pwd`" ;
    echo ""
    echo "Reading '${REPO_BASEDIR}/.env'..."
    echo ""
    if [ -f "${REPO_BASEDIR}/.env" ]; then
        set -o allexport; . "${REPO_BASEDIR}/.env"; set +o allexport ;
    fi
    #
    if [ "${APP_NAME}" = "" ]; then
        echo "APP_NAME environment variable must be defined"
        exit 1
    fi
    if [ "${CURRENT_FRAMEWORK}" = "" ]; then
        echo "CURRENT_FRAMEWORK environment variable must be defined"
        exit 1
    fi
else
    ERROR="Could not change directory to: ${REPO_BASEDIR}"
fi

CREATE_TABLES="0"

#
if [ "${ACTION}" == "" ] || [ "${ACTION}" == "up" ] || [ "${ACTION}" == "run" ]; then
    if [ "${ERROR}" == "" ]; then
        # Verify if Docker Destop is running
        docker_dependencies
        # Verify if MongoDB local container is running to avoid re-loading
        if ${DOCKER_CMD} ps | grep mongo-db -q
        then
            echo ""
            echo "MongoDb docker container was already started..."
            echo ""
        else
            # Start local dev database docker containers
            echo ""
            echo "Starting MongoDb docker container..."
            echo ""
            if ${DOCKER_COMPOSE_CMD} -f ${SCRIPTS_DIR}/mongodb_stack_for_test.yml up -d
            then
                echo ""
                echo "MongoDb docker container started successfully."
                echo ""
                export APP_DB_NAME=mongo
                export APP_DB_URI=mongodb://root:example@127.0.0.1:27017/
                ${DOCKER_CMD} ps ;
                CREATE_TABLES="1"
            else
                ERROR="ERROR: could not start mongo docker container" ;
            fi
            # Chalice specific setup
            if [ "${ERROR}" == "" ]; then
                echo ""
                echo "Starting Lambda configuration for local MongoDb on docker..."
                echo ""
                if sh ${SCRIPTS_DIR}/../aws/set_chalice_cnf.sh mongo_docker
                then
                    echo ""
                    echo "Lambda configuration for local MongoDb on docker ran successfully."
                    echo ""
                else
                    ERROR="ERROR: running ${SCRIPTS_DIR}/../aws/set_chalice_cnf.sh"
                fi
            fi
            #
            if [ "${ERROR}" == "" ]; then
                echo ""
                echo "Please remember to perform the 'supad-create'"
                echo ""
                if [ "${RUN_LOCAL_APP}" = "1" ]; then
                    echo "Starting ${APP_NAME} API over local MongoDb on docker..."
                    echo ""
                    if make run
                    then
                        echo "${APP_NAME} API over local MongoDb on docker ran successfully."
                    else
                        ERROR="ERROR: running ${REPO_BASEDIR}/make api"
                    fi
                fi
            fi
        fi
        # Verify local DynamoDb container is started
        if [ "${ERROR}" == "" ]; then
            if [ "${APP_DB_ENGINE_DEV}" == "DYNAMO_DB" ]; then
                if ! ${DOCKER_CMD} ps | grep dynamodb-local -q
                then
                    ERROR="ERROR: Failed to start the local Docker DynamoDB database container"
                    echo ""
                    echo "For some reason, the local Docker DynamoDB database container is not running."
                    echo "The logs are:"
                    ${DOCKER_CMD} logs dynamodb-local
                    echo ""
                    echo "Shutting down the databases container to fix this error on the next run"
                    echo ""
                    make mongo_docker_down
                fi
            fi
        fi
        # Create tables
        if [ "${ERROR}" == "" ]; then
            if [ "${STAGE}" == "dev" ]; then
                if [ "${CREATE_TABLES}" == "1" ]; then
                    if [ "${APP_DB_ENGINE_DEV}" == "DYNAMO_DB" ]; then
                        echo ""
                        echo "Creating DynamoDB tables on the Dev environment..."
                        echo ""
                        if ! sh ${SCRIPTS_DIR}/../aws_dynamodb/generate_dynamodb_cf/generate_dynamodb_cf.sh create_tables dev
                        then
                            ERROR="ERROR: running 'sh ${SCRIPTS_DIR}/../aws_dynamodb/generate_dynamodb_cf/generate_dynamodb_cf.sh create_tables dev'"
                            
                        fi
                    fi
                fi
            fi
        fi
    fi
fi
#
if [ "${ACTION}" == "down" ]; then
    if [ "${ERROR}" == "" ]; then
        echo "Starting MongoDb local docker container unmount..."
        echo "${DOCKER_COMPOSE_CMD} -f ${SCRIPTS_DIR}/mongodb_stack_for_test.yml down"
        if ${DOCKER_COMPOSE_CMD} -f "${SCRIPTS_DIR}/mongodb_stack_for_test.yml" down
        then
            ERROR="MongoDb local docker container UNMOUNTED successfully."
        fi
    fi
fi
#
if [ "${ERROR}" == "" ]; then
    echo "MongoDb docker container processing done."
else
    echo ${ERROR}
    exit 1
fi
