#!/bin/bash
# scripts/secure_local_server/docker_entrypoint.sh
# 2023-12-01 | CR
# Make sure it's executable:
# chmod +x scripts/secure_local_server/docker_entrypoint.sh

REPO_BASEDIR="/app"
cd "${REPO_BASEDIR}"

echo ""
echo "Loading environment variables from '.env' file..."
set -o allexport ; . .env ; set +o allexport

APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
STAGE_UPPERCASE=$(echo $STAGE | tr '[:lower:]' '[:upper:]')

echo ""
echo "Installing OS updates..."
if ! apt-get update -y
then
    echo ""
    echo "Error updating OS"
    exit 1
fi
echo ""
echo "Installing OS dependencies..."
# gcc libpq-dev are required to compile python dependencies like bottleneck
if ! apt-get install -y git gcc libpq-dev
then
    echo ""
    echo "Error installing OS dependencies"
    exit 1
fi

echo ""
echo "Installing Python dependencies..."
pip install --upgrade pip
#if ! pip install --trusted-host pypi.python.org -r requirements.txt
if ! pip install -r requirements.txt
then
    echo ""
    echo "Error installing Python dependencies"
    exit 1
fi

echo ""
echo "Current working directory content: $(pwd)"
ls -la
if [ "${LOCAL_GE_BE_REPO}" != "" ]; then
    echo ""
    echo "GS BE Directory: ${LOCAL_GE_BE_REPO}"
    ls -la "${LOCAL_GE_BE_REPO}"
fi
if [ "${LOCAL_GE_BE_AI_REPO}" != "" ]; then
    echo ""
    echo "GS BE AI Directory: ${LOCAL_GE_BE_AI_REPO}"
    ls -la "${LOCAL_GE_BE_AI_REPO}"
fi
echo ""

PORT="8000"

echo ""
echo "Getting domain name..."
source /var/scripts/get_domain_name.sh "${STAGE}"
if [ "${DOMAIN_NAME}" = "" ];then
    exit 1
fi
export APP_HOST_NAME="${DOMAIN_NAME}"

export APP_VERSION=$(cat version.txt)
export APP_DB_ENGINE=$(eval echo \$APP_DB_ENGINE_${STAGE_UPPERCASE})
export APP_DB_NAME=$(eval echo \$APP_DB_NAME_${STAGE_UPPERCASE})
export DYNAMDB_PREFIX="${APP_NAME_LOWERCASE}_${STAGE}_"
if [[ "${GET_SECRETS_ENABLED}" = "0" || "${GET_SECRETS_CRITICAL}" = "0" ]]; then
    export APP_DB_URI=$(eval echo \$APP_DB_URI_${STAGE_UPPERCASE})
fi
export APP_CORS_ORIGIN="$(eval echo \"\$APP_CORS_ORIGIN_${STAGE_UPPERCASE}\")"
export AWS_S3_CHATBOT_ATTACHMENTS_BUCKET=$(eval echo \$AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_${STAGE_UPPERCASE})

export APP_STAGE="${STAGE}"
# To avoid message from langsmith:
# USER_AGENT environment variable not set, consider setting it to identify your requests.
export USER_AGENT="${APP_NAME_LOWERCASE}-${STAGE}"

echo ""
echo "Current App / Version: ${APP_NAME} / ${APP_VERSION}"
echo "Stage: ${STAGE}"
echo "Current Framework: ${CURRENT_FRAMEWORK}"
echo "Python entry point (APP_DIR.APP_MAIN_FILE): ${APP_DIR}.${APP_MAIN_FILE}"
echo "DB Engine: ${APP_DB_ENGINE}"
echo "DB Name: ${APP_DB_NAME}"
echo "App CORS Origin: ${APP_CORS_ORIGIN}"
echo "Python version: $(python --version)"
echo "Port: ${PORT}"
echo ""

echo ""
echo "Stating application..."

if [ "${CURRENT_FRAMEWORK}" = "fastapi" ]; then
    # Start FastAPI application
    echo "uvicorn ${APP_DIR}.${APP_MAIN_FILE}:app --reload --host 0.0.0.0 --port ${PORT}"
    uvicorn ${APP_DIR}.${APP_MAIN_FILE}:app --reload --host 0.0.0.0 --port ${PORT}
fi

if [ "${CURRENT_FRAMEWORK}" = "flask" ]; then
    # Start Flask application
    echo "gunicorn ${APP_DIR}.${APP_MAIN_FILE}:app --bind 0.0.0.0:${PORT} --reload --workers=2"
    gunicorn ${APP_DIR}.${APP_MAIN_FILE}:app --bind 0.0.0.0:${PORT} --reload --workers=2
fi

if [ "${CURRENT_FRAMEWORK}" = "chalice" ]; then
    # Start Chalice application
    echo "chalice local --host 0.0.0.0 --port ${PORT} --stage "${STAGE}" --autoreload"
    chalice local --host 0.0.0.0 --port ${PORT} --stage "${STAGE}" --autoreload
fi
echo ""
