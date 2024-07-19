#!/bin/sh
#
# sh scripts/aws/set_chalice_cnf.sh
# 2023-02-11 | CR
#
TARGET_STAGE=$1
TARGET_ACTION=$2

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

# TARGET_STAGE_UPPERCASE=$(echo $TARGET_STAGE | tr '[:lower:]' '[:upper:]')

ENV_FILESPEC=""
if [ -f "${REPO_BASEDIR}/.env" ]; then
    ENV_FILESPEC="${REPO_BASEDIR}/.env"
fi
if [ "$ENV_FILESPEC" = "" ]; then
    echo "ERROR: '.env' file doesn't exist"
    exit 1   
fi

set -o allexport; . ${ENV_FILESPEC}; set +o allexport ;

APP_VERSION=$(cat ${REPO_BASEDIR}/version.txt)
if [ "${APP_NAME}" = "" ]; then
    echo "ERROR: APP_NAME not set"
    exit 1
fi

export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

if [ "${CURRENT_FRAMEWORK}" = "" ]; then
    echo "ERROR: CURRENT_FRAMEWORK not set"
    exit 1
fi

if [ "${APP_DOMAIN_NAME}" = "" ]; then
    echo "ERROR: APP_HOST_NAME not set"
    exit 1
fi
if [ "${STORAGE_URL_SEED}" = "" ]; then
    echo "ERROR: STORAGE_URL_SEED not set"
    exit 1
fi

if [[ "${CURRENT_FRAMEWORK}" != "chalice" && "${CURRENT_FRAMEWORK}" != "chalice_docker" ]]; then
    echo "CURRENT_FRAMEWORK '${CURRENT_FRAMEWORK}' doesn't need 'set_chalice_cnf.sh' script to run..."
    exit 0
fi

echo "Running 'set_chalice_cnf.sh' to config '${CURRENT_FRAMEWORK}'..."

CONFIG_FILE="${REPO_BASEDIR}/.chalice/config.json"
CONFIG_TEMPLATE="${REPO_BASEDIR}/.chalice/config-example.json"

# if [ ! -f "${CONFIG_FILE}" ]; then
#     echo "ERROR: Config file doesn't exist"
#     exit 1
# fi

if [ ! -f "${CONFIG_TEMPLATE}" ]; then
    echo "ERROR: Config Template file doesn't exist"
    exit 1
fi

# Prepare domain names
. ${SCRIPTS_DIR}/../get_domain_name.sh "dev"
if [ "${DOMAIN_NAME}" = "" ];then
    exit 1
fi
DOMAIN_NAME_DEV="${DOMAIN_NAME}"
. ${SCRIPTS_DIR}/../get_domain_name.sh "qa"
DOMAIN_NAME_QA="${DOMAIN_NAME}"
. ${SCRIPTS_DIR}/../get_domain_name.sh "staging"
DOMAIN_NAME_STAGING="${DOMAIN_NAME}"
. ${SCRIPTS_DIR}/../get_domain_name.sh "demo"
DOMAIN_NAME_DEMO="${DOMAIN_NAME}"
. ${SCRIPTS_DIR}/../get_domain_name.sh "prod"
DOMAIN_NAME_PROD="${DOMAIN_NAME}"
echo ">> Done with Domain Names assignment..."
echo ""

if [ "${TARGET_STAGE}" = "qa" ] && [ "${TARGET_ACTION}" = "deploy" ]; then
    perl -i -pe "s|APP_CORS_ORIGIN_QA=.*|APP_CORS_ORIGIN_QA=${APP_CORS_ORIGIN_QA_CLOUD}|g" "${ENV_FILESPEC}"
    set -o allexport; . ${ENV_FILESPEC}; set +o allexport ;
fi

if [ "${TARGET_STAGE}" = "qa" ] && [ "${TARGET_ACTION}" = "" ]; then
    perl -i -pe "s|APP_CORS_ORIGIN_QA=.*|APP_CORS_ORIGIN_QA=${APP_CORS_ORIGIN_QA_LOCAL}|g" "${ENV_FILESPEC}"
    set -o allexport; . ${ENV_FILESPEC}; set +o allexport ;
fi

if [ "${TARGET_STAGE}" = "qa" ] && [ "${TARGET_ACTION}" = "http" ]; then
    echo "APP_CORS_ORIGIN_QA before: ${APP_CORS_ORIGIN_QA}"
    export APP_CORS_ORIGIN_QA=$(echo $APP_CORS_ORIGIN_QA | perl -i -pe 's|https:|http:|')
    echo "APP_CORS_ORIGIN_QA after: ${APP_CORS_ORIGIN_QA}"
fi

if [ "${TARGET_STAGE}" == "mongo_docker" ]; then
    export APP_STAGE="dev"
    APP_DB_NAME_DEV="mongo"
    APP_DB_URI_DEV="mongodb://root:example@127.0.0.1:27017/"
else
    export APP_STAGE="${TARGET_STAGE}"
fi

echo ""
echo ">> Copying '${CONFIG_TEMPLATE}' to '${CONFIG_FILE}'"
cp -f "${CONFIG_TEMPLATE}" "${CONFIG_FILE}"
echo ""

# Remove things not needed in the deployment
if [ "${TARGET_STAGE}" = "qa" ] && [ "${TARGET_ACTION}" = "deploy" ]; then
    perl -i -pe "s|\"manage_iam_role.*||g" "${CONFIG_FILE}"
    perl -i -pe "s|\"certificate_arn.*||g" "${CONFIG_FILE}"
    perl -i -pe "s|\"certificate_arn_key.*||g" "${CONFIG_FILE}"
    perl -i -pe "s|\"certificate_path.*||g" "${CONFIG_FILE}"
    perl -i -pe "s|\"private_key_path.*||g" "${CONFIG_FILE}"
fi

# Replace @ with \@
APP_SUPERADMIN_EMAIL=${APP_SUPERADMIN_EMAIL//@/\\@}
APP_SECRET_KEY=${APP_SECRET_KEY//@/\\@}

APP_DB_URI_DEV=${APP_DB_URI_DEV//@/\\@}
APP_DB_URI_QA=${APP_DB_URI_QA//@/\\@}
APP_DB_URI_STAGING=${APP_DB_URI_STAGING//@/\\@}
APP_DB_URI_PROD=${APP_DB_URI_PROD//@/\\@}
APP_DB_URI_DEMO=${APP_DB_URI_DEMO//@/\\@}

if [ "${APP_CORS_ORIGIN_DEV}" = "" ]; then
    APP_CORS_ORIGIN_DEV="*"
fi
if [ "${APP_CORS_ORIGIN_QA}" = "" ]; then
    APP_CORS_ORIGIN_QA="*"
fi
if [ "${APP_CORS_ORIGIN_STAGING}" = "" ]; then
    APP_CORS_ORIGIN_STAGING="*"
fi
if [ "${APP_CORS_ORIGIN_PROD}" = "" ]; then
    APP_CORS_ORIGIN_PROD="*"
fi
if [ "${APP_CORS_ORIGIN_DEMO}" = "" ]; then
    APP_CORS_ORIGIN_DEMO="*"
fi

perl -i -pe"s|APP_NAME_LOWERCASE_placeholder|${APP_NAME_LOWERCASE}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_NAME_placeholder|${APP_NAME}|g" "${CONFIG_FILE}"
perl -i -pe"s|AI_ASSISTANT_NAME_placeholder|${AI_ASSISTANT_NAME}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_VERSION_placeholder|${APP_VERSION}|g" "${CONFIG_FILE}"
perl -i -pe"s|FLASK_APP_placeholder|${FLASK_APP}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DEBUG_placeholder|${APP_DEBUG}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_STAGE_placeholder|${APP_STAGE}|g" "${CONFIG_FILE}"
perl -i -pe"s|CURRENT_FRAMEWORK_placeholder|${CURRENT_FRAMEWORK}|g" "${CONFIG_FILE}"
perl -i -pe"s|DEFAULT_LANG_placeholder|${DEFAULT_LANG}|g" "${CONFIG_FILE}"

perl -i -pe"s|GIT_SUBMODULE_URL_placeholder|${GIT_SUBMODULE_URL}|g" "${CONFIG_FILE}"
perl -i -pe"s|GIT_SUBMODULE_LOCAL_PATH_placeholder|${GIT_SUBMODULE_LOCAL_PATH}|g" "${CONFIG_FILE}"

perl -i -pe"s|APP_SUPERADMIN_EMAIL_placeholder|${APP_SUPERADMIN_EMAIL}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_SECRET_KEY_placeholder|${APP_SECRET_KEY}|g" "${CONFIG_FILE}"
perl -i -pe"s|STORAGE_URL_SEED_placeholder|${STORAGE_URL_SEED}|g" "${CONFIG_FILE}"

perl -i -pe"s|OPENAI_API_KEY_placeholder|${OPENAI_API_KEY}|g" "${CONFIG_FILE}"
perl -i -pe"s|OPENAI_MODEL_placeholder|${OPENAI_MODEL}|g" "${CONFIG_FILE}"
perl -i -pe"s|OPENAI_TEMPERATURE_placeholder|${OPENAI_TEMPERATURE}|g" "${CONFIG_FILE}"
perl -i -pe"s|GOOGLE_API_KEY_placeholder|${GOOGLE_API_KEY}|g" "${CONFIG_FILE}"
perl -i -pe"s|GOOGLE_CSE_ID_placeholder|${GOOGLE_CSE_ID}|g" "${CONFIG_FILE}"
perl -i -pe"s|LANGCHAIN_API_KEY_placeholder|${LANGCHAIN_API_KEY}|g" "${CONFIG_FILE}"
perl -i -pe"s|LANGCHAIN_PROJECT_placeholder|${LANGCHAIN_PROJECT}|g" "${CONFIG_FILE}"
perl -i -pe"s|HUGGINGFACE_API_KEY_placeholder|${HUGGINGFACE_API_KEY}|g" "${CONFIG_FILE}"
perl -i -pe"s|HUGGINGFACE_ENDPOINT_URL_placeholder|${HUGGINGFACE_ENDPOINT_URL}|g" "${CONFIG_FILE}"

perl -i -pe"s|SMTP_SERVER_placeholder|${SMTP_SERVER}|g" "${CONFIG_FILE}"
perl -i -pe"s|SMTP_PORT_placeholder|${SMTP_PORT}|g" "${CONFIG_FILE}"
perl -i -pe"s|SMTP_USER_placeholder|${SMTP_USER}|g" "${CONFIG_FILE}"
perl -i -pe"s|SMTP_PASSWORD_placeholder|${SMTP_PASSWORD}|g" "${CONFIG_FILE}"
perl -i -pe"s|SMTP_DEFAULT_SENDER_placeholder|${SMTP_DEFAULT_SENDER}|g" "${CONFIG_FILE}"

# perl -i -pe"s|API_GATEWAY_STAGE_placeholder|${AWS_API_GATEWAY_STAGE}|g" "${CONFIG_FILE}"

perl -i -pe"s|APP_HOST_NAME_DEV_placeholder|${DOMAIN_NAME_DEV}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_ENGINE_DEV_placeholder|${APP_DB_ENGINE_DEV}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_NAME_DEV_placeholder|${APP_DB_NAME_DEV}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_URI_DEV_placeholder|${APP_DB_URI_DEV}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_CORS_ORIGIN_DEV_placeholder|${APP_CORS_ORIGIN_DEV}|g" "${CONFIG_FILE}"
perl -i -pe"s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_DEV_placeholder|${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_DEV}|g" "${CONFIG_FILE}"

perl -i -pe"s|APP_HOST_NAME_QA_placeholder|${DOMAIN_NAME_QA}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_ENGINE_QA_placeholder|${APP_DB_ENGINE_QA}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_NAME_QA_placeholder|${APP_DB_NAME_QA}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_URI_QA_placeholder|${APP_DB_URI_QA}|g" "${CONFIG_FILE}"

echo "perl -i -pe\"s|APP_CORS_ORIGIN_QA_placeholder|${APP_CORS_ORIGIN_QA}|g\" \"${CONFIG_FILE}\""
perl -i -pe"s|APP_CORS_ORIGIN_QA_placeholder|${APP_CORS_ORIGIN_QA}|g" "${CONFIG_FILE}"

perl -i -pe"s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_QA_placeholder|${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_QA}|g" "${CONFIG_FILE}"

perl -i -pe"s|APP_HOST_NAME_STAGING_placeholder|${DOMAIN_NAME_STAGING}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_ENGINE_STAGING_placeholder|${APP_DB_ENGINE_STAGING}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_NAME_STAGING_placeholder|${APP_DB_NAME_STAGING}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_URI_STAGING_placeholder|${APP_DB_URI_STAGING}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_CORS_ORIGIN_STAGING_placeholder|${APP_CORS_ORIGIN_STAGING}|g" "${CONFIG_FILE}"
perl -i -pe"s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_STAGING_placeholder|${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_STAGING}|g" "${CONFIG_FILE}"

perl -i -pe"s|APP_HOST_NAME_DEMO_placeholder|${DOMAIN_NAME_DEMO}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_ENGINE_DEMO_placeholder|${APP_DB_ENGINE_DEMO}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_NAME_DEMO_placeholder|${APP_DB_NAME_DEMO}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_URI_DEMO_placeholder|${APP_DB_URI_DEMO}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_CORS_ORIGIN_DEMO_placeholder|${APP_CORS_ORIGIN_DEMO}|g" "${CONFIG_FILE}"
perl -i -pe"s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_DEMO_placeholder|${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_DEMO}|g" "${CONFIG_FILE}"

perl -i -pe"s|APP_HOST_NAME_PROD_placeholder|${DOMAIN_NAME_PROD}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_ENGINE_PROD_placeholder|${APP_DB_ENGINE_PROD}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_NAME_PROD_placeholder|${APP_DB_NAME_PROD}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_URI_PROD_placeholder|${APP_DB_URI_PROD}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_CORS_ORIGIN_PROD_placeholder|${APP_CORS_ORIGIN_PROD}|g" "${CONFIG_FILE}"
perl -i -pe"s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_PROD_placeholder|${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_PROD}|g" "${CONFIG_FILE}"

perl -i -pe"s|APP_HOST_NAME_placeholder|${APP_HOST_NAME}|g" "${CONFIG_FILE}"
perl -i -pe"s|CLOUD_PROVIDER_placeholder|${CLOUD_PROVIDER}|g" "${CONFIG_FILE}"
perl -i -pe"s|AWS_REGION_placeholder|${AWS_REGION}|g" "${CONFIG_FILE}"

if [ -f "${REPO_BASEDIR}/scripts/aws/update_additional_envvars.sh" ]; then
    . "${REPO_BASEDIR}/scripts/aws/update_additional_envvars.sh" "${CONFIG_FILE}" "${REPO_BASEDIR}"
fi

# if [ "${TARGET_ACTION}" = "deploy" ]; then
#     cat "${CONFIG_FILE}"
# fi

echo ""
echo "Done!"
echo "Updated ${REPO_BASEDIR}/.chalice/config.json"
echo "To settings for ${TARGET_STAGE} environment"
echo ""
