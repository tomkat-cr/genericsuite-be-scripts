#!/bin/sh
# generate_dynamodb_cf.sh
# 2024-05-21 | CR
# Generates the DynamoDB tables section for a SAM template.
# Usage:
# sh scripts/aws_dynamodb/generate_dynamodb_cf/generate_dynamodb_cf.sh
# ACTION=create_tables STAGE=dev make generate_cf_dynamodb

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

if [ "${ACTION}" = "" ]; then
    # "generate": generate the CloudFormation yaml file.
    # "create_tables": create the tables in the local Docker DynamoDB instance.
    ACTION="generate"
fi

set -o allexport; . .env ; set +o allexport ;

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`" ;
SCRIPTS_DIR="`pwd`" ;

WORKING_DIR="/tmp/generate_dynamodb_cf"
mkdir -p "${WORKING_DIR}"

docker_dependencies

python -m venv venv
. venv/bin/activate

if [ ! -f requirements.txt ]; then
    pip install pyyaml boto3 botocore
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

if [ "${APP_NAME}" = "" ]; then
    echo 'ERROR: 'APP_NAME' environment variable not set'
    exit 1
fi

if [ "${ACTION}" = "create_tables" ]; then
    if [ "${STAGE}" = "" ]; then
        echo 'ERROR: 'STAGE' environment variable must be set to run the '${ACTION}' action (dev, qa, staging, demo, prod)'
        exit 1
    fi
    if [ "${AWS_REGION}" = "" ]; then
        echo 'ERROR: 'AWS_REGION' environment variable must be set to run the '${ACTION}' action'
        exit 1
    fi
fi

APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
CF_TEMPLATE_NAME="cf-template-dynamodb.yml"
FINAL_TARGET_DIR="${REPO_BASEDIR}/scripts/aws_dynamodb"

STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:upper:]' '[:lower:]')
DYNAMDB_PREFIX=$(eval echo \$DYNAMDB_PREFIX_${STAGE_UPPERCASE})
if [ "${DYNAMDB_PREFIX}" = "" ]; then
    DYNAMDB_PREFIX="${APP_NAME_LOWERCASE}_${STAGE}_"
fi

ERROR="0"
DONE="0"
if [ "${ACTION}" = "generate" ]; then
    # "generate": generate the CloudFormation yaml file.
    if ! python -m generate_dynamodb_cf "${BASE_CONFIG_PATH}" "${WORKING_DIR}/${CF_TEMPLATE_NAME}" "" "0"
    then
        # We need to postpone the error reporting to remove __pycache__ and venv every time the python code is executed.
        ERROR="1"
    else
        # This report a valid action.
        DONE="1"
    fi
fi
if [ "${ACTION}" = "create_tables" ]; then
    # "create_tables": create the tables in the local Docker DynamoDB instance.
    
    # Verify if DynamoDB local container is running to avoid cycling "make mongo_docker" call
    if ! ${DOCKER_CMD} ps | grep dynamodb-local -q
    then
        cd "${REPO_BASEDIR}"
        if ! make mongo_docker
        then
            echo ""
            echo "ERROR: Failed to start the local Docker databases container"
            exit 1
        fi
    fi

    cd "${SCRIPTS_DIR}"
    if ! python -m generate_dynamodb_cf "${BASE_CONFIG_PATH}" "${WORKING_DIR}/${CF_TEMPLATE_NAME}" "${DYNAMDB_PREFIX}" "1"
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

if [ "${ACTION}" = "generate" ]; then
    if [ "${ERROR}" = "1" ]; then
        echo ""
        echo "ERROR: Failed to generate SAM template file"
    else
        echo ""
        echo "Generated SAM template file in:"
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

if [ "${ACTION}" = "create_tables" ]; then
    if [ "${ERROR}" = "1" ]; then
        echo ""
        echo "ERROR: Failed to generate the DynamoDB tables in the local environment"
    else
        echo ""
        echo "Generated DynamoDB tables in the local environment:"
        echo ""
        ENDPOINT_URL="${DYNAMODB_LOCAL_ENDPOINT_URL}"
        if [ "${ENDPOINT_URL}" = "" ]; then
            ENDPOINT_URL="http://127.0.0.1:8000"
        fi
        aws dynamodb list-tables --endpoint-url ${ENDPOINT_URL} --region ${AWS_REGION} | jq
    fi
fi

if [ "${ERROR}" = "0" ]; then
    echo ""
    if [ "${DONE}" = "1" ]; then
        echo "Done!"
    else
        echo "ERROR: Invalid ACTION '${ACTION}'"
    fi
fi
echo ""
