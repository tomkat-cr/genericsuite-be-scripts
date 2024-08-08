#!/bin/bash
# run-dynamodb-deploy.sh
# Create AWS DynamoDD tbles using AWS CloudFormation templates.
# 2024-07-14 | CR
# Usage:
# scripts/aws_dynamodb/run-dynamodb-deploy.sh ACTION TARGET STAGE DEBUG

clear
echo ""
echo "================"
echo "DYNAMODB BUILDER"
echo "================"
echo ""

remove_temp_files() {
    if [ "${TMP_BUILD_DIR}" != "" ]; then
        if [ -d "${TMP_BUILD_DIR}" ]; then
            echo "CLEAN-UP: Removing temporary files"
            if rm -rf "${TMP_BUILD_DIR}"
            then
                echo "CLEAN-UP Done"
            else
                echo "CLEAN-UP Failed"
            fi
        fi
    fi
}

exit_abort() {
    echo ""
    echo "Aborting..."
    echo ""
    remove_temp_files
    echo ""
    sh ${SCRIPTS_DIR}/../show_date_time.sh
    exit 1
}

# Basic Variables
REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

# ${SCRIPTS_DIR}/../aws_cf_processor/run-cf-deployment.sh ACTION STAGE CF_STACK_NAME CF_STACK_PARAMETERS CF_TEMPLATE_FILE ROUND
AWS_CF_PROCESSOR_SCRIPT="${SCRIPTS_DIR}/../aws_cf_processor/run-cf-deployment.sh"

# Default values
if [ "${CICD_MODE}" = "" ]; then
    CICD_MODE="0"
fi
if [ "${TMP_BUILD_DIR}" = "" ]; then
    TMP_BUILD_DIR="/tmp/${APP_NAME_LOWERCASE}_aws_secrets_tmp"
fi

# Script parameters
if [ "$1" != "" ]; then
    ACTION="$1"
fi
if [ "$2" != "" ]; then
    TARGET="$2"
fi
if [ "$3" != "" ]; then
    STAGE="$3"
fi
if [ "$4" != "" ]; then
    DEBUG="$4"
fi

# Script parameters validations
if [ "${ACTION}" = "" ]; then
    # echo "ERROR: ACTION not set. Options: create, update, delete, describe"
    echo "ERROR: ACTION not set. Options: run, destroy, describe, list_tables"
    exit_abort
fi
if [ "${STAGE}" = "" ]; then
    echo "ERROR: STAGE not set. Options: dev, qa, staging, demo, prod"
    exit_abort
fi
if [ "${TARGET}" = "" ]; then
    echo "ERROR: TARGET not set. Options: dynamodb"
    exit_abort
fi

prepare_working_environment() {
    # Get and validate environment variables
    set -o allexport ; . .env ; set +o allexport ;

    if [ "${APP_NAME}" = "" ]; then
        echo "ERROR: APP_NAME environment variable not set"
        exit_abort
    fi

    if [ "${AWS_REGION}" = "" ]; then
        echo "ERROR: AWS_REGION not set"
        exit_abort
    fi

    if [ "${APP_DOMAIN_NAME}" = "" ]; then
        echo "ERROR: APP_DOMAIN_NAME not set"
        exit_abort
    fi

    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output json --no-paginate | jq -r '.Account')
    if [ "${AWS_ACCOUNT_ID}" = "" ]; then
        echo "ERROR: AWS_ACCOUNT_ID not set"
        if [ "${ENGINE}" != "localstack" ]; then
            exit_abort
        fi
    fi

    # Working variables
    STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')
    APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

    # Temporary template file
    # TMP_CF_TEMPLATE_FILE="${TMP_BUILD_DIR}/template.yaml"

    CF_STACK_NAME_P1="${APP_NAME_LOWERCASE}-${STAGE}-dynamodb"
    CF_TEMPLATE_FILE_P1="cf-template-dynamodb.yml"
}

run_cf_templates_creation() {
    if [ "${TARGET}" = "dynamodb" ]; then
        local cf_template_file_p1_path="${REPO_BASEDIR}/scripts/aws_dynamodb/${CF_TEMPLATE_FILE_P1}"

        # DynamoDB template parameters
        CF_STACK_PARAMETERS="ParameterKey=AppName,ParameterValue='${APP_NAME_LOWERCASE}' ParameterKey=AppStage,ParameterValue='${STAGE}'"

        # Validate the create DynamoDB template
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "validate" "${STAGE}" "${CF_STACK_NAME_P1}" "${CF_STACK_PARAMETERS}" "${cf_template_file_p1_path}" ""
        then
            exit_abort
        fi

        # Run the create DynamoDB template
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "run" "${STAGE}" "${CF_STACK_NAME_P1}" "${CF_STACK_PARAMETERS}" "${cf_template_file_p1_path}" ""
        then
            exit_abort
        fi

        # List DynamoDB tables
        list_tables
    fi
}

run_cf_templates_destroy() {
    if [ "${TARGET}" = "dynamodb" ]; then
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "destroy" "${STAGE}" "${CF_STACK_NAME_P1}" "" "" ""
        then
            exit_abort
        fi
    fi
}

run_cf_templates_describe() {
    if [ "${TARGET}" = "dynamodb" ]; then
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "describe" "${STAGE}" "${CF_STACK_NAME_P1}" "" "" ""
        then
            exit_abort
        fi
    fi
}

list_tables() {
    if [ "${TARGET}" = "dynamodb" ]; then
        echo ""
        echo "Listing DynamoDB tables..."
        echo ""
        if ! ${AWS_COMMAND} dynamodb list-tables
        then
            exit_abort
        fi
    fi
}

localstack_venv() {
    if [ ! -d "venv" ]; then
        echo "[INFO|EC2] - Creating virtual environment..."
        python3 -m venv venv
        if [ -f localstack_requirements.txt ]; then
            pip install -r localstack_requirements.txt
        fi
    fi
    . venv/bin/activate
}

set_engine() {
    # Set ENGINE. Options: aws (meaning use the AWS Cloud services), localstack (local AWS services). Defaults to "aws"
    if [ "${ENGINE}" = "" ]; then
        ENGINE="aws"
    fi
    # Set AWS_COMMAND and eventually localstack envvars
    if [ "${ENGINE}" = "localstack" ]; then
        if [ "${LOCALSTACK_KEEP_ALIVE}" = "" ]; then
            # LOCALSTACK_KEEP_ALIVE="0"
            LOCALSTACK_KEEP_ALIVE="1"
        fi
        export AWS_COMMAND="awslocal --endpoint-url http://localhost:4566"
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "localstack_launch" "${STAGE}" "${CF_STACK_NAME_P1}" "" "" ""
        then
            exit_abort
        fi
        localstack_venv
    else
        export AWS_COMMAND="aws"
    fi
}

show_summary() {
    echo "Action (ACTION): ${ACTION}"
    echo "Stage (STAGE): ${STAGE}"
    echo "Target (TARGET): ${TARGET}"
    echo ""
    echo "* Parameters from the '.env' file:"
    echo ""
    echo "Repository base directory (REPO_BASEDIR): ${REPO_BASEDIR}"
    echo "Application name (APP_NAME): ${APP_NAME}"
    echo "AWS Region (AWS_REGION): ${AWS_REGION}"
    echo ""
    echo "* Working parameters:"
    echo ""
    echo "DynamoDB prefix for the tables: ${APP_NAME_LOWERCASE}_${STAGE}_"
    echo ""

    if [ "${CICD_MODE}" = "0" ]; then
        echo "Press Enter to proceed with the `echo ${TARGET} | tr '[:lower:]' '[:upper:]'` CloudFormation Stack processing..."
        read -r
    fi
}

# Main

prepare_working_environment
show_summary

set_engine

ERROR="1"

if [ "${ACTION}" = "run" ]; then
    run_cf_templates_creation
    ERROR="0"
fi

if [ "${ACTION}" = "destroy" ]; then
    ERROR="0"
    run_cf_templates_destroy
fi

if [ "${ACTION}" = "describe" ]; then
    run_cf_templates_describe
    ERROR="0"
fi

if [ "${ACTION}" = "list_tables" ]; then
    list_tables
    ERROR="0"
fi

remove_temp_files

if [ "${ERROR}" = "1" ]; then
    echo ""
    echo "Unknown action: '${ACTION}'"
    exit_abort
fi

echo "Done"
echo ""
