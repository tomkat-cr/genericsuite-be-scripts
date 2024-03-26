#!/bin/sh
#
# sh scripts/aws/update_config.sh
# 2023-02-11 | CR
#
APP_DIR='chalicelib'

ENV=$1
TARGET_ACTION=$2
CORS_ORIGIN=$3
ACCOUNT_ID=$4
API_SECRET_KEY=$5
API_ID=$6

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

CONFIG_FILE="${REPO_BASEDIR}/.chalice/config.json"

# ENV_UPPERCASE=$(echo $ENV | tr '[:lower:]' '[:upper:]')

ENV_FILENAME=".env"
ENV_FILESPEC=""
if [ -f "${REPO_BASEDIR}/${ENV_FILENAME}" ]; then
    ENV_FILESPEC="${REPO_BASEDIR}/${ENV_FILENAME}"
fi
if [ -f "${REPO_BASEDIR}/${APP_DIR}/${ENV_FILENAME}" ]; then
    ENV_FILESPEC="${REPO_BASEDIR}/${APP_DIR}/${ENV_FILENAME}v"
fi

APP_VERSION=$(cat ${REPO_BASEDIR}/version.txt)

if [ "$ENV_FILESPEC" != "" ]; then
    set -o allexport; . ${ENV_FILESPEC}; set +o allexport ;
fi

if [ "${APP_NAME}" = "" ]; then
    echo "APP_NAME not set"
    exit 1
fi
export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

if [ "${CURRENT_FRAMEWORK}" = "" ]; then
    echo "CURRENT_FRAMEWORK not set"
    exit 1
fi

if [ "${ENV}" = "qa" ] && [ "${TARGET_ACTION}" = "deploy" ]; then
    perl -i -pe "s|APP_CORS_ORIGIN_QA=.*|APP_CORS_ORIGIN_QA=${APP_CORS_ORIGIN_QA_CLOUD}|g" "${ENV_FILESPEC}"
    set -o allexport; . ${ENV_FILESPEC}; set +o allexport ;
fi

if [ "${ENV}" = "qa" ] && [ "${TARGET_ACTION}" = "" ]; then
    perl -i -pe "s|APP_CORS_ORIGIN_QA=.*|APP_CORS_ORIGIN_QA=${APP_CORS_ORIGIN_QA_LOCAL}|g" "${ENV_FILESPEC}"
    set -o allexport; . ${ENV_FILESPEC}; set +o allexport ;
fi

if [ "${ENV}" = "qa" ] && [ "${TARGET_ACTION}" = "http" ]; then
    echo "APP_CORS_ORIGIN_QA before: ${APP_CORS_ORIGIN_QA}"
    export APP_CORS_ORIGIN_QA=$(echo $APP_CORS_ORIGIN_QA | perl -i -pe 's|https:|http:|')
    echo "APP_CORS_ORIGIN_QA after: ${APP_CORS_ORIGIN_QA}"
fi

if [ "${ENV}" == "mongo_docker" ]; then
    APP_DB_NAME_DEV="mongo"
    APP_DB_URI_DEV="mongodb://root:example@127.0.0.1:27017/"
fi

cp -f ${REPO_BASEDIR}/.chalice/config-example.json "${CONFIG_FILE}"

# Remove things not needed in the deployment
if [ "${ENV}" = "qa" ] && [ "${TARGET_ACTION}" = "deploy" ]; then
    perl -i -pe "s|\"manage_iam_role.*||g" "${ENV_FILESPEC}"
    perl -i -pe "s|\"certificate_arn.*||g" "${ENV_FILESPEC}"
    perl -i -pe "s|\"certificate_arn_key.*||g" "${ENV_FILESPEC}"
    perl -i -pe "s|\"certificate_path.*||g" "${ENV_FILESPEC}"
    perl -i -pe "s|\"private_key_path.*||g" "${ENV_FILESPEC}"
fi

# Replace @ with \@
APP_SUPERADMIN_EMAIL=${APP_SUPERADMIN_EMAIL//@/\\@}
APP_SECRET_KEY=${APP_SECRET_KEY//@/\\@}

APP_DB_URI_DEV=${APP_DB_URI_DEV//@/\\@}
APP_DB_URI_QA=${APP_DB_URI_QA//@/\\@}
APP_DB_URI_STAGING=${APP_DB_URI_STAGING//@/\\@}
APP_DB_URI_PROD=${APP_DB_URI_PROD//@/\\@}

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

perl -i -pe"s|APP_NAME_LOWERCASE_placeholder|${APP_NAME_LOWERCASE}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_NAME_placeholder|${APP_NAME}|g" "${CONFIG_FILE}"
perl -i -pe"s|AI_ASSISTANT_NAME_placeholder|${AI_ASSISTANT_NAME}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_VERSION_placeholder|${APP_VERSION}|g" "${CONFIG_FILE}"
perl -i -pe"s|FLASK_APP_placeholder|${FLASK_APP}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DEBUG_placeholder|${APP_DEBUG}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_STAGE_placeholder|${APP_STAGE}|g" "${CONFIG_FILE}"
perl -i -pe"s|CURRENT_FRAMEWORK_placeholder|${CURRENT_FRAMEWORK}|g" "${CONFIG_FILE}"
perl -i -pe"s|DEFAULT_LANG_placeholder|${DEFAULT_LANG}|g" "${CONFIG_FILE}"

perl -i -pe"s|FDA_API_KEY_placeholder|${FDA_API_KEY}|g" "${CONFIG_FILE}"
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

perl -i -pe"s|GIT_SUBMODULE_URL_placeholder|${GIT_SUBMODULE_URL}|g" "${CONFIG_FILE}"
perl -i -pe"s|GIT_SUBMODULE_LOCAL_PATH_placeholder|${GIT_SUBMODULE_LOCAL_PATH}|g" "${CONFIG_FILE}"

perl -i -pe"s|APP_SECRET_KEY_placeholder|${APP_SECRET_KEY}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_SUPERADMIN_EMAIL_placeholder|${APP_SUPERADMIN_EMAIL}|g" "${CONFIG_FILE}"

perl -i -pe"s|ACCOUNT_ID_placeholder|${ACCOUNT_ID}|g" "${CONFIG_FILE}"
perl -i -pe"s|API_SECRET_KEY_placeholder|${API_SECRET_KEY}|g" "${CONFIG_FILE}"

perl -i -pe"s|API_GATEWAY_STAGE_placeholder|${AWS_API_GATEWAY_STAGE}|g" "${CONFIG_FILE}"

perl -i -pe"s|APP_DB_ENGINE_DEV_placeholder|${APP_DB_ENGINE_DEV}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_NAME_DEV_placeholder|${APP_DB_NAME_DEV}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_URI_DEV_placeholder|${APP_DB_URI_DEV}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_FRONTEND_AUDIENCE_DEV_placeholder|${APP_FRONTEND_AUDIENCE_DEV}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_CORS_ORIGIN_DEV_placeholder|${APP_CORS_ORIGIN_DEV}|g" "${CONFIG_FILE}"
perl -i -pe"s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_DEV_placeholder|${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_DEV}|g" "${CONFIG_FILE}"

perl -i -pe"s|APP_DB_ENGINE_QA_placeholder|${APP_DB_ENGINE_QA}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_NAME_QA_placeholder|${APP_DB_NAME_QA}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_URI_QA_placeholder|${APP_DB_URI_QA}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_FRONTEND_AUDIENCE_QA_placeholder|${APP_FRONTEND_AUDIENCE_QA}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_CORS_ORIGIN_QA_placeholder|${APP_CORS_ORIGIN_QA}|g" "${CONFIG_FILE}"
perl -i -pe"s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_QA_placeholder|${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_QA}|g" "${CONFIG_FILE}"

perl -i -pe"s|APP_DB_ENGINE_STAGING_placeholder|${APP_DB_ENGINE_STAGING}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_NAME_STAGING_placeholder|${APP_DB_NAME_STAGING}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_URI_STAGING_placeholder|${APP_DB_URI_STAGING}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_FRONTEND_AUDIENCE_STAGING_placeholder|${APP_FRONTEND_AUDIENCE_STAGING}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_CORS_ORIGIN_STAGING_placeholder|${APP_CORS_ORIGIN_STAGING}|g" "${CONFIG_FILE}"
perl -i -pe"s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_STAGING_placeholder|${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_STAGING}|g" "${CONFIG_FILE}"

perl -i -pe"s|APP_DB_ENGINE_PROD_placeholder|${APP_DB_ENGINE_PROD}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_NAME_PROD_placeholder|${APP_DB_NAME_PROD}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_DB_URI_PROD_placeholder|${APP_DB_URI_PROD}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_FRONTEND_AUDIENCE_PROD_placeholder|${APP_FRONTEND_AUDIENCE_PROD}|g" "${CONFIG_FILE}"
perl -i -pe"s|APP_CORS_ORIGIN_PROD_placeholder|${APP_CORS_ORIGIN_PROD}|g" "${CONFIG_FILE}"
perl -i -pe"s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_PROD_placeholder|${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_PROD}|g" "${CONFIG_FILE}"

if [ -f "${REPO_BASEDIR}/.chalice/deployed/api.json" ]; then
    if [ "${API_ID}" = "" -o -z "${API_ID}" ]; then
        rm "${REPO_BASEDIR}/.chalice/deployed/api.json"
    else
        perl -i -pe"s|WEBAPP_BACKEND_ID|${API_ID}|g" "${REPO_BASEDIR}/.chalice/deployed/api.json"
        perl -i -pe"s|ACCOUNT_ID|${ACCOUNT_ID}|g" "${REPO_BASEDIR}/.chalice/deployed/api.json"
    fi
fi

# if [ "${TARGET_ACTION}" = "deploy" ]; then
#     cat "${CONFIG_FILE}"
# fi

echo ""
echo "Done!"
echo "Updated ${REPO_BASEDIR}/.chalice/config.json"
echo "To settings for ${ENV} environment"
echo ""
