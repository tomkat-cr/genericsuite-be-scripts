# !/bin/bash
# run-ec2-cloud-deploy.sh
# Origin: init-cloud-deploy.sh [GS-96]
# 2024-06-15 | CR
# Usage:
# ECR_DOCKER_IMAGE_TAG="0.0.16" STAGE=qa sh node_modules/genericsuite-be-scripts/scripts/aws_ec2_elb/run-ec2-cloud-deploy.sh

remove_temp_files() {
    echo "No temporary files to remove..."
}

exit_abort() {
    echo ""
    echo "Aborting..."
    # echo ""
    # remove_temp_files
    sh ${SCRIPTS_DIR}/../show_date_time.sh
    exit 1
}

create_key_pair() {
    echo ""
    echo "Creating '${EC2_KEY_NAME}' key pair..."
    echo ""
    SSH_KEYS_DIRECTORY="${HOME}/.ssh"
    # Delete existing key pair file
    if [ -f ${SSH_KEYS_DIRECTORY}/${EC2_KEY_NAME}.pem ]; then
        echo "Key pair ${EC2_KEY_NAME} already exists. Removing it..."
        if ! rm -rf ${SSH_KEYS_DIRECTORY}/${EC2_KEY_NAME}.pem; then
            echo "ERROR: Could not delete existing key pair."
            exit_abort
        fi
    fi
    # Create new key pair in AWS and .pem file
    aws ec2 create-key-pair --key-name "${EC2_KEY_NAME}" --query 'KeyMaterial' --output text > "${SSH_KEYS_DIRECTORY}/${EC2_KEY_NAME}.pem"
    if [ ! $? -eq 0 ]
    then
        exit_abort
    fi
    echo ""
    echo "Securing '${SSH_KEYS_DIRECTORY}/${EC2_KEY_NAME}.pem'..."
    echo ""
    if ! chmod 400 "${SSH_KEYS_DIRECTORY}/${EC2_KEY_NAME}.pem"
    then
        echo "ERROR: Could not secure '${SSH_KEYS_DIRECTORY}/${EC2_KEY_NAME}.pem'"
        exit_abort
    fi
    echo ""
    echo "Done."
}

verify_key_pairs() {
    echo ""
    echo "Verify '${EC2_KEY_NAME}' key pair existence"
    if ! AWS_CMD_RESULT=$(aws ec2 describe-key-pairs --key-names "$EC2_KEY_NAME" --region "$AWS_REGION" --output text)
    then
        echo "${AWS_CMD_RESULT}"
        echo "Key pair does not exist... Creating it..."
        create_key_pair
    else
        echo "${AWS_CMD_RESULT}"
    fi
}

# Function to get a specific output value from the stack
get_stack_output() {
    local output_key=$1
    aws cloudformation describe-stacks \
        --region $AWS_REGION \
        --stack-name $CF_STACK_NAME_P1 \
        --query "Stacks[0].Outputs[?OutputKey=='$output_key'].OutputValue" \
        --output text
}

# Function to get the HostedZoneId for a given domain
get_hosted_zone_id() {
    local domain=$1
    aws route53 list-hosted-zones-by-name \
        --dns-name "$domain." \
        --query "HostedZones[?Name=='$domain.'].Id" \
        --output text | sed 's/\/hostedzone\///'
}

get_pars_for_second_run() {
    # Get LoadBalancerArn
    LOAD_BALANCER_ARN=$(get_stack_output "LoadBalancerArn")
    if [ -z "$LOAD_BALANCER_ARN" ]; then
        echo "Failed to retrieve LoadBalancerArn"
        exit_abort
    fi

    # Get TargetGroupArn
    TARGET_GROUP_ARN=$(get_stack_output "TargetGroupArn")
    if [ -z "$TARGET_GROUP_ARN" ]; then
        echo "Failed to retrieve TargetGroupArn"
        exit_abort
    fi

    # Print the retrieved values
    echo "LoadBalancerArn: $LOAD_BALANCER_ARN"
    echo "TargetGroupArn: $TARGET_GROUP_ARN"

    # Optionally, you can export these variables to use them in other scripts
    export LOAD_BALANCER_ARN
    export TARGET_GROUP_ARN
    export HOSTED_ZONE_ID
}

create_tmp_cf_template_file() {
    local cf_template_file_original=$1
    echo ""
    echo "Creating temporary CloudFormation template file..."
    echo "From: ${cf_template_file_original}"
    echo ""

    # Copy the original CloudFormation template file to the temporary directory
    local cf_template_file="${TMP_WORKING_DIR}/$(basename ${cf_template_file_original})"
    if ! cp "${cf_template_file_original}" "${cf_template_file}"
    then
        echo "ERROR: Could not copy '${cf_template_file_original}' to '${cf_template_file}'"
        exit_abort
    fi

    local aws_s3_chatbot_attachments_bucket=$(eval echo \$AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_${STAGE_UPPERCASE})
    local app_name_and_stage="${APP_NAME_LOWERCASE}-${STAGE}"
    perl -i -pe "s|APP_NAME_LOWERCASE_placeholder|${APP_NAME_LOWERCASE}|g" "${cf_template_file}"
    perl -i -pe "s|APP_STAGE_placeholder|${STAGE}|g" "${cf_template_file}"
    perl -i -pe "s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_placeholder|${aws_s3_chatbot_attachments_bucket}|g" "${cf_template_file}"
    perl -i -pe "s|AWS_KMS_KEY_ALIAS_placeholder|${app_name_and_stage}-kms|g" "${cf_template_file}"
    perl -i -pe "s|AWS_SECRETS_MANAGER_SECRETS_NAME_placeholder|${app_name_and_stage}-secrets|g" "${cf_template_file}"
    perl -i -pe "s|AWS_SECRETS_MANAGER_ENVS_NAME_placeholder|${app_name_and_stage}-envs|g" "${cf_template_file}"
    perl -i -pe "s|AWS_REGION_placeholder|${AWS_REGION}|g" "${cf_template_file}"
    perl -i -pe "s|AWS_ACCOUNT_ID_placeholder|${AWS_ACCOUNT_ID}|g" "${cf_template_file}"
    perl -i -pe "s|AWS_ECR_REPOSITORY_NAME_placeholder|${DOCKER_IMAGE_NAME}|g" "${cf_template_file}"

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

    verify_key_pairs
    if ! AWS_CMD_RESULT=$(aws cloudformation describe-stacks --stack-name ${cf_stack_name} --output text)
    then
        STACK_ACTION="create-stack"
        STACK_FOLLOWUP_ACTION="stack-create-complete"
    else
        STACK_ACTION="update-stack"
        STACK_FOLLOWUP_ACTION="stack-update-complete"
    fi
    echo ""
    echo "Process the CloudFormation stack:"
    echo "cf_template_file: '${cf_template_file}'"
    echo "cf_stack_name: '${cf_stack_name}'"
    echo "cf_stack_parameters: '${cf_stack_parameters}'"
    echo ""
    echo "aws cloudformation ${STACK_ACTION} --stack-name ${cf_stack_name} --template-body file://${cf_template_file} --parameters ${cf_stack_parameters} --capabilities CAPABILITY_NAMED_IAM --output text"
    echo ""
    if aws cloudformation ${STACK_ACTION} --stack-name ${cf_stack_name} --template-body file://${cf_template_file} --parameters ${cf_stack_parameters} --capabilities CAPABILITY_NAMED_IAM --output text > "${LOG_FILE}" 2>&1
    then
        AWS_CMD_RESULT=$(cat "${LOG_FILE}")
        echo "${AWS_CMD_RESULT}"
    else
        AWS_CMD_RESULT=$(cat "${LOG_FILE}")
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
                echo "Deleting the stacks and retrying..."
                echo ""
                destroy_cloud_cf_stack "${CF_STACK_NAME_P1}"
                destroy_cloud_cf_stack "${CF_STACK_NAME_P2}"
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
    echo "aws cloudformation wait ${STACK_FOLLOWUP_ACTION} --stack-name ${cf_stack_name} --output text"
    echo ""
    if AWS_CMD_RESULT=$(aws cloudformation wait ${STACK_FOLLOWUP_ACTION} --stack-name ${cf_stack_name} --output text)
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

run_cf_templates_creation() {
    # Validate templates
    validate_cloud_cf_stack "${CF_TEMPLATE_FILE_P1}"
    validate_cloud_cf_stack "${CF_TEMPLATE_FILE_P2}"

    # Run the create infraestructure template
    CF_STACK_PARAMETERS="ParameterKey=AppStackName,ParameterValue=${DOCKER_IMAGE_NAME} ParameterKey=KeyName,ParameterValue=${EC2_KEY_NAME} ParameterKey=EcrDockerImageUri,ParameterValue=${ECR_DOCKER_IMAGE_URI} ParameterKey=EcrDockerImageTag,ParameterValue=${ECR_DOCKER_IMAGE_TAG} ParameterKey=DomainName,ParameterValue=${ALB_DOMAIN_NAME} ParameterKey=HostedZoneId,ParameterValue=${HOSTED_ZONE_ID} ParameterKey=AppName,ParameterValue=${APP_NAME_LOWERCASE} ParameterKey=AppStage,ParameterValue=${STAGE}"

    create_and_test_cloud_cf_stack "${CF_TEMPLATE_FILE_P1}" "${CF_STACK_NAME_P1}" "${CF_STACK_PARAMETERS}"

    get_pars_for_second_run

    # Run the create app https-certificate template
    CF_STACK_PARAMETERS="ParameterKey=AppStackName,ParameterValue=${DOCKER_IMAGE_NAME} ParameterKey=DomainName,ParameterValue=${ALB_DOMAIN_NAME} ParameterKey=TargetGroupArn,ParameterValue=${LOAD_BALANCER_ARN} ParameterKey=LoadBalancerArn,ParameterValue=${TARGET_GROUP_ARN} ParameterKey=HostedZoneId,ParameterValue=${HOSTED_ZONE_ID} ParameterKey=AppName,ParameterValue=${APP_NAME_LOWERCASE} ParameterKey=AppStage,ParameterValue=${STAGE}"

    create_and_test_cloud_cf_stack "${CF_TEMPLATE_FILE_P2}" "${CF_STACK_NAME_P2}" "${CF_STACK_PARAMETERS}"

    # Get the certificate ARN from the SSL stack (after it's created)
    CERTIFICATE_ARN=$(get_stack_output $SSL_STACK_NAME "CertificateArn")

    echo ""
    echo "Templates run result:"
    echo "Certificate ARN: ${CERTIFICATE_ARN}"
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

# Default values

# REPO_BASEDIR="./my-fastapi-app"
# APP_NAME="my-fastapi-app"
# AWS_LAMBDA_FUNCTION_NAME="${APP_NAME}-backend"
# AWS_REGION="us-east-1"
# STAGE="qa"

DEBUG="1"
DESTROY_STACK="0"
TMP_WORKING_DIR="/tmp"

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

echo ""
echo "REPO_BASEDIR=${REPO_BASEDIR}"
echo "SCRIPTS_DIR=${SCRIPTS_DIR}"
echo ""

set -o allexport; . .env ; set +o allexport ;

# Validations
if [ "${ECR_DOCKER_IMAGE_TAG}" = "" ]; then
    # ECR_DOCKER_IMAGE_TAG="latest"
    echo ""
    echo "ERROR: ECR_DOCKER_IMAGE_TAG is not defined"
    exit_abort
fi
if [ "${STAGE}" = "" ]; then
    echo ""
    echo "ERROR: STAGE is not defined"
    exit_abort
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

if [ "${ACTION}" = "" ]; then
    ACTION="$1"
fi
if [ "${ACTION}" = "" ]; then
    echo ""
    echo "ERROR: ACTION is not defined. Options: run, destroy"
    exit_abort
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output json --no-paginate | jq -r '.Account')
if [ "${AWS_ACCOUNT_ID}" = "" ]; then
    echo ""
    echo "ERROR: AWS_ACCOUNT_ID could not be retrieved. Please configure your AWS credentials."
    exit_abort
fi

# Working variables
STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')
APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

AWS_LAMBDA_FUNCTION_NAME_AND_STAGE=$(echo ${AWS_LAMBDA_FUNCTION_NAME}-${STAGE_UPPERCASE} | tr '[:upper:]' '[:lower:]')
DOCKER_IMAGE_NAME="${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}-ec2"

LOG_FILE="${TMP_WORKING_DIR}/${DOCKER_IMAGE_NAME}.log"

# ....

EC2_VPC_ID="${DOCKER_IMAGE_NAME}-vpc"
EC2_SUBNET_ID="${DOCKER_IMAGE_NAME}-subnet"
EC2_KEY_NAME="${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}-ec2-keys"
ALB_DOMAIN_NAME="api-${STAGE}-2.${APP_DOMAIN_NAME}"

ECR_DOCKER_IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${DOCKER_IMAGE_NAME}"

CF_STACK_NAME_P1="${DOCKER_IMAGE_NAME}-core"
CF_STACK_NAME_P2="${DOCKER_IMAGE_NAME}-ssl-https"

if [ "${CF_TEMPLATE_FILE_P1}" = "" ]; then
    # CF_TEMPLATE_FILE_P1="fastapi-ec2-localstack.yml"
    # CF_TEMPLATE_FILE_P1="fastapi-ec2-ecr.yml"
    CF_TEMPLATE_FILE_P1="template-cf-ec2-elb-part-1.yml"
fi
CF_TEMPLATE_FILE_P1="${SCRIPTS_DIR}/${CF_TEMPLATE_FILE_P1}"

if [ "${CF_TEMPLATE_FILE_P2}" = "" ]; then
    CF_TEMPLATE_FILE_P2="template-cf-ec2-elb-part-2.yml"
fi
CF_TEMPLATE_FILE_P2="${SCRIPTS_DIR}/${CF_TEMPLATE_FILE_P2}"

# Get the HostedZoneId
HOSTED_ZONE_ID=$(get_hosted_zone_id $APP_DOMAIN_NAME)
if [ -z "$HOSTED_ZONE_ID" ]; then
    echo "Failed to retrieve HostedZoneId"
    exit_abort
fi

clear
echo ""
echo "INIT-CLOUD-DEPLOY"
echo "AWS EC2 + ALB App Deployment"
echo ""
echo "ACTION: ${ACTION}"
echo "Stage (STAGE): ${STAGE}"
echo ""
echo "* Parameters from the '.env' file:"
echo ""
echo "Repository base directory (REPO_BASEDIR): ${REPO_BASEDIR}"
echo "Application name (APP_NAME): ${APP_NAME}"
echo "ECR Repository base name (AWS_LAMBDA_FUNCTION_NAME): ${AWS_LAMBDA_FUNCTION_NAME}"
echo "AWS Region (AWS_REGION): ${AWS_REGION}"
echo ""
echo "* Parameters to be used in the process:"
echo ""
# echo "Stage uppercased (STAGE_UPPERCASE): ${STAGE_UPPERCASE}"
# echo "ECR Repository name with stage (AWS_LAMBDA_FUNCTION_NAME_AND_STAGE): ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}"
echo "AWS Account ID (AWS_ACCOUNT_ID): ${AWS_ACCOUNT_ID}"
echo "Docker image name (DOCKER_IMAGE_NAME): ${DOCKER_IMAGE_NAME}"
echo "Log file (LOG_FILE): ${LOG_FILE}"
echo ""
# echo "Virtual private cloud ID (EC2_VPC_ID): ${EC2_VPC_ID}"
# echo "Subnet ID (EC2_SUBNET_ID): ${EC2_SUBNET_ID}"
echo "SSH key-pair name (EC2_KEY_NAME): ${EC2_KEY_NAME}"
echo "ECR Repository Name (ECR_DOCKER_IMAGE_URI): ${ECR_DOCKER_IMAGE_URI}"
echo "ECR Image Tag (ECR_DOCKER_IMAGE_TAG): ${ECR_DOCKER_IMAGE_TAG}"
echo "CloudFormation Stack Name # 1 (CF_STACK_NAME_P1): ${CF_STACK_NAME_P1}"
echo "CloudFormation Template File # 1 (CF_TEMPLATE_FILE_P1): ${CF_TEMPLATE_FILE_P1}"
echo "CloudFormation Stack Name # 2 (CF_STACK_NAME_P2): ${CF_STACK_NAME_P2}"
echo "CloudFormation Template File # 2 (CF_TEMPLATE_FILE_P2): ${CF_TEMPLATE_FILE_P2}"
echo "HostedZoneId (HOSTED_ZONE_ID): ${HOSTED_ZONE_ID}"
echo "Final API Service URI (ALB_DOMAIN_NAME): ${ALB_DOMAIN_NAME}"
echo ""

echo "Press enter to proceed with the CloudFormation Stack processing..."
read -r

sh ${SCRIPTS_DIR}/../show_date_time.sh

if [[ "${ACTION}" = "" || "${ACTION}" = "run" ]]; then
    run_cf_templates_creation
fi

if [[ "${ACTION}" = "down" || "${ACTION}" = "destroy" ]]; then
    destroy_cloud_cf_stack "${CF_STACK_NAME_P1}"
    destroy_cloud_cf_stack "${CF_STACK_NAME_P2}"
fi

echo ""
echo "Done"
sh ${SCRIPTS_DIR}/../show_date_time.sh
