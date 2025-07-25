#!/bin/bash
# aws_secrets_manager.sh
# Create KMS Key(s), environment variables and secrets in AWS Secrets Manager using CloudFormation templates.
# 2024-06-16 | CR
# Usage:
# scripts/aws_secrets/aws_secrets_manager.sh ACTION TARGET STAGE DEBUG

clear
echo ""
echo "====================="
echo "SECRET STRING BUILDER"
echo "====================="
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
if [ "${AWS_DEPLOYMENT_TYPE}" = "" ]; then
    AWS_DEPLOYMENT_TYPE="lambda"
    # AWS_DEPLOYMENT_TYPE="fargate"
    # AWS_DEPLOYMENT_TYPE="ec2"
fi
if [ "${KMS_KEY_ALIAS}" = "" ]; then
    KMS_KEY_ALIAS="genericsuite-key"
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
    echo "ERROR: ACTION not set. Options: run, destroy, describe"
    exit_abort
fi
if [ "${STAGE}" = "" ]; then
    echo "ERROR: STAGE not set. Options: dev, qa, staging, demo, prod"
    exit_abort
fi
if [ "${TARGET}" = "" ]; then
    echo "ERROR: TARGET not set. Options: kms, secrets"
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
        exit_abort
    fi

    # Working variables
    STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')
    APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

    CF_STACK_NAME_P1="${APP_NAME_LOWERCASE}-${STAGE}-secrets"

    if [ "${CF_STACK_NAME_P2}" = "" ]; then
        # One for each application and environment (more expensive)
        # CF_STACK_NAME_P2="${APP_NAME_LOWERCASE}-${STAGE}-kms"
        # One for the entire AWS account (cheaper)
        CF_STACK_NAME_P2="genericsuite-key"
    fi

    CF_TEMPLATE_FILE_P1="cf-template-secrets.yml"
    CF_TEMPLATE_FILE_P2="cf-template-kms-key.yml"
}

get_secret_var_list() {
    # Set working variables

    # Secrets (will be encrypted)
    # Core
    export CORE_SECRETS="APP_SECRET_KEY APP_SUPERADMIN_EMAIL APP_DB_URI SMTP_USER SMTP_PASSWORD SMTP_DEFAULT_SENDER STORAGE_URL_SEED"
    # AI
    export EXTENSION_SECRETS="OPENAI_API_KEY GOOGLE_API_KEY GOOGLE_CSE_ID GOOGLE_MAPS_API_KEY \
        ANTHROPIC_API_KEY LANGCHAIN_API_KEY HUGGINGFACE_API_KEY GROQ_API_KEY AIMLAPI_API_KEY \
        NVIDIA_API_KEY RHYMES_CHAT_API_KEY RHYMES_VIDEO_API_KEY IBM_WATSONX_API_KEY \
        IBM_WATSONX_PROJECT_ID OPENROUTER_API_KEY XAI_API_KEY TOGETHER_API_KEY"

    # App specific
    export APP_SECRETS=""

    # Environment variables (will be plain, unencrypted)
    # Core
    export CORE_ENVS="APP_NAME APP_VERSION FLASK_APP APP_DEBUG APP_STAGE APP_CORS_ORIGIN APP_DB_ENGINE APP_DB_NAME CURRENT_FRAMEWORK DEFAULT_LANG GIT_SUBMODULE_URL GIT_SUBMODULE_LOCAL_PATH SMTP_SERVER SMTP_PORT SMTP_DEFAULT_SENDER APP_HOST_NAME CLOUD_PROVIDER AWS_REGION DYNAMDB_PREFIX"
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
    export DYNAMDB_PREFIX="${APP_NAME_LOWERCASE}_${STAGE}_"

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
    # APP_DB_URI=${APP_DB_URI//@/\\@}

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
    echo "{$secret_string}"
}

build_envvars() {
    # recover_at_sign
    # recover_at_sign_v2
    prepare_envars
    get_secret_var_list
    SECRET_STRING=$(secret_string_builder "${CORE_SECRETS}" "${EXTENSION_SECRETS}" "${APP_SECRETS}")
    ENV_VARS_STRING=$(secret_string_builder "${CORE_ENVS}" "${EXTENSION_ENVS}" "${APP_ENVS}")
    # echo "SECRET_STRING: ${SECRET_STRING}"
}

run_cf_templates_creation() {
    if [ "${TARGET}" = "secrets" ]; then
        build_envvars

        local cf_template_file_p1_path="${SCRIPTS_DIR}/${CF_TEMPLATE_FILE_P1}"

        local EncryptedSecretName="${APP_NAME_LOWERCASE}-${STAGE}-secrets"
        local EncryptedSecretDescription="Encrypted-Secrets-for-${APP_NAME_LOWERCASE}-${STAGE_UPPERCASE}"
        local UnEncryptedSecretName="${APP_NAME_LOWERCASE}-${STAGE}-envs"
        local UnEncryptedSecretDescription="Environment-variables-for-${APP_NAME_LOWERCASE}-${STAGE_UPPERCASE}"

        # Secrets template parameters
        CF_STACK_PARAMETERS="ParameterKey=AppName,ParameterValue='${APP_NAME_LOWERCASE}' ParameterKey=AppStage,ParameterValue='${STAGE}' ParameterKey=KmsKeyAlias,ParameterValue='${KMS_KEY_ALIAS}' ParameterKey=EncryptedSecretName,ParameterValue='${EncryptedSecretName}' ParameterKey=EncryptedSecretDescription,ParameterValue='${EncryptedSecretDescription}' ParameterKey=EncryptedSecretSecretString,ParameterValue='${SECRET_STRING}' ParameterKey=UnEncryptedSecretName,ParameterValue='${UnEncryptedSecretName}' ParameterKey=UnEncryptedSecretDescription,ParameterValue='${UnEncryptedSecretDescription}' ParameterKey=UnEncryptedSecretSecretString,ParameterValue='${ENV_VARS_STRING}'"

        # Validate the create Secrets template
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "validate" "${STAGE}" "${CF_STACK_NAME_P1}" "${CF_STACK_PARAMETERS}" "${cf_template_file_p1_path}" ""
        then
            exit_abort
        fi

        # Run the create Secrets template
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "run" "${STAGE}" "${CF_STACK_NAME_P1}" "${CF_STACK_PARAMETERS}" "${cf_template_file_p1_path}" ""
        then
            exit_abort
        fi
    fi

    if [ "${TARGET}" = "kms" ]; then
        local cf_template_file_p2_path="${SCRIPTS_DIR}/${CF_TEMPLATE_FILE_P2}"

        # KMS and https-certificate template parameters
        CF_STACK_PARAMETERS="ParameterKey=AppName,ParameterValue=${APP_NAME_LOWERCASE} ParameterKey=AppStage,ParameterValue=${STAGE} ParameterKey=KmsKeyAlias,ParameterValue=${KMS_KEY_ALIAS}"

        # KMS and https-certificate template parameters validation
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "validate" "${STAGE}" "${CF_STACK_NAME_P2}" "${CF_STACK_PARAMETERS}" "${cf_template_file_p2_path}" ""
        then
            exit_abort
        fi

        # Run the create KMS and https-certificate template
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "run" "${STAGE}" "${CF_STACK_NAME_P2}" "${CF_STACK_PARAMETERS}" "${cf_template_file_p2_path}" ""
        then
            exit_abort
        fi
    fi
}

run_cf_templates_destroy() {
    if [ "${TARGET}" = "secrets" ]; then
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "destroy" "${STAGE}" "${CF_STACK_NAME_P1}" "" "" ""
        then
            exit_abort
        fi
    fi
    if [ "${TARGET}" = "kms" ]; then
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "destroy" "${STAGE}" "${CF_STACK_NAME_P2}" "" "" ""
        then
            exit_abort
        fi
    fi
}

run_cf_templates_describe() {
    if [ "${TARGET}" = "secrets" ]; then
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "describe" "${STAGE}" "${CF_STACK_NAME_P1}" "" "" ""
        then
            exit_abort
        fi
    fi
    if [ "${TARGET}" = "kms" ]; then
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "describe" "${STAGE}" "${CF_STACK_NAME_P2}" "" "" ""
        then
            exit_abort
        fi
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
    echo "KMS key alias (KMS_KEY_ALIAS): ${KMS_KEY_ALIAS}"
    echo "AWS deployment type (AWS_DEPLOYMENT_TYPE): ${AWS_DEPLOYMENT_TYPE}"
    echo ""

    if [ "${CICD_MODE}" = "0" ]; then
        echo "Press Enter to proceed with the `echo ${TARGET} | tr '[:lower:]' '[:upper:]'` CloudFormation Stack processing..."
        read -r
    fi
}

# Main

prepare_working_environment
show_summary

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

remove_temp_files

if [ "${ERROR}" = "1" ]; then
    echo ""
    echo "Unknown action: '${ACTION}'"
    exit_abort
fi

echo "Done"
echo ""
