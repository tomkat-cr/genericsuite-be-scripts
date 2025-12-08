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

docker_dependencies() {
    if ! source "${SCRIPTS_DIR}/../../container_engine_manager.sh" start "${CONTAINERS_ENGINE}" "${OPEN_CONTAINERS_ENGINE_APP}"
    then
        echo ""
        echo "Could not run container engine '${CONTAINERS_ENGINE}' automatically"
        echo ""
        exit 1
    fi

    if [ -z "${DOCKER_CMD}" ]; then
        echo ""
        echo "DOCKER_CMD is not set"
        echo ""
        exit 1
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

if [ "${ACTION}" = "" ]; then
    # "generate": generate the PostgreSQL SQL files.
    # "create_tables": create the tables in the local Docker PostgreSQL instance.
    ACTION="create_tables"
fi

if [ "${DB_TYPE}" = "" ]; then
    echo "ERROR: DB_TYPE not set. Options: postgres, mysql"
    exit_abort
fi

GT_ACTION=${ACTION}
GT_STAGE=${STAGE}

echo ""
echo "Generating PostgreSQL tables"
echo ""
echo "GT_ACTION: ${GT_ACTION}"
echo "GT_STAGE: ${GT_STAGE}"
echo "DB_TYPE: ${DB_TYPE}"
echo ""

set -o allexport; . .env ; set +o allexport ;

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`" ;
SCRIPTS_DIR="`pwd`" ;

WORKING_DIR="/tmp/generate_sql_db_cf"
mkdir -p "${WORKING_DIR}"

docker_dependencies

echo ""
echo "Creating virtual environment"
echo ""
python -m venv venv
. venv/bin/activate

echo ""
echo "Installing dependencies"
echo ""
if [ ! -f requirements.txt ]; then
    pip install pyyaml psycopg2-binary mysql-connector-python
    pip freeze > requirements.txt
else
    pip install -r requirements.txt
fi

BASE_CONFIG_PATH="${GIT_SUBMODULE_LOCAL_PATH}"
if [ "${BASE_CONFIG_PATH}" = "" ]; then
    echo 'GIT_SUBMODULE_LOCAL_PATH environment variable not set'
    exit 1
fi
BASE_CONFIG_PATH="${REPO_BASEDIR}/${BASE_CONFIG_PATH}"

echo ""
echo "BASE_CONFIG_PATH: ${BASE_CONFIG_PATH}"
echo ""

if [ "${APP_NAME}" = "" ]; then
    echo 'ERROR: 'APP_NAME' environment variable not set'
    exit 1
fi

if [ "${GT_ACTION}" = "create_tables" ]; then
    if [ "${GT_STAGE}" = "" ]; then
        echo 'ERROR: 'STAGE' environment variable must be set to run the '${GT_ACTION}' action (dev, qa, staging, demo, prod)'
        exit 1
    fi
    if [ "${AWS_REGION}" = "" ]; then
        echo 'ERROR: 'AWS_REGION' environment variable must be set to run the '${GT_ACTION}' action'
        exit 1
    fi
fi

APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
CF_TEMPLATE_NAME="cf-template-postgres.yml"
FINAL_TARGET_DIR="${REPO_BASEDIR}/scripts/sql_db"

STAGE_UPPERCASE=$(echo ${GT_STAGE} | tr '[:upper:]' '[:lower:]')
POSTGRES_PREFIX=$(eval echo \$POSTGRES_PREFIX_${STAGE_UPPERCASE})
if [ "${POSTGRES_PREFIX}" = "" ]; then
    POSTGRES_PREFIX="${APP_NAME_LOWERCASE}_${GT_STAGE}_"
fi

ERROR="0"
DONE="0"
if [ "${GT_ACTION}" = "generate" ]; then
    # "generate": generate the CloudFormation yaml file.
    if ! python -m generate_sql_db_cf "${BASE_CONFIG_PATH}" "${WORKING_DIR}/${CF_TEMPLATE_NAME}" "" "0" "${DB_TYPE}"
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
    
    # Verify if postgres local container is running to avoid cycling "make local-db-up" call
    if ! ${DOCKER_CMD} ps | grep postgres-local -q
    then
        cd "${REPO_BASEDIR}"
        if ! make local-db-up
        then
            echo ""
            echo "ERROR: Failed to start the local Docker databases container"
            exit 1
        fi
    fi

    cd "${SCRIPTS_DIR}"
    if ! python -m generate_sql_db_cf "${BASE_CONFIG_PATH}" "${WORKING_DIR}/${CF_TEMPLATE_NAME}" "${POSTGRES_PREFIX}" "1" "${DB_TYPE}"
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
        echo "ERROR: Failed to generate CloudFormation/SQL template file"
    else
        echo ""
        echo "Generated CloudFormation/SQL template file in:"
        echo "${WORKING_DIR}/${CF_TEMPLATE_NAME}"
        echo ""
        echo "Do you want to edit it (y/n)?"
        yes_or_no

        if [[ $choice =~ ^[Yy]$ ]]; then
            echo "Opening editor..."
            if ! code "${WORKING_DIR}/${CF_TEMPLATE_NAME}"
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
    else
        echo ""
        echo "Generated Database tables in the local environment (${DB_TYPE})"
        echo ""
        ENDPOINT_URL="${POSTGRES_URI}"
        if [ "${ENDPOINT_URL}" = "" ]; then
            ENDPOINT_URL="postgresql://user:pass@localhost:5432/db"
        fi
        docker exec -it postgres-local psql -U user -d pass -h localhost -p 5432 -d db -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public'"
    fi
fi

if [ "${ERROR}" = "0" ]; then
    echo ""
    if [ "${DONE}" = "1" ]; then
        echo "Done!"
    else
        echo "ERROR: Invalid ACTION '${GT_ACTION}'"
    fi
fi
echo ""
