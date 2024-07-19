# !/bin/bash
# run-ec2-cloud-deploy.sh
# Origin: init-cloud-deploy.sh [GS-96]
# 2024-06-15 | CR
# Usage:
# ACTION=run STAGE=qa TARGET=ec2 ECR_DOCKER_IMAGE_TAG="0.0.16" sh node_modules/genericsuite-be-scripts/scripts/aws_ec2_elb/run-ec2-cloud-deploy.sh
# ACTION=run STAGE=qa TARGET=domain ECR_DOCKER_IMAGE_TAG=0.1.16 make deploy_ec2
# ACTION=run STAGE=qa TARGET=domain ECR_DOCKER_IMAGE_TAG=0.1.16 ENGINE=localstack make deploy_ec2
# CICD_MODE=0 ACTION=run STAGE=qa TARGET=ec2 ECR_DOCKER_IMAGE_TAG=0.0.16 make deploy_ec2
# CICD_MODE=0 ACTION=run STAGE=qa TARGET=ec2 ECR_DOCKER_IMAGE_TAG=0.0.16 ENGINE=localstack make deploy_ec2
# CICD_MODE=0 ACTION=destroy STAGE=qa TARGET=ec2 ECR_DOCKER_IMAGE_TAG=0.0.16 make deploy_ec2

remove_temp_files() {
    echo "No temporary files to remove..."
}

exit_abort() {
    echo ""
    echo "Aborting..."
    # echo ""
    remove_temp_files
    sh ${SCRIPTS_DIR}/../show_date_time.sh
    exit 1
}

clear
echo ""
echo "============================"
echo "     INIT-CLOUD-DEPLOY      "
echo "AWS EC2 + ALB App Deployment"
echo "============================"
echo ""

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
if [ "${TMP_WORKING_DIR}" = "" ]; then
    TMP_WORKING_DIR="/tmp"
fi
if [ "${DEBUG}" = "" ]; then
    DEBUG="1"
fi

# Script parameters
if [ "${ACTION}" = "" ]; then
    ACTION="$1"
fi
if [ "${STAGE}" = "" ]; then
    STAGE="$2"
fi
if [ "${TARGET}" = "" ]; then
    TARGET="$3"
fi

# Script parameters validations
if [ "${ACTION}" = "" ]; then
    echo "ERROR: ACTION is not set. Options: run, destroy"
    exit_abort
fi
if [ "${STAGE}" = "" ]; then
    echo "ERROR: STAGE is not set. Options: dev, qa, staging, demo, prod"
    exit_abort
fi
if [ "${TARGET}" = "" ]; then
    echo "ERROR: TARGET is not set. Options: domain, ec2"
    exit_abort
fi

create_key_pair() {
    echo ""
    echo "Creating '${EC2_SSH_KEY_FILENAME}.pem' key pair..."
    echo ""
    # Delete existing key pair file
    if [ -f "${SSH_KEYS_DIRECTORY}/${EC2_SSH_KEY_FILENAME}.pem" ]; then
        echo "Key pair ${EC2_SSH_KEY_FILENAME}.pem already exists. Removing it..."
        if ! rm -rf "${SSH_KEYS_DIRECTORY}/${EC2_SSH_KEY_FILENAME}.pem"; then
            echo "ERROR: Could not delete existing key pair."
            exit_abort
        fi
    fi
    # Create new key pair in AWS and .pem file
    ${AWS_COMMAND} ec2 create-key-pair --key-name "${EC2_KEY_NAME}" --query 'KeyMaterial' --output text > "${SSH_KEYS_DIRECTORY}/${EC2_SSH_KEY_FILENAME}.pem"
    if [ ! $? -eq 0 ]
    then
        exit_abort
    fi
    echo ""
    echo "Securing '${SSH_KEYS_DIRECTORY}/${EC2_SSH_KEY_FILENAME}.pem'..."
    echo ""
    if ! chmod 400 "${SSH_KEYS_DIRECTORY}/${EC2_SSH_KEY_FILENAME}.pem"
    then
        echo "ERROR: Could not secure '${SSH_KEYS_DIRECTORY}/${EC2_SSH_KEY_FILENAME}.pem'"
        exit_abort
    fi
    echo ""
    echo "Done."
}

verify_key_pairs() {
    echo ""
    echo "Verify '${EC2_KEY_NAME}' key pair existence"
    if ! AWS_CMD_RESULT=$(${AWS_COMMAND} ec2 describe-key-pairs --key-names "${EC2_KEY_NAME}" --region "$AWS_REGION" --output text)
    then
        echo "${AWS_CMD_RESULT}"
        echo "Key pair does not exist... Creating it..."
        create_key_pair
    else
        echo "${AWS_CMD_RESULT}"
    fi
}

# Function to get the HostedZoneId for a given domain
get_hosted_zone_id() {
    local domain=$1
    ${AWS_COMMAND} route53 list-hosted-zones-by-name \
        --dns-name "$domain." \
        --query "HostedZones[?Name=='$domain.'].Id" \
        --output text | sed 's/\/hostedzone\///'
}

# Function to get a specific output value from the stack
get_stack_output() {
    local output_key=$1
    local cf_stack_name_p1=$2
    if [ -z "${cf_stack_name_p1}" ]; then
        cf_stack_name_p1="${CF_STACK_NAME_P1}"
    fi
    ${AWS_COMMAND} cloudformation describe-stacks \
        --region ${AWS_REGION} \
        --stack-name ${cf_stack_name_p1} \
        --query "Stacks[0].Outputs[?OutputKey=='$output_key'].OutputValue" \
        --output text
}

# get_pars_for_second_run() {
#     # Get LoadBalancerArn
#     LOAD_BALANCER_ARN=$(get_stack_output "LoadBalancerArn")
#     if [ -z "$LOAD_BALANCER_ARN" ]; then
#         echo "Failed to retrieve LoadBalancerArn"
#         exit_abort
#     fi

#     # Get TargetGroupArn
#     TARGET_GROUP_ARN=$(get_stack_output "TargetGroupArn")
#     if [ -z "$TARGET_GROUP_ARN" ]; then
#         echo "Failed to retrieve TargetGroupArn"
#         exit_abort
#     fi

#     # Print the retrieved values
#     echo "LoadBalancerArn: $LOAD_BALANCER_ARN"
#     echo "TargetGroupArn: $TARGET_GROUP_ARN"

#     # Optionally, you can export these variables to use them in other scripts
#     export LOAD_BALANCER_ARN
#     export TARGET_GROUP_ARN
#     export HOSTED_ZONE_ID
# }

authorize_localstack_one_sq() {
    if [ "${ENGINE}" = "localstack" ]; then
        # Reference: https://docs.localstack.cloud/user-guide/aws/ec2/
        local security_group_name=$1
        ${AWS_COMMAND} ec2 authorize-security-group-ingress \
            --group-id ${security_group_name} \
            --protocol tcp \
            --port 22 \
            --cidr 0.0.0.0/0
        ${AWS_COMMAND} ec2 authorize-security-group-ingress \
            --group-id ${security_group_name} \
            --protocol tcp \
            --port 80 \
            --cidr 0.0.0.0/0
    fi
}

authorize_localstack_sq() {
    # authorize_localstack_one_sq "${APP_NAME_LOWERCASE}-${STAGE}-sg-ec2"
    authorize_localstack_one_sq "default"
}

get_localstack_default_sg_id() {
    local security_group_name=$1
    local security_group_id=$(awslocal ec2 describe-security-groups \
        --filters Name=group-name,Values=${security_group_name} \
        --query 'SecurityGroups[0].GroupId' \
        --output text)
    echo "${security_group_id}"
}


get_ec2_ip() {
    EC2_IP=$(awslocal ec2 describe-instances --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    echo "${EC2_IP}"
}

show_ssh_conection_help() {
    if [ "${ENGINE}" = "localstack" ]; then
        EC2_IP=$(get_stack_output "InstancePublicIP" "${CF_STACK_NAME_P1}")
        echo ""
        echo "Access the EC2 instance using this command:"
        echo "ssh -i "\${HOME}/.ssh/${EC2_SSH_KEY_FILENAME}.pem" root@${EC2_IP} -p 22"
        echo "ssh -p 12862 -i \${HOME}/.ssh/${EC2_SSH_KEY_FILENAME}.pem root@127.0.0.1"
        echo "And test with:"
        echo "curl ${EC2_IP}:80"
        echo "curl \"http://${EC2_IP}\""
    fi
}

run_cf_templates_creation() {
    if [ "${TARGET}" = "ec2" ]; then
        local cf_template_file_p1_path="${SCRIPTS_DIR}/${CF_TEMPLATE_FILE_P1}"

        # Verify / create key pairs for the EC2 instances
        verify_key_pairs

        local aws_s3_chatbot_attachments_bucket=$(eval echo \$AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_${STAGE_UPPERCASE})
        local app_name_and_stage="${APP_NAME_LOWERCASE}-${STAGE}"

        # Infraestructure template parameters
        CF_STACK_PARAMETERS="ParameterKey=KeyName,ParameterValue=${EC2_KEY_NAME} ParameterKey=EcrRepositoryName,ParameterValue=${DOCKER_IMAGE_NAME} ParameterKey=EcrDockerImageUri,ParameterValue=${ECR_DOCKER_IMAGE_URI} ParameterKey=EcrDockerImageTag,ParameterValue=${ECR_DOCKER_IMAGE_TAG} ParameterKey=DomainName,ParameterValue=${ALB_DOMAIN_NAME} ParameterKey=HostedZoneId,ParameterValue=${HOSTED_ZONE_ID} ParameterKey=AppName,ParameterValue=${APP_NAME_LOWERCASE} ParameterKey=AppStage,ParameterValue=${STAGE} ParameterKey=S3BucketName1,ParameterValue=${aws_s3_chatbot_attachments_bucket} ParameterKey=KmsKeyAlias,ParameterValue=${KMS_KEY_ALIAS} ParameterKey=AsmSecretsName,ParameterValue=${app_name_and_stage}-secrets ParameterKey=AsmEnvsName,ParameterValue=${app_name_and_stage}-envs ParameterKey=AwsRegion,ParameterValue=${AWS_REGION} ParameterKey=AwsAccountId,ParameterValue=${AWS_ACCOUNT_ID}  ParameterKey=DomainStackName,ParameterValue=${CF_STACK_NAME_P2}"

        if [ "${ENGINE}" = "localstack" ]; then
            local default_sg_id=$(get_localstack_default_sg_id "default")
            if [ -z "${default_sg_id}" ]; then
                echo "Failed to retrieve default security group ID"
                exit_abort
            fi
            CF_STACK_PARAMETERS="${CF_STACK_PARAMETERS} ParameterKey=DefaultSecurityGroupId,ParameterValue=${default_sg_id}"
        fi

        # Validate the create infraestructure template
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "validate" "${STAGE}" "${CF_STACK_NAME_P1}" "${CF_STACK_PARAMETERS}" "${cf_template_file_p1_path}" ""
        then
            exit_abort
        fi

        # Run the create infraestructure template
        # get_pars_for_second_run
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "run" "${STAGE}" "${CF_STACK_NAME_P1}" "${CF_STACK_PARAMETERS}" "${cf_template_file_p1_path}" ""
        then
            exit_abort
        fi

        authorize_localstack_sq
        show_ssh_conection_help
    fi

    if [ "${TARGET}" = "domain" ]; then
        local cf_template_file_p2_path="${SCRIPTS_DIR}/../aws_domains/${CF_TEMPLATE_FILE_P2}"

        # Subdomain and https-certificate template parameters
        CF_STACK_PARAMETERS="ParameterKey=DomainName,ParameterValue=${ALB_DOMAIN_NAME} ParameterKey=HostedZoneId,ParameterValue=${HOSTED_ZONE_ID} ParameterKey=AppName,ParameterValue=${APP_NAME_LOWERCASE} ParameterKey=AppStage,ParameterValue=${STAGE}"

        # Subdomain and https-certificate template parameters validation
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "validate" "${STAGE}" "${CF_STACK_NAME_P2}" "${CF_STACK_PARAMETERS}" "${cf_template_file_p2_path}" ""
        then
            exit_abort
        fi

        # Run the create subdomain and https-certificate template
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "run" "${STAGE}" "${CF_STACK_NAME_P2}" "${CF_STACK_PARAMETERS}" "${cf_template_file_p2_path}" ""
        then
            exit_abort
        fi

        # Get the certificate ARN from the SSL stack (after it's created)
        # CERTIFICATE_ARN=$(get_stack_output "CertificateArn")

        # echo ""
        # echo "Templates run result:"
        # echo "Certificate ARN: ${CERTIFICATE_ARN}"
    fi
}

run_cf_templates_destroy() {
    if [ "${TARGET}" = "ec2" ]; then
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "destroy" "${STAGE}" "${CF_STACK_NAME_P1}" "" "" ""
        then
            exit_abort
        fi
    fi
    if [ "${TARGET}" = "domain" ]; then
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "destroy" "${STAGE}" "${CF_STACK_NAME_P2}" "" "" ""
        then
            exit_abort
        fi
    fi
}

run_cf_templates_describe() {
    if [ "${TARGET}" = "ec2" ]; then
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "describe" "${STAGE}" "${CF_STACK_NAME_P1}" "" "" ""
        then
            exit_abort
        fi
    fi
    if [ "${TARGET}" = "domain" ]; then
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "describe" "${STAGE}" "${CF_STACK_NAME_P2}" "" "" ""
        then
            exit_abort
        fi
    fi
}

prepare_working_environment() {
    # Get and validate environment variables
    set -o allexport; . .env ; set +o allexport ;

    # .env variables validations
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

    if [ "${ECR_DOCKER_IMAGE_TAG}" = "" ]; then
        # ECR_DOCKER_IMAGE_TAG="latest"
        echo ""
        echo "ERROR: ECR_DOCKER_IMAGE_TAG is not defined"
        exit_abort
    fi

    # if [ "${ENGINE}" != "localstack" ]; then
        # AWS_ACCOUNT_ID=$(${AWS_COMMAND} sts get-caller-identity --output json --no-paginate | jq -r '.Account')
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output json --no-paginate | jq -r '.Account')
        if [ "${AWS_ACCOUNT_ID}" = "" ]; then
            echo ""
            echo "ERROR: AWS_ACCOUNT_ID could not be retrieved. Please configure your AWS credentials."
            exit_abort
        fi
    # fi

    # Working variables
    STAGE=$(echo ${STAGE} | tr '[:upper:]' '[:lower:]')
    STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')
    APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

    AWS_LAMBDA_FUNCTION_NAME_AND_STAGE=$(echo ${AWS_LAMBDA_FUNCTION_NAME}-${STAGE_UPPERCASE} | tr '[:upper:]' '[:lower:]')
    DOCKER_IMAGE_NAME="${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}-ec2"

    LOG_FILE="${TMP_WORKING_DIR}/${DOCKER_IMAGE_NAME}.log"

    # ....

    EC2_KEY_NAME="${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}-ec2-keys"
    ALB_DOMAIN_NAME="api-${STAGE}-2.${APP_DOMAIN_NAME}"

    ECR_DOCKER_IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${DOCKER_IMAGE_NAME}"

    CF_STACK_NAME_P1="${DOCKER_IMAGE_NAME}-infra"
    CF_STACK_NAME_P2="${DOCKER_IMAGE_NAME}-domain"

    if [ "${CF_TEMPLATE_FILE_P1}" = "" ]; then
        if [ "${ENGINE}" != "localstack" ]; then
            CF_TEMPLATE_FILE_P1="cf-template-ec2-elb.yml"
        else
            CF_TEMPLATE_FILE_P1="cf-template-ec2-localstack.yml"
        fi
    fi

    if [ "${CF_TEMPLATE_FILE_P2}" = "" ]; then
        CF_TEMPLATE_FILE_P2="cf-template-ec2-domain.yml"
    fi

    # Get the HostedZoneId
    if [ "${ENGINE}" != "localstack" ]; then
        HOSTED_ZONE_ID=$(get_hosted_zone_id $APP_DOMAIN_NAME)
        if [ -z "$HOSTED_ZONE_ID" ]; then
            echo "Failed to retrieve HostedZoneId"
            exit_abort
        fi
    fi

    # KMS key allias
    if [ "${KMS_KEY_ALIAS}" = "" ]; then
        KMS_KEY_ALIAS="genericsuite-key"
    fi

    # Set the EC2 SSH key filename
    EC2_SSH_KEY_FILENAME="${EC2_KEY_NAME}"
    if [ "${ENGINE}" = "localstack" ]; then
        EC2_SSH_KEY_FILENAME="${EC2_KEY_NAME}-localstack"
    fi
    SSH_KEYS_DIRECTORY="${HOME}/.ssh"
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
            LOCALSTACK_KEEP_ALIVE="0"
            # LOCALSTACK_KEEP_ALIVE="1"
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

describe_instances() {
    localstack_venv
    echo ""
    echo "EC2 VPCs:"
    ${AWS_COMMAND} ec2 describe-vpcs | jq
    echo ""
    echo "EC2 Security Groups:"
    ${AWS_COMMAND} ec2 describe-security-groups | jq
    echo ""
    echo "EC2 Instance(s):"
    ${AWS_COMMAND} ec2 describe-instances | jq
    echo ""
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

    if [ "${CICD_MODE}" = "0" ]; then
        echo "Press Enter to proceed with the `echo ${TARGET} | tr '[:lower:]' '[:upper:]'` CloudFormation Stack processing..."
        read -r
    fi
}

# Main

set_engine
prepare_working_environment
show_summary

sh ${SCRIPTS_DIR}/../show_date_time.sh

ERROR="1"

if [ "${ACTION}" = "run" ]; then
    run_cf_templates_creation
    ERROR="0"
fi

if [ "${ACTION}" = "destroy" ]; then
    run_cf_templates_destroy
    ERROR="0"
fi

if [ "${ACTION}" = "describe" ]; then
    run_cf_templates_describe
    ERROR="0"
fi

if [ "${ACTION}" = "localstack_status" ]; then
    sh ${AWS_CF_PROCESSOR_SCRIPT} "localstack_status" "${STAGE}" "localstack" "" "" ""
    ERROR="0"
fi

if [ "${ACTION}" = "localstack_logs" ]; then
    sh ${AWS_CF_PROCESSOR_SCRIPT} "localstack_logs" "${STAGE}" "localstack" "" "" ""
    ERROR="0"
fi

if [ "${ACTION}" = "localstack_stop" ]; then
    sh ${AWS_CF_PROCESSOR_SCRIPT} "localstack_stop" "${STAGE}" "localstack" "" "" ""
    ERROR="0"
fi

if [ "${ACTION}" = "localstack_shell" ]; then
    # sh ${AWS_CF_PROCESSOR_SCRIPT} "localstack_shell" "${STAGE}" "localstack" "" "" ""
    localstack_venv
    bash
    ERROR="0"
fi

if [ "${ACTION}" = "describe_instances" ]; then
    describe_instances
    ERROR="0"
fi

if [ "${ERROR}" = "1" ]; then
    echo "Unknown action: '${ACTION}'"
    exit_abort
fi

echo ""
echo "Done"
sh ${SCRIPTS_DIR}/../show_date_time.sh
