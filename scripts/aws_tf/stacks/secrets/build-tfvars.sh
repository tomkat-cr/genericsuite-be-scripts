#!/bin/bash
# stacks/secrets/build-tfvars.sh
# Sourced by run-tf-deployment.sh. Builds TF_VAR_secrets_map and
# TF_VAR_envs_map as JSON from the same variable lists used by
# scripts/aws_secrets/aws_secrets_manager.sh.
# 2026-07-16 | CR [GS-334]

# Secrets (encrypted)
CORE_SECRETS="APP_SECRET_KEY APP_SUPERADMIN_EMAIL APP_DB_URI SMTP_USER SMTP_PASSWORD SMTP_DEFAULT_SENDER STORAGE_URL_SEED"
EXTENSION_SECRETS="OPENAI_API_KEY GOOGLE_API_KEY GOOGLE_CSE_ID GOOGLE_MAPS_API_KEY \
    ANTHROPIC_API_KEY LANGCHAIN_API_KEY HUGGINGFACE_API_KEY GROQ_API_KEY AIMLAPI_API_KEY \
    NVIDIA_API_KEY RHYMES_CHAT_API_KEY RHYMES_VIDEO_API_KEY IBM_WATSONX_API_KEY \
    IBM_WATSONX_PROJECT_ID OPENROUTER_API_KEY XAI_API_KEY TOGETHER_API_KEY"
APP_SECRETS="${APP_SECRETS:-}"

# Environment variables (plain)
CORE_ENVS="APP_NAME FLASK_APP APP_DEBUG APP_STAGE APP_CORS_ORIGIN APP_DB_ENGINE APP_DB_NAME CURRENT_FRAMEWORK DEFAULT_LANG GIT_SUBMODULE_URL GIT_SUBMODULE_LOCAL_PATH SMTP_SERVER SMTP_PORT SMTP_DEFAULT_SENDER APP_HOST_NAME CLOUD_PROVIDER AWS_REGION DYNAMDB_PREFIX"
EXTENSION_ENVS="AI_ASSISTANT_NAME AWS_S3_CHATBOT_ATTACHMENTS_BUCKET OPENAI_MODEL OPENAI_TEMPERATURE LANGCHAIN_PROJECT USER_AGENT HUGGINGFACE_DEFAULT_CHAT_MODEL"
APP_ENVS="${APP_ENVS:-}"

# App-specific additions hook (same contract as the CF path)
if [ -f "${REPO_BASEDIR}/scripts/aws/update_additional_envvars.sh" ]; then
    # shellcheck disable=SC1091
    . "${REPO_BASEDIR}/scripts/aws/update_additional_envvars.sh" "" "${REPO_BASEDIR}"
fi

# Resolve stage-dependent variables (VAR = VAR_${STAGE_UPPERCASE})
STAGE_DEPENDENT_VAR_LIST="${STAGE_DEPENDENT_VAR_LIST:-APP_DB_ENGINE APP_DB_NAME APP_DB_URI APP_CORS_ORIGIN AWS_S3_CHATBOT_ATTACHMENTS_BUCKET}"
for base_name in ${STAGE_DEPENDENT_VAR_LIST}; do
    resolved_varname="${base_name}_${STAGE_UPPERCASE}"
    resolved="${!resolved_varname:-}"
    if [ "${resolved}" != "" ]; then
        printf -v "${base_name}" '%s' "${resolved}"
        export "${base_name}"
    fi
done

# Special envvars not in .env (same as aws_secrets_manager.sh prepare_envars)
export APP_STAGE="${STAGE}"
export USER_AGENT="${APP_NAME_LOWERCASE}-${STAGE}"
export DYNAMDB_PREFIX="${APP_NAME_LOWERCASE}_${STAGE}_"
AWS_DEPLOYMENT_TYPE="${AWS_DEPLOYMENT_TYPE:-lambda}"
if [ "${AWS_DEPLOYMENT_TYPE}" = "lambda" ]; then
    export APP_HOST_NAME="app-${STAGE}.${APP_DOMAIN_NAME:-}"
elif [ "${AWS_DEPLOYMENT_TYPE}" = "ec2" ]; then
    export APP_HOST_NAME="app-${STAGE}-2.${APP_DOMAIN_NAME:-}"
elif [ "${AWS_DEPLOYMENT_TYPE}" = "fargate" ]; then
    export APP_HOST_NAME="app-${STAGE}-3.${APP_DOMAIN_NAME:-}"
fi
if [ "${STAGE_UPPERCASE}" = "QA" ] && [ "${APP_CORS_ORIGIN_QA_CLOUD:-}" != "" ]; then
    export APP_CORS_ORIGIN="${APP_CORS_ORIGIN_QA_CLOUD}"
fi

# Build a JSON object {"VAR":"value",...} from a list of variable names
build_json_map() {
    local names="$1"
    local json="{}"
    local name value
    for name in ${names}; do
        value="${!name:-}"
        json="$(echo "${json}" | jq --arg k "${name}" --arg v "${value}" '. + {($k): $v}')"
    done
    echo "${json}"
}

TF_VAR_secrets_map="$(build_json_map "${CORE_SECRETS} ${EXTENSION_SECRETS} ${APP_SECRETS}")"
TF_VAR_envs_map="$(build_json_map "${CORE_ENVS} ${EXTENSION_ENVS} ${APP_ENVS}")"
export TF_VAR_secrets_map TF_VAR_envs_map

echo "Secrets/envs TF_VAR maps built ($(echo "${TF_VAR_envs_map}" | jq 'length') envs, $(echo "${TF_VAR_secrets_map}" | jq 'length') secrets)."
