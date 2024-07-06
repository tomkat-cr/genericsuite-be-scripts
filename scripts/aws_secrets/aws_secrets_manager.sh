#!/bin/bash
# aws_secrets_manager.sh
# Create secrets in AWS Secrets Manager by a CloudFormation template.
# 2024-06-16 | CR

echo ""
echo "====================="
echo "SECRET STRING BUILDER"
echo "====================="
echo ""

# Action
ACTION="$1"
# Stage
# STAGE="$2"
# Debug
# DEBUG="$3"

remove_temp_files() {
    rm -rf "${TMP_BUILD_DIR}"
    echo "CLEAN-UP Done"
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

prepare_working_environment() {
    REPO_BASEDIR="`pwd`"
    cd "`dirname "$0"`"
    SCRIPTS_DIR="`pwd`"
    cd "${REPO_BASEDIR}"

    # Get and validate script parameters

    if [ "${AWS_DEPLOYMENT_TYPE}" = "" ]; then
        AWS_DEPLOYMENT_TYPE="lambda"
        # AWS_DEPLOYMENT_TYPE="fargate"
        # AWS_DEPLOYMENT_TYPE="ec2"
    fi

    # Stage
    if [ "${STAGE}" = "" ]; then
        echo "ERROR: STAGE environment variable not set"
        exit_abort
    fi
    STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')

    # Get and validate environment variables

    set -o allexport ; . .env ; set +o allexport ;

    if [ "${APP_NAME}" = "" ]; then
        echo "ERROR: APP_NAME environment variable not set"
        exit_abort
    fi
    export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

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
    exit_abort
    fi

    TMP_BUILD_DIR="/tmp/${APP_NAME_LOWERCASE}_aws_secrets_tmp"
    CF_TEMPLATE_FILE="${TMP_BUILD_DIR}/template.yaml"

    # CF_SOURCE_TEMPLATE_FILE="secrets_cf_template.yml"
    CF_SOURCE_TEMPLATE_FILE="cf_template_secrets.yml"
}

get_secret_var_list() {
    # Set working variables

    # Secrets (will be encrypted)
    # Core
    export CORE_SECRETS="APP_SECRET_KEY APP_SUPERADMIN_EMAIL APP_DB_URI SMTP_USER SMTP_PASSWORD SMTP_DEFAULT_SENDER STORAGE_URL_SEED"
    # AI
    export EXTENSION_SECRETS="OPENAI_API_KEY GOOGLE_API_KEY GOOGLE_CSE_ID LANGCHAIN_API_KEY HUGGINGFACE_API_KEY"
    # App specific
    export APP_SECRETS=""

    # Environment variables (will be plain, unencrypted)
    # Core
    export CORE_ENVS="APP_NAME APP_VERSION FLASK_APP APP_DEBUG APP_STAGE APP_CORS_ORIGIN APP_DB_ENGINE APP_DB_NAME CURRENT_FRAMEWORK DEFAULT_LANG GIT_SUBMODULE_URL GIT_SUBMODULE_LOCAL_PATH SMTP_SERVER SMTP_PORT SMTP_DEFAULT_SENDER APP_HOST_NAME CLOUD_PROVIDER AWS_REGION"
    # AI
    export EXTENSION_ENVS="AI_ASSISTANT_NAME AWS_S3_CHATBOT_ATTACHMENTS_BUCKET OPENAI_MODEL OPENAI_TEMPERATURE LANGCHAIN_PROJECT USER_AGENT HUGGINGFACE_ENDPOINT_URL"
    # App specific
    export APP_ENVS=""

    # Get secrets and envvars from the specific app script
    if [ -f "${REPO_BASEDIR}/scripts/aws/update_additional_envvars.sh" ]; then
        if ! . "${REPO_BASEDIR}/scripts/aws/update_additional_envvars.sh"
        then
            echo "Failed to update additional envvars"
            exit_abort
        fi
    fi
}

recover_at_sign() {
    # Replace @ with \@
    APP_SUPERADMIN_EMAIL=${APP_SUPERADMIN_EMAIL//@/\\@}
    APP_SECRET_KEY=${APP_SECRET_KEY//@/\\@}

    APP_DB_URI_DEV=${APP_DB_URI_DEV//@/\\@}
    APP_DB_URI_QA=${APP_DB_URI_QA//@/\\@}
    APP_DB_URI_STAGING=${APP_DB_URI_STAGING//@/\\@}
    APP_DB_URI_PROD=${APP_DB_URI_PROD//@/\\@}
    APP_DB_URI_DEMO=${APP_DB_URI_DEMO//@/\\@}

    APP_DB_URI=${APP_DB_URI//@/\\@}

    SMTP_DEFAULT_SENDER=${SMTP_DEFAULT_SENDER//@/\\@}
    SMTP_USER=${SMTP_USER//@/\\@}
    SMTP_PASSWORD=${SMTP_PASSWORD//@/\\@}
    OPENAI_API_KEY=${OPENAI_API_KEY//@/\\@}
    LANGCHAIN_API_KEY=${LANGCHAIN_API_KEY//@/\\@}
    GOOGLE_API_KEY=${GOOGLE_API_KEY//@/\\@}
    HUGGINGFACE_API_KEY=${HUGGINGFACE_API_KEY//@/\\@}
}

# recover_at_sign_v2() {
#     # Replace @ with \@
#     if [ "${REPLACE_AMPERSAND_VAR_LIST}" = "" ]; then
#         REPLACE_AMPERSAND_VAR_LIST="APP_SUPERADMIN_EMAIL APP_SECRET_KEY APP_DB_URI_DEV APP_DB_URI_QA APP_DB_URI_STAGING APP_DB_URI_PROD APP_DB_URI_DEMO APP_DB_URI SMTP_DEFAULT_SENDER SMTP_USER SMTP_PASSWORD OPENAI_API_KEY LANGCHAIN_API_KEY GOOGLE_API_KEY HUGGINGFACE_API_KEY"
#     fi
#     base_names=(${REPLACE_AMPERSAND_VAR_LIST})
#     for base_name in "${base_names[@]}"; do
#         # eval "$base_name"=\${$base_name//@/\\@}
#         echo "1) INIT  $base_name=$(eval echo \$${base_name} | perl -pe 's/@/\\\\@/g')"
#         eval "$base_name"=$(eval echo \$${base_name} | perl -pe 's/@/\\@/g')
#         echo "1) FINAL $base_name=$(eval echo \$${base_name})"
#     done
# }

prepare_envars() {
    # Get environemnt variables values from its 3 stages
    if [ "${STAGE_DEPENDENT_VAR_LIST}" = "" ]; then
        STAGE_DEPENDENT_VAR_LIST="APP_DB_ENGINE APP_DB_NAME APP_DB_URI APP_CORS_ORIGIN AWS_S3_CHATBOT_ATTACHMENTS_BUCKET"
    fi
    base_names=(${STAGE_DEPENDENT_VAR_LIST})
    for base_name in "${base_names[@]}"; do
        echo "2) ${base_name}=$(eval echo \$${base_name}_${STAGE_UPPERCASE})"
        eval "export ${base_name}=$(eval echo \$${base_name}_${STAGE_UPPERCASE})"
        # eval "export $base_name"=\${$base_name//@/\\@}
        echo "2) FINAL $base_name=$(eval echo \$${base_name})"
    done

    # Special envvars not in .env
    export APP_VERSION=$(cat ${REPO_BASEDIR}/version.txt)
    export APP_STAGE="${STAGE}"
    export USER_AGENT="${APP_NAME_LOWERCASE}-${STAGE}"

    # Build the App backend host name
    if [ "${AWS_DEPLOYMENT_TYPE}" = "lambda" ]; then
        export APP_HOST_NAME="app-${STAGE}.${APP_DOMAIN_NAME}"
    fi
    if [ "${AWS_DEPLOYMENT_TYPE}" = "ec2" ]; then
        export APP_HOST_NAME="app-${STAGE}-2.${APP_DOMAIN_NAME}"
    fi
    if [ "${AWS_DEPLOYMENT_TYPE}" = "fargate" ]; then
        export APP_HOST_NAME="app-${STAGE}-3.${APP_DOMAIN_NAME}"
    fi

    # Fix the values with @
    APP_DB_URI=${APP_DB_URI//@/\\@}

    # Build CORS origin
    if [ "${ACTION}" = "run_local" ]; then
        export APP_CORS_ORIGIN="http://app.${APP_NAME_LOWERCASE}.local:${FRONTEND_LOCAL_PORT}"
    else
        if [ "${STAGE_UPPERCASE}" = "QA" ]; then
            export APP_CORS_ORIGIN="${APP_CORS_ORIGIN_QA_CLOUD}"
        fi
    fi
}

secret_string_builder() {
    # Returns SECRET_STRING as: "username":"myUsername","password":"myPassword"
    local core_secrets="$1"
    local extension_secrets="$2"
    local app_secrets="$3"
    secret_string=""
    base_names=(${core_secrets} ${extension_secrets} ${app_secrets})
    # echo ">> base_names: ${base_names[@]}"
    # echo ""
    separator=""
    for base_name in "${base_names[@]}"; do
        secret_string="${secret_string}${separator}\"${base_name}\":\"$(eval echo "\$${base_name}")\""
        separator=","
    done
    # secret_string="{\"SecretString\": '{$SECRET_STRING}'}"
    echo "$secret_string"
}

prepare_cf_template() {
    if ! mkdir -p "${TMP_BUILD_DIR}"
    then
        echo "Failed to create ${TMP_BUILD_DIR}"
        exit_abort
    fi

    if ! cp "${SCRIPTS_DIR}/${CF_SOURCE_TEMPLATE_FILE}" "${CF_TEMPLATE_FILE}"
    then
        echo "Failed to copy CloudFormation template"
        exit_abort
    fi

    perl -i -pe"s|GsKmsKeyAlias_placeholder|${APP_NAME_LOWERCASE}-${STAGE}-kms|g" "${CF_TEMPLATE_FILE}"
    perl -i -pe"s|GsEncryptedSecretName_placeholder|${APP_NAME_LOWERCASE}-${STAGE}-secrets|g" "${CF_TEMPLATE_FILE}"
    perl -i -pe"s|GsEncryptedSecretDescription_placeholder|Encrypted Secrets for ${APP_NAME_LOWERCASE} - ${STAGE_UPPERCASE}|g" "${CF_TEMPLATE_FILE}"
    perl -i -pe"s|GsEncryptedSecretSecretString_placeholder|${SECRET_STRING}|g" "${CF_TEMPLATE_FILE}"

    perl -i -pe"s|GsUnEncryptedSecretName_placeholder|${APP_NAME_LOWERCASE}-${STAGE}-envs|g" "${CF_TEMPLATE_FILE}"
    perl -i -pe"s|GsUnEncryptedSecretDescription_placeholder|Environment variables for ${APP_NAME_LOWERCASE} - ${STAGE_UPPERCASE}|g" "${CF_TEMPLATE_FILE}"
    perl -i -pe"s|GsUnEncryptedSecretSecretString_placeholder|${ENV_VARS_STRING}|g" "${CF_TEMPLATE_FILE}"

    if [ "${DEBUG}" = "1" ]; then
        cat "${CF_TEMPLATE_FILE}"
        echo ""
    fi

    # Validate CloudFormation template
    if ! aws cloudformation validate-template --template-body file://"${CF_TEMPLATE_FILE}" > /dev/null
    then
        echo "Failed to validate CloudFormation template"
        exit_abort
    fi
    echo "CloudFormation template validated successfully"
    echo ""
}

create_temp_cr_template() {
    recover_at_sign
    # recover_at_sign_v2
    prepare_envars
    get_secret_var_list
    SECRET_STRING=$(secret_string_builder "${CORE_SECRETS}" "${EXTENSION_SECRETS}" "${APP_SECRETS}")
    ENV_VARS_STRING=$(secret_string_builder "${CORE_ENVS}" "${EXTENSION_ENVS}" "${APP_ENVS}")
    # echo "SECRET_STRING: ${SECRET_STRING}"
    prepare_cf_template
}

# Main

prepare_working_environment

ERROR="1"
if [ "${ACTION}" = "create" ]; then
    # Create stack
    echo "Creating stack..."
    create_temp_cr_template
    RESULT=$(aws cloudformation create-stack --stack-name "${APP_NAME_LOWERCASE}-${STAGE}-secrets" --template-body file://"${CF_TEMPLATE_FILE}" --parameters ParameterKey=AppName,ParameterValue=${APP_NAME_LOWERCASE} ParameterKey=AppStage,ParameterValue=${STAGE} --capabilities CAPABILITY_IAM --capabilities CAPABILITY_NAMED_IAM)
    if [ $? -ne 0 ]; then
        echo ${RESULT} | jq
        echo "Failed to create stack"
        exit_abort
    fi
    echo ${RESULT} | jq
    echo "Stack created successfully"
    ERROR="0"
fi

if [ "${ACTION}" = "update" ]; then
    # Update stack
    echo "Updating stack..."
    create_temp_cr_template
    RESULT=$(aws cloudformation update-stack --stack-name "${APP_NAME_LOWERCASE}-${STAGE}-secrets" --template-body file://"${CF_TEMPLATE_FILE}" --parameters ParameterKey=AppName,ParameterValue=${APP_NAME_LOWERCASE} ParameterKey=AppStage,ParameterValue=${STAGE} --capabilities CAPABILITY_IAM --capabilities CAPABILITY_NAMED_IAM)
    if [ $? -ne 0 ]; then
        echo ${RESULT} | jq
        echo "Failed to update stack"
        exit_abort
    fi
    echo ${RESULT} | jq
    echo "Stack updated successfully"
    ERROR="0"
fi

if [ "${ACTION}" = "delete" ]; then
    # Delete stack
    echo "Deleting stack..."
    RESULT=$(aws cloudformation delete-stack --stack-name "${APP_NAME_LOWERCASE}-${STAGE}-secrets")
    if [ $? -ne 0 ]; then
        echo ${RESULT} | jq
        echo "Failed to delete stack"
        exit_abort
    fi
    echo ${RESULT} | jq
    echo "Stack deleted successfully"
    ERROR="0"
fi

if [ "${ACTION}" = "describe" ]; then
    # Describe stack
    create_temp_cr_template
    echo "Describing stack..."
    RESULT=$(aws cloudformation describe-stacks --stack-name "${APP_NAME_LOWERCASE}-${STAGE}-secrets")
    if [ $? -ne 0 ]; then
        echo ${RESULT} | jq
        echo "Failed to describe stack"
        exit_abort
    fi
    echo ${RESULT} | jq
    echo "Stack described successfully"
    ERROR="0"
fi

echo ""

# Cleanup
if [ "${DEBUG}" = "1" ]; then
    echo ""
    echo "Before CLEAN-UP debug: cat ${TMP_BUILD_DIR}/template.yaml"
    echo ""
    cat ${TMP_BUILD_DIR}/template.yaml
    echo ""
    echo ""
fi
remove_temp_files

if [ "${ERROR}" = "1" ]; then
    echo "Unknown action: '${ACTION}'"
    exit_abort
fi

echo "Done"
echo ""
