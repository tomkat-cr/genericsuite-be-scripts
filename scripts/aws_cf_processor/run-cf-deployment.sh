# !/bin/bash
# run-cf-deployment.sh
# 2024-07-06 | CR
#
# Usage:
# scripts/aws_cf_processor/run-cf-deployment.sh ACTION STAGE CF_STACK_NAME CF_STACK_PARAMETERS CF_TEMPLATE_FILE ROUND
#
# Parameters:
# ACTION: valid options: run, destroy, validate, get_output, describe
# STAGE: dev, qa, staging, demo, prod
# CF_STACK_NAME: AWS CloudFormation stack name
# CF_STACK_PARAMETERS: AWS CloudFormation stack parameters
# CF_TEMPLATE_FILE: path of the AWS CloudFormation template file
# ROUND: it should be empty for the first run, then it must have a value

remove_temp_files() {
    if [ "${TMP_BUILD_DIR}" != "" ]; then
        if [ "${TMP_BUILD_DIR}" != "/tmp" ]; then
            if [ -d "${TMP_BUILD_DIR}" ]; then
                echo "Removing temporary directory: ${TMP_BUILD_DIR}"
                if rm -rf "${TMP_BUILD_DIR}"
                then
                    echo "CLEAN-UP Done"
                else
                    echo "CLEAN-UP Failed"
                fi
            fi
        fi
    fi
    if [ "${TEMP_CF_TEMPLATE_FILE}" != "" ]; then
        if [ -f "${TEMP_CF_TEMPLATE_FILE}" ]; then
            echo "Removing temp file: ${TEMP_CF_TEMPLATE_FILE}"
            if ! rm -rf ${TEMP_CF_TEMPLATE_FILE}; then
                echo "ERROR: Could not remove temporary CloudFormation template file: ${TEMP_CF_TEMPLATE_FILE}"
            fi
        fi
    fi
    if [ "${TEMP_LOG_FILE}" != "" ]; then
        if [ -f "${TEMP_LOG_FILE}" ]; then
            echo "Removing temp file: ${TEMP_LOG_FILE}"
            if ! rm -rf ${TEMP_LOG_FILE}; then
                echo "ERROR: Could not remove temporary log file: ${TEMP_LOG_FILE}"
            fi
        fi
    fi
}

exit_abort() {
    echo ""
    echo "Aborting..."
    # echo ""
    remove_temp_files
    sh ${SCRIPTS_DIR}/../show_date_time.sh
    exit 1
}

get_stack_output() {
    # Function to get a specific output value from the stack
    local cf_stack_name="$1"
    local aws_region="$2"
    local output_key="$3"
    if [ -z "$output_key" ]; then
        local query_arg="Stacks[0].Outputs"
    else
        local query_arg="Stacks[0].Outputs[?OutputKey=='$output_key'].OutputValue"
    fi
    aws cloudformation describe-stacks \
        --region $aws_region \
        --stack-name $cf_stack_name \
        --query $query_arg \
        --output text
}

describe_stack() {
    local cf_stack_name=$1
    RESULT=$(aws cloudformation describe-stacks --stack-name "$cf_stack_name")
    if [ $? -ne 0 ]; then
        echo ${RESULT} | jq
        echo "Failed to describe stack: '$cf_stack_name'"
        exit_abort
    fi
    echo ${RESULT} | jq
    echo "Stack described successfully"

}

create_tmp_cf_template_file() {
    local cf_template_file_original=$1
    echo ""
    echo "Creating temporary CloudFormation template file..."
    echo "From: ${cf_template_file_original}"
    echo ""

    # Create temp directory if it isn't /tmp
    if [ "${TMP_BUILD_DIR}" != "/tmp" ]; then
        if ! mkdir -p "${TMP_BUILD_DIR}"
        then
            echo "Failed to create temp directory: ${TMP_BUILD_DIR}"
            exit_abort
        fi
    fi

    # Copy the original CloudFormation template file to the temporary directory
    local cf_template_file="${TMP_BUILD_DIR}/$(basename ${cf_template_file_original})"
    if ! cp "${cf_template_file_original}" "${cf_template_file}"
    then
        echo "ERROR: Could not copy '${cf_template_file_original}' to '${cf_template_file}'"
        exit_abort
    fi

    # local aws_s3_chatbot_attachments_bucket=$(eval echo \$AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_${STAGE_UPPERCASE})
    # local app_name_and_stage="${APP_NAME_LOWERCASE}-${STAGE}"
    # perl -i -pe "s|APP_NAME_LOWERCASE_placeholder|${APP_NAME_LOWERCASE}|g" "${cf_template_file}"
    # perl -i -pe "s|APP_STAGE_placeholder|${STAGE}|g" "${cf_template_file}"
    # perl -i -pe "s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_placeholder|${aws_s3_chatbot_attachments_bucket}|g" "${cf_template_file}"
    # perl -i -pe "s|AWS_KMS_KEY_ALIAS_placeholder|${app_name_and_stage}-kms|g" "${cf_template_file}"
    # perl -i -pe "s|AWS_SECRETS_MANAGER_SECRETS_NAME_placeholder|${app_name_and_stage}-secrets|g" "${cf_template_file}"
    # perl -i -pe "s|AWS_SECRETS_MANAGER_ENVS_NAME_placeholder|${app_name_and_stage}-envs|g" "${cf_template_file}"
    # perl -i -pe "s|AWS_REGION_placeholder|${AWS_REGION}|g" "${cf_template_file}"
    # perl -i -pe "s|AWS_ACCOUNT_ID_placeholder|${AWS_ACCOUNT_ID}|g" "${cf_template_file}"
    # perl -i -pe "s|AWS_ECR_REPOSITORY_NAME_placeholder|${DOCKER_IMAGE_NAME}|g" "${cf_template_file}"

    export TEMP_CF_TEMPLATE_FILE="${cf_template_file}"
    echo "File created: ${TEMP_CF_TEMPLATE_FILE}"
    echo "Done."
}

validate_cloud_cf_stack() {
    local cf_template_file_original=$1
    echo ""
    echo "Validating CloudFormation template..."
    echo "From: ${cf_template_file_original}"
    echo ""
    create_tmp_cf_template_file "${cf_template_file_original}"
    local cf_template_file="${TEMP_CF_TEMPLATE_FILE}"
    if ! AWS_CMD_RESULT=$(aws cloudformation validate-template --template-body file://${cf_template_file} --output text)
        then
        echo "ERROR: CloudFormation template validation failed"
        echo "ERROR: ${AWS_CMD_RESULT}"
        exit_abort
    fi
    echo "Done."
}

create_and_test_cloud_cf_stack() {
    local cf_template_file_original=$1
    local cf_stack_name=$2
    local cf_stack_parameters=$3
    local round=$4

    create_tmp_cf_template_file "${cf_template_file_original}"
    local cf_template_file="${TEMP_CF_TEMPLATE_FILE}"

    # verify_key_pairs
    if ! AWS_CMD_RESULT=$(aws cloudformation describe-stacks --stack-name ${cf_stack_name} --output text)
    then
        STACK_ACTION="create-stack"
        STACK_FOLLOW_UP_ACTION="stack-create-complete"
    else
        STACK_ACTION="update-stack"
        STACK_FOLLOW_UP_ACTION="stack-update-complete"
    fi
    echo ""
    echo "Process the CloudFormation stack:"
    echo "cf_template_file: '${cf_template_file}'"
    echo "cf_stack_name: '${cf_stack_name}'"
    echo "cf_stack_parameters: '${cf_stack_parameters}'"
    echo ""
    echo "aws cloudformation ${STACK_ACTION} --stack-name ${cf_stack_name} --template-body file://${cf_template_file} --parameters ${cf_stack_parameters} --capabilities CAPABILITY_NAMED_IAM --output text"
    echo ""
    if aws cloudformation ${STACK_ACTION} --stack-name ${cf_stack_name} --template-body file://${cf_template_file} --parameters ${cf_stack_parameters} --capabilities CAPABILITY_NAMED_IAM --output text > "${TEMP_LOG_FILE}" 2>&1
    then
        AWS_CMD_RESULT=$(cat "${TEMP_LOG_FILE}")
        echo "${AWS_CMD_RESULT}"
    else
        AWS_CMD_RESULT=$(cat "${TEMP_LOG_FILE}")
        if echo ${AWS_CMD_RESULT} | grep -q "can not be updated"
        then
            if [ "$round" != "" ]
            then
                echo ""
                echo "The process tried to delete the stack and re-run but it doesn't works..."
                echo "Please delete the stack manually and run the script again."
                echo "Exiting..."
                exit_abort
            else
                echo ""
                echo "The stack was rolled-back..."
                echo "${AWS_CMD_RESULT}"
                echo ""
                echo "Deleting the stacks and retrying..."
                echo ""
                destroy_cloud_cf_stack "${cf_stack_name}"
                sleep 5
                echo ""
                echo "Retrying the stack run..."
                echo ""
                create_and_test_cloud_cf_stack "${cf_template_file_original}" "${cf_stack_name}" "${cf_stack_parameters}" "2"
            fi
        else
            echo ""
            echo "ERROR-010: ${AWS_CMD_RESULT}"
            exit_abort
        fi
    fi

    echo ""
    echo "Wait for Stack Creation"
    echo ""
    echo "aws cloudformation wait ${STACK_FOLLOW_UP_ACTION} --stack-name ${cf_stack_name} --output text"
    echo ""
    if AWS_CMD_RESULT=$(aws cloudformation wait ${STACK_FOLLOW_UP_ACTION} --stack-name ${cf_stack_name} --output text)
    then
        echo "${AWS_CMD_RESULT}"
    else
        echo "ERROR: ${AWS_CMD_RESULT}"
        exit_abort
    fi

    echo ""
    echo "Check the stack creation"
    echo ""
    echo "aws cloudformation describe-stacks --stack-name ${cf_stack_name} --output text"
    echo ""
    if AWS_CMD_RESULT=$(aws cloudformation describe-stacks --stack-name ${cf_stack_name} --output text)
    then
        echo "${AWS_CMD_RESULT}"
    else
        echo "ERROR: ${AWS_CMD_RESULT}"
        exit_abort
    fi

    echo ""
    echo "Check the outputs"
    echo ""
    echo "aws cloudformation describe-stacks --stack-name ${cf_stack_name} --query "Stacks[0].Outputs" --output text"
    echo ""
    if AWS_CMD_RESULT=$(aws cloudformation describe-stacks --stack-name ${cf_stack_name} --query "Stacks[0].Outputs" --output text)
    then
        echo "${AWS_CMD_RESULT}"
    else
        echo "ERROR: ${AWS_CMD_RESULT}"
        exit_abort
    fi
}

destroy_cloud_cf_stack() {
    local cf_stack_name=$1
    echo ""
    echo "Deleting the CLOUD stack: ${cf_stack_name}"
    echo ""
    echo "aws cloudformation delete-stack --stack-name ${cf_stack_name} --output text"
    echo ""
    if AWS_CMD_RESULT=$(aws cloudformation delete-stack --stack-name ${cf_stack_name} --output text)
    then
        echo "${AWS_CMD_RESULT}"
    else
        echo "ERROR: ${AWS_CMD_RESULT}"
        exit_abort
    fi
    echo ""
    echo "Wait for Stack Deletion"
    echo ""
    echo "aws cloudformation wait stack-delete-complete --stack-name ${cf_stack_name} --output text"
    echo ""
    if AWS_CMD_RESULT=$(aws cloudformation wait stack-delete-complete --stack-name ${cf_stack_name} --output text)
    then
        echo "${AWS_CMD_RESULT}"
    else
        echo "ERROR: ${AWS_CMD_RESULT}"
        exit_abort
    fi
}

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

echo ""
echo "REPO_BASEDIR=${REPO_BASEDIR}"
echo "SCRIPTS_DIR=${SCRIPTS_DIR}"
echo ""

# Default values
# if [ "${CICD_MODE}" = "" ]; then
    CICD_MODE="1"
# fi
if [ "${TMP_BUILD_DIR}" = "" ]; then
    TMP_BUILD_DIR="/tmp/aws_cf_processor"
fi
if [ "${DEBUG}" = "" ]; then
    DEBUG="1"
fi

# set -o allexport; . .env ; set +o allexport ;

# Script parameters
# if [ "${ACTION}" = "" ]; then
    ACTION="$1"
# fi
# if [ "${STAGE}" = "" ]; then
    STAGE="$2"
# fi
# if [ "${CF_STACK_NAME}" = "" ]; then
    CF_STACK_NAME="$3"
# fi
# if [ "${CF_STACK_PARAMETERS}" = "" ]; then
    CF_STACK_PARAMETERS="$4"
# fi
# if [ "${CF_TEMPLATE_FILE}" = "" ]; then
    CF_TEMPLATE_FILE="$5"
# fi
# if [ "${ROUND}" = "" ]; then
    ROUND="$6"
# fi

# Validations

if [ "${ACTION}" = "" ]; then
    echo ""
    echo "ERROR: ACTION is not set. Valid options: run, destroy, validate, get_output"
    exit_abort
fi
if [ "${STAGE}" = "" ]; then
    echo ""
    echo "ERROR: STAGE is not set."
    exit_abort
fi
if [ "${CF_STACK_NAME}" = "" ]; then
    echo ""
    echo "ERROR: CF_STACK_NAME is not set."
    exit_abort
fi
if [ "${CF_STACK_PARAMETERS}" = "" ]; then
    echo ""
    echo "WARNING: CF_STACK_PARAMETERS is not set."
fi
if [ "${CF_TEMPLATE_FILE}" = "" ]; then
    echo ""
    echo "WARNING: CF_TEMPLATE_FILE is not set."
fi

if [ "${APP_NAME}" = "" ]; then
    echo ""
    echo "ERROR: APP_NAME is not defined"
    exit_abort
fi
if [ "${AWS_LAMBDA_FUNCTION_NAME}" = "" ]; then
    echo ""
    echo "ERROR: AWS_LAMBDA_FUNCTION_NAME is not defined"
    exit_abort
fi
if [ "${APP_DOMAIN_NAME}" = "" ]; then
    echo ""
    echo "ERROR: APP_DOMAIN_NAME is not defined"
    exit_abort
fi
if [ "${AWS_REGION}" = "" ]; then
    echo ""
    echo "ERROR: AWS_REGION is not defined"
    exit_abort
fi

if [ "${AWS_ACCOUNT_ID}" = "" ]; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output json --no-paginate | jq -r '.Account')
fi
if [ "${AWS_ACCOUNT_ID}" = "" ]; then
    echo ""
    echo "ERROR: AWS_ACCOUNT_ID could not be retrieved. Please configure your AWS credentials."
    exit_abort
fi

# Working variables
if [ "${STAGE_UPPERCASE}" = "" ]; then
    STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')
fi
if [ "${APP_NAME_LOWERCASE}" = "" ]; then
    APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
fi
if [ "${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}" = "" ]; then
    AWS_LAMBDA_FUNCTION_NAME_AND_STAGE=$(echo ${AWS_LAMBDA_FUNCTION_NAME}-${STAGE_UPPERCASE} | tr '[:upper:]' '[:lower:]')
fi
if [ "${DOCKER_IMAGE_NAME}" = "" ]; then
    DOCKER_IMAGE_NAME="${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}-ec2"
fi
TEMP_LOG_FILE="${TMP_BUILD_DIR}/${DOCKER_IMAGE_NAME}.log"

# clear
echo ""
echo "RUN-CF-DEPLOYMENT"
echo ""
echo "Action (ACTION): ${ACTION}"
echo "Stage (STAGE): ${STAGE}"
echo "CloudFormation Stack Name (CF_STACK_NAME): ${CF_STACK_NAME}"
echo "CloudFormation Parameters (CF_STACK_PARAMETERS): ${CF_STACK_PARAMETERS}"
echo "CloudFormation Template File (CF_TEMPLATE_FILE): ${CF_TEMPLATE_FILE}"
echo "Round (ROUND): ${ROUND}"
echo ""
echo "* Parameters from the '.env' file:"
echo ""
echo "Application name (APP_NAME): ${APP_NAME}"
echo "Application domain name (APP_DOMAIN_NAME): ${APP_DOMAIN_NAME}"
echo "AWS Resources base name (AWS_LAMBDA_FUNCTION_NAME): ${AWS_LAMBDA_FUNCTION_NAME}"
echo "AWS Region (AWS_REGION): ${AWS_REGION}"
echo ""
echo "* Parameters to be used in the process:"
echo ""
echo "AWS Account ID (AWS_ACCOUNT_ID): ${AWS_ACCOUNT_ID}"
echo "Docker image name (DOCKER_IMAGE_NAME): ${DOCKER_IMAGE_NAME}"
echo "Temporary log file (TEMP_LOG_FILE): ${TEMP_LOG_FILE}"
echo ""
echo ""

if [ "${CICD_MODE}" = "0" ]; then
    echo "Press Enter to proceed with the CloudFormation Stack processing..."
    read -r
fi

sh ${SCRIPTS_DIR}/../show_date_time.sh

if [[ "${ACTION}" = "" || "${ACTION}" = "run" ]]; then
    # Deploy (create or update) the CF stack
    create_and_test_cloud_cf_stack "${CF_TEMPLATE_FILE}" "${CF_STACK_NAME}" "${CF_STACK_PARAMETERS}"
    # Get the CF stack output
    echo $(get_stack_output "${CF_STACK_NAME}" "${AWS_REGION}")
fi

if [[ "${ACTION}" = "down" || "${ACTION}" = "destroy" ]]; then
    destroy_cloud_cf_stack "${CF_STACK_NAME}"
fi

if [ "${ACTION}" = "validate" ]; then
    validate_cloud_cf_stack "${CF_TEMPLATE_FILE}"
fi

if [ "${ACTION}" = "get_output" ]; then
    echo ""
    echo "CF stack output:"
    echo $(get_stack_output "${CF_STACK_NAME}" "${AWS_REGION}")
fi

if [ "${ACTION}" = "describe" ]; then
    echo ""
    echo "CF stack describe:"
    echo $(describe_stack "${CF_STACK_NAME}" "${AWS_REGION}")
fi

echo ""
echo "Done with '${ACTION}' over '${CF_STACK_NAME}'"
sh ${SCRIPTS_DIR}/../show_date_time.sh
cd "${REPO_BASEDIR}"
