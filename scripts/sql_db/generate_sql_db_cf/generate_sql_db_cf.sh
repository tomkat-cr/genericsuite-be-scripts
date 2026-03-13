#!/bin/sh
# generate_sql_db_cf.sh
# 2025-11-30 | CR
# Generates the PostgreSQL tables SQL files.
#
# Usage:
# sh scripts/sql_db/generate_sql_db_cf/generate_sql_db_cf.sh
#    or
# DB_TYPE=mysql ACTION=generate STAGE=dev make generate_cf_sql_db
#    or
# DB_TYPE=postgres ACTION=generate STAGE=dev make generate_cf_sql_db

yes_or_no() {
  read choice
  while [[ ! $choice =~ ^[YyNn]$ ]]; do
    echo "Please enter Y or N"
    read choice
  done
}

exit_abort() {
    echo ""
    echo "Fix the error and try again by running:"
    echo "  STAGE=${STAGE} ACTION=create_tables make generate_cf_${DB_TYPE}"
    echo ""
    exit 1
}

docker_dependencies() {
    if ! source "${SCRIPTS_DIR}/../../container_engine_manager.sh" start "${CONTAINERS_ENGINE}" "${OPEN_CONTAINERS_ENGINE_APP}"
    then
        echo ""
        echo "Could not run container engine '${CONTAINERS_ENGINE}' automatically"
        echo ""
        exit_abort
    fi

    if [ -z "${DOCKER_CMD}" ]; then
        echo ""
        echo "DOCKER_CMD is not set"
        echo ""
        exit_abort
    fi
}

if [ "${ACTION}" = "" ]; then
    ACTION="$1"
fi
if [ "${STAGE}" = "" ]; then
    STAGE="$2"
fi
if [ "$3" != "" ]; then
    DB_TYPE="$3"
fi

if [ "${ACTION}" = "" ] || [ "${ACTION}" = "start" ]; then
    # "generate": generate the PostgreSQL SQL files.
    # "create_tables": create the tables in the local Docker PostgreSQL instance.
    ACTION="create_tables"
fi

if [ "${DB_TYPE}" = "" ]; then
    echo "ERROR: DB_TYPE not set. Options: POSTGRES, MYSQL"
    exit_abort
fi
DB_TYPE=$(echo "${DB_TYPE}" | tr '[:upper:]' '[:lower:]')
if [ "${DB_TYPE}" != "postgres" ] && [ "${DB_TYPE}" != "mysql" ]; then
    echo "ERROR: DB_TYPE '${DB_TYPE}' is not valid. Options: postgres, mysql"
    exit_abort
fi

IDE_COMMAND="code"

GT_ACTION=${ACTION}
GT_STAGE=$(echo ${STAGE} | tr '[:upper:]' '[:lower:]')
GT_DB_TYPE=${DB_TYPE}

set -o allexport; . .env ; set +o allexport ;

echo ""
echo "Generating PostgreSQL tables"
echo ""
echo "GT_ACTION: ${GT_ACTION}"
echo "GT_STAGE: ${GT_STAGE}"
echo "GT_DB_TYPE: ${DB_TYPE}"
echo "IDE (code editor): ${IDE_COMMAND}"
echo ""

STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')
APP_DB_ENGINE=$(eval echo \$APP_DB_ENGINE_${STAGE_UPPERCASE})
if [ "${APP_DB_ENGINE}" = "" ]; then
    echo "ERROR: APP_DB_ENGINE_${STAGE_UPPERCASE} not set"
    exit_abort
fi
DB_TYPE_UPPERCASE=$(echo ${DB_TYPE} | tr '[:lower:]' '[:upper:]')
if [ "${APP_DB_ENGINE}" != ${DB_TYPE_UPPERCASE} ]; then
    if [ "${APP_DB_ENGINE}" = "SUPABASE" ] && [ ${DB_TYPE_UPPERCASE} != "POSTGRES" ]; then
        echo "ERROR: APP_DB_ENGINE_${STAGE_UPPERCASE} (${APP_DB_ENGINE}) is not equal to DB_TYPE (${DB_TYPE_UPPERCASE})"
        exit_abort
    fi
fi

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`" ;
SCRIPTS_DIR="`pwd`" ;

WORKING_DIR="/tmp/generate_sql_db_cf"
mkdir -p "${WORKING_DIR}"

BASE_CONFIG_PATH="${GIT_SUBMODULE_LOCAL_PATH}"
if [ "${BASE_CONFIG_PATH}" = "" ]; then
    echo 'GIT_SUBMODULE_LOCAL_PATH environment variable not set'
    exit_abort
fi
BASE_CONFIG_PATH="${REPO_BASEDIR}/${BASE_CONFIG_PATH}"

echo ""
echo "BASE_CONFIG_PATH: ${BASE_CONFIG_PATH}"
echo ""

if [ "${APP_NAME}" = "" ]; then
    echo 'ERROR: 'APP_NAME' environment variable not set'
    exit_abort
fi

if [ "${GT_ACTION}" = "create_tables" ]; then
    if [ "${GT_STAGE}" = "" ]; then
        echo 'ERROR: 'STAGE' environment variable must be set to run the '${GT_ACTION}' action (dev, qa, staging, demo, prod)'
        exit_abort
    fi
    if [ "${AWS_REGION}" = "" ]; then
        echo 'ERROR: 'AWS_REGION' environment variable must be set to run the '${GT_ACTION}' action'
        exit_abort
    fi
    if [ "${APP_DB_ENGINE}" = "SUPABASE" ]; then
        echo "NOTICE: the procedure to create tables on Supabase is not implemented"
        echo "I can give to the SQL script to create the tables and you must run it manually"
        echo "on the Supabase UI. Do you want to proceed ? (y/n)"
        read USER_ANSWER
        USER_ANSWER=$(echo ${USER_ANSWER} | tr '[:upper:]' '[:lower:]')
        if [ "${USER_ANSWER}" = "n" ]; then
            exit_abort
        fi
        GT_ACTION="generate"
    fi
fi

if [ "${GT_STAGE}" = "dev" ]; then
    docker_dependencies
fi

echo ""
echo "Creating virtual environment"
echo ""
python -m venv venv
. venv/bin/activate

echo ""
echo "Installing dependencies"
echo ""
if [ ! -f requirements.txt ]; then
    if ! pip install --upgrade pip
    then
        echo "Error running: pip install --upgrade pip"
        exit_abort
    fi
    if ! pip install pyyaml psycopg2-binary mysql-connector-python
    then
        echo "Error running: pip install pyyaml psycopg2-binary mysql-connector-python"
        exit_abort
    fi

    if ! pip freeze > requirements.txt
    then
        echo "Error running: pip freeze > requirements.txt"
        exit_abort
    fi
else
    if ! pip install -r requirements.txt
    then
        echo "Error running: pip install -r requirements.txt"
        exit_abort
    fi
fi

APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
CF_TEMPLATE_NAME="tables_creation.sql"
FINAL_TARGET_DIR="${REPO_BASEDIR}/scripts/sql_db"

POSTGRES_PREFIX=$(eval echo \$POSTGRES_PREFIX_${STAGE_UPPERCASE})
if [ "${POSTGRES_PREFIX}" = "" ]; then
    POSTGRES_PREFIX="${APP_NAME_LOWERCASE}_${GT_STAGE}_"
fi

ERROR="0"
DONE="0"

if [ "${GT_ACTION}" = "generate" ]; then
    # "generate": generate the SQL script file.
    if ! python -m generate_sql_db_cf "${BASE_CONFIG_PATH}" "${WORKING_DIR}/${CF_TEMPLATE_NAME}" "" "0" "${DB_TYPE}" "${STAGE_UPPERCASE}"
    then
        # We need to postpone the error reporting to remove __pycache__ and venv every time the python code is executed.
        ERROR="1"
    else
        # This report a valid action.
        DONE="1"
    fi
fi

if [ "${GT_ACTION}" = "create_tables" ]; then
    # "create_tables": create the tables in the local Docker postgres instance.

    if [ "${GT_STAGE}" = "dev" ]; then
        # Verify if postgres local container is running to avoid cycling "make local-db-up" call
        if ! ${DOCKER_CMD} ps | grep postgres-local -q
        then
            cd "${REPO_BASEDIR}"
            if ! make local-db-up
            then
                echo ""
                echo "ERROR: Failed to start the local Docker databases container"
                exit_abort
            fi
            # Wait for the database to be ready
            if [ "${DB_TYPE}" = "postgres" ]; then
                ${DOCKER_CMD} exec -it postgres-local psql -U user -d pass -h localhost -p 5432 -d db -c "SELECT 1;"
            elif [ "${DB_TYPE}" = "mysql" ]; then
                ${DOCKER_CMD} exec -i mysql-local mysql -uroot -ppass -h localhost -P 3306 db -e "SELECT 1;"
            fi
        fi
    fi

    cd "${SCRIPTS_DIR}"
    if ! python -m generate_sql_db_cf "${BASE_CONFIG_PATH}" "${WORKING_DIR}/${CF_TEMPLATE_NAME}" "${POSTGRES_PREFIX}" "1" "${DB_TYPE}" "${STAGE_UPPERCASE}"
    then
        # We need to postpone the error reporting to remove __pycache__ and venv every time the python code is executed.
        ERROR="1"
    else
        # This report a valid action.
        DONE="1"
    fi
fi

deactivate
rm -rf __pycache__
rm -rf venv

if [ "${GT_ACTION}" = "generate" ]; then
    if [ "${ERROR}" = "1" ]; then
        echo ""
        echo "ERROR: Failed to generate SQL script file"
    else
        # For supabase, append the "../create_supabase_tables_tail.sql" file
        if [ "${APP_DB_ENGINE}" = "SUPABASE" ]; then
            cat "${SCRIPTS_DIR}/../create_supabase_tables_tail.sql" >> "${WORKING_DIR}/${CF_TEMPLATE_NAME}"
        fi

        echo ""
        echo "Generated SQL script file in:"
        echo "${WORKING_DIR}/${CF_TEMPLATE_NAME}"
        echo ""
        echo "Do you want to edit it (y/n)?"
        yes_or_no

        if [[ $choice =~ ^[Yy]$ ]]; then
            echo "Opening IDE (${IDE_COMMAND})..."
            if ! ${IDE_COMMAND} "${WORKING_DIR}/${CF_TEMPLATE_NAME}"
            then
                if ! nano "${WORKING_DIR}/${CF_TEMPLATE_NAME}"
                then
                    if ! vi "${WORKING_DIR}/${CF_TEMPLATE_NAME}"
                    then
                        echo "ERROR: Failed to open editor"
                        exit 1
                    fi
                fi
            fi
        fi

        echo ""
        echo "Copy to final destination:"
        echo "From: ${WORKING_DIR}/${CF_TEMPLATE_NAME}"
        echo "To: ${FINAL_TARGET_DIR}/${CF_TEMPLATE_NAME}"
        echo ""
        echo "Do you want to perform the copy (y/n)?"
        yes_or_no

        if [[ $choice =~ ^[Yy]$ ]]; then
            echo "Copying..."
            if ! mkdir -p "${FINAL_TARGET_DIR}"
            then
                echo "Failed to create directory: ${FINAL_TARGET_DIR}"
            else
                if [ -f "${FINAL_TARGET_DIR}/${CF_TEMPLATE_NAME}" ]
                then
                    echo "File already exists. Overwrite (y/n)"
                    yes_or_no
                    if [[ $choice =~ ^[Yy]$ ]]; then
                        if ! cp "${WORKING_DIR}/${CF_TEMPLATE_NAME}" "${FINAL_TARGET_DIR}/"
                        then
                            echo "ERROR: Failed to copy file [1]"
                        fi
                    else
                        echo "Skipping copy."
                    fi
                else
                    if ! cp "${WORKING_DIR}/${CF_TEMPLATE_NAME}" "${FINAL_TARGET_DIR}/"
                    then
                        echo "ERROR: Failed to copy file [2]"
                    fi
                fi
            fi
        fi
    fi
fi

if [ "${GT_ACTION}" = "create_tables" ]; then
    if [ "${ERROR}" = "1" ]; then
        echo ""
        echo "ERROR: Failed to generate the Database tables in the local environment (${DB_TYPE})"
        exit_abort
    else
        echo ""
        echo "Generated Database tables in the local environment (${DB_TYPE})"
        echo ""
        if [ "${DB_TYPE}" = "postgres" ]; then
            ${DOCKER_CMD} exec -it postgres-local psql -U user -d pass -h localhost -p 5432 -d db -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public'"
        elif [ "${DB_TYPE}" = "mysql" ]; then
            ${DOCKER_CMD} exec -i mysql-local sh -c "echo \"SHOW TABLES;\" > /tmp/show_tables.sql && mysql -uroot -ppass -h localhost -P 3306 db < /tmp/show_tables.sql && rm /tmp/show_tables.sql"
        else
            echo "ERROR: DB_TYPE '${DB_TYPE}' not registered"
            exit_abort
        fi
    fi
fi

if [ "${ERROR}" = "0" ]; then
    echo ""
    if [ "${DONE}" = "1" ]; then
        echo "Done!"
    else
        echo "ERROR: Invalid ACTION '${GT_ACTION}'"
        exit_abort
    fi
fi
echo ""
