#!/bin/bash
# Create secrets in AWS Secrets Manager by a CloudFormation template.
# 2024-06-16 | CR

echo ""
echo "====================="
echo "SECRET_STRING_BUILDER"
echo "====================="
echo ""

# Action
ACTION="$1"
# Stage
STAGE="$2"
# Debug
DEBUG="$3"

prepare_working_environment() {
    REPO_BASEDIR="`pwd`"
    cd "`dirname "$0"`"
    SCRIPTS_DIR="`pwd`"
    cd "${REPO_BASEDIR}"

    # Get and validate script parameters

    # Stage
    if [ "${STAGE}" = "" ]; then
        STAGE="qa"
    fi
    STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')

    # Get and validate environment variables

    set -o allexport ; . .env ; set +o allexport ;

    if [ "${APP_NAME}" = "" ]; then
        echo "ERROR: APP_NAME environment variable not set"
        exit 1
    fi
    export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

    if [ "${AWS_REGION}" = "" ]; then
    echo "ERROR: AWS_REGION not set"
    exit_abort
    fi

    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output json --no-paginate | jq -r '.Account')

    if [ "${AWS_ACCOUNT_ID}" = "" ]; then
    echo "ERROR: AWS_ACCOUNT_ID not set"
    exit_abort
    fi

    TMP_BUILD_DIR="/tmp/${APP_NAME_LOWERCASE}_aws_secrets_tmp"
    CF_TEMPLATE_FILE="${TMP_BUILD_DIR}/template.yaml"
}

get_secret_var_list() {
    # Set working variables

    # Core
    export CORE_SECRETS="APP_SECRET_KEY APP_SUPERADMIN_EMAIL APP_DB_URI SMTP_USER SMTP_PASSWORD SMTP_DEFAULT_SENDER STORAGE_URL_SEED"

    # AI
    export EXTENSION_SECRETS="OPENAI_API_KEY GOOGLE_API_KEY GOOGLE_CSE_ID LANGCHAIN_API_KEY HUGGINGFACE_API_KEY"

    # App specific
    export APP_SECRETS=""
    if [ -f "${REPO_BASEDIR}/scripts/aws/update_additional_envvars.sh" ]; then
        if ! . "${REPO_BASEDIR}/scripts/aws/update_additional_envvars.sh"
        then
            echo "Failed to update additional envvars"
            exit 1
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

recover_at_sign_v2() {
    # Replace @ with \@
    if [ "${REPLACE_AMPERSAND_VAR_LIST}" = "" ]; then
        REPLACE_AMPERSAND_VAR_LIST="APP_SUPERADMIN_EMAIL APP_SECRET_KEY APP_DB_URI_DEV APP_DB_URI_QA APP_DB_URI_STAGING APP_DB_URI_PROD APP_DB_URI_DEMO APP_DB_URI SMTP_DEFAULT_SENDER SMTP_USER SMTP_PASSWORD OPENAI_API_KEY LANGCHAIN_API_KEY GOOGLE_API_KEY HUGGINGFACE_API_KEY"
    fi
    base_names=(${REPLACE_AMPERSAND_VAR_LIST})
    for base_name in "${base_names[@]}"; do
        # eval "$base_name"=\${$base_name//@/\\@}
        echo "1) INIT  $base_name=$(eval echo \$${base_name} | perl -pe 's/@/\\\\@/g')"
        eval "$base_name"=$(eval echo \$${base_name} | perl -pe 's/@/\\@/g')
        echo "1) FINAL $base_name=$(eval echo \$${base_name})"
    done
}

prepare_envars() {
    if [ "${STAGE_DEPENDENT_VAR_LIST}" = "" ]; then
        STAGE_DEPENDENT_VAR_LIST="APP_DB_ENGINE APP_DB_NAME APP_DB_URI APP_CORS_ORIGIN"
    fi
    base_names=(${STAGE_DEPENDENT_VAR_LIST})
    for base_name in "${base_names[@]}"; do
        echo "2) ${base_name}=$(eval echo \$${base_name}_${STAGE_UPPERCASE})"
        eval "export ${base_name}=$(eval echo \$${base_name}_${STAGE_UPPERCASE})"
        # eval "export $base_name"=\${$base_name//@/\\@}
        echo "2) FINAL $base_name=$(eval echo \$${base_name})"
    done

    # export APP_DB_ENGINE=$(eval echo \$APP_DB_ENGINE_${STAGE_UPPERCASE})
    # export APP_DB_NAME=$(eval echo \$APP_DB_NAME_${STAGE_UPPERCASE})
    # export APP_DB_URI=$(eval echo \$APP_DB_URI_${STAGE_UPPERCASE})

    APP_DB_URI=${APP_DB_URI//@/\\@}

    if [ "${ACTION}" = "run_local" ]; then
        export APP_CORS_ORIGIN="http://app.${APP_NAME_LOWERCASE}.local:${FRONTEND_LOCAL_PORT}"
    else
        if [ "${STAGE_UPPERCASE}" = "QA" ]; then
            export APP_CORS_ORIGIN="${APP_CORS_ORIGIN_QA_CLOUD}"
        fi
    fi
}

secret_string_builder() {
    #
    # Returns SECRET_STRING as:
    #   SecretString: '{"username":"myUsername","password":"myPassword"}'
    #
    SECRET_STRING=""
    base_names=(${CORE_SECRETS} ${EXTENSION_SECRETS} ${APP_SECRETS})
    echo ">> base_names: ${base_names[@]}"
    echo ""
    separator=""
    for base_name in "${base_names[@]}"; do
        SECRET_STRING="${SECRET_STRING}${separator}\"${base_name}\":\"$(eval echo "\$${base_name}")\""
        separator=","
    done
    # SECRET_STRING="{\"SecretString\": '{$SECRET_STRING}'}"
}

prepare_cr_template() {
    if ! mkdir -p "${TMP_BUILD_DIR}"
    then
        echo "Failed to create ${TMP_BUILD_DIR}"
        exit 1
    fi

    if ! cp "${SCRIPTS_DIR}/secrets_cf_template.yml" "${CF_TEMPLATE_FILE}"
    then
        echo "Failed to copy CloudFormation template"
        exit 1
    fi

    perl -i -pe"s|GsEncryptedSecretName_placeholder|${APP_NAME_LOWERCASE}-${STAGE}|g" "${CF_TEMPLATE_FILE}"
    perl -i -pe"s|GsEncryptedSecretDescription_placeholder|Secrets for ${APP_NAME_LOWERCASE} - ${STAGE_UPPERCASE}|g" "${CF_TEMPLATE_FILE}"
    perl -i -pe"s|GsEncryptedSecretSecretString_placeholder|${SECRET_STRING}|g" "${CF_TEMPLATE_FILE}"

    if [ "${DEBUG}" = "1" ]; then
        cat "${CF_TEMPLATE_FILE}"
        echo ""
    fi

    # Validate CloudFormation template
    if ! aws cloudformation validate-template --template-body file://"${CF_TEMPLATE_FILE}" > /dev/null
    then
        echo "Failed to validate CloudFormation template"
        exit 1
    fi
    echo "CloudFormation template validated successfully"
    echo ""
}

create_temp_cr_template() {
    recover_at_sign
    # recover_at_sign_v2
    prepare_envars
    get_secret_var_list
    secret_string_builder
    # echo "SECRET_STRING: ${SECRET_STRING}"
    prepare_cr_template
}

# Main

prepare_working_environment

ERROR="1"
if [ "${ACTION}" = "create" ]; then
    # Create stack
    echo "Creating stack..."
    create_temp_cr_template
    RESULT=$(aws cloudformation create-stack --stack-name "${APP_NAME_LOWERCASE}-${STAGE}-secrets" --template-body file://"${CF_TEMPLATE_FILE}" --capabilities CAPABILITY_IAM)
    if [ $? -ne 0 ]; then
        echo ${RESULT} | jq
        echo "Failed to create stack"
        exit 1
    fi
    echo ${RESULT} | jq
    echo "Stack created successfully"
    ERROR="0"
fi

if [ "${ACTION}" = "update" ]; then
    # Update stack
    echo "Updating stack..."
    create_temp_cr_template
    RESULT=$(aws cloudformation update-stack --stack-name "${APP_NAME_LOWERCASE}-${STAGE}-secrets" --template-body file://"${CF_TEMPLATE_FILE}" --capabilities CAPABILITY_IAM)
    if [ $? -ne 0 ]; then
        echo ${RESULT} | jq
        echo "Failed to update stack"
        exit 1
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
        exit 1
    fi
    echo ${RESULT} | jq
    echo "Stack deleted successfully"
    ERROR="0"
fi

if [ "${ACTION}" = "describe" ]; then
    # Describe stack
    echo "Describing stack..."
    RESULT=$(aws cloudformation describe-stacks --stack-name "${APP_NAME_LOWERCASE}-${STAGE}-secrets")
    if [ $? -ne 0 ]; then
        echo ${RESULT} | jq
        echo "Failed to describe stack"
        exit 1
    fi
    echo ${RESULT} | jq
    echo "Stack described successfully"
    ERROR="0"
fi

echo ""

# Cleanup
rm -rf "${TMP_BUILD_DIR}"
echo "CLEAN-UP Done"
echo ""

if [ "${ERROR}" = "1" ]; then
    echo "Unknown action: '${ACTION}'"
    exit 1
fi

echo "Done"
echo ""
