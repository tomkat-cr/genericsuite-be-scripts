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
if ! apt-get install -y git
then
    echo ""
    echo "Error installing OS dependencies"
    exit 1
fi
echo ""
echo "Installing Python dependencies..."
# pip install --trusted-host pypi.python.org -r requirements.txt
if ! pip install -r requirements.txt ; then
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

APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
STAGE_UPPERCASE=$(echo $STAGE | tr '[:lower:]' '[:upper:]')

SSL_KEY_PATH="./app.${APP_NAME_LOWERCASE}.local.key"
SSL_CERT_PATH="./app.${APP_NAME_LOWERCASE}.local.chain.crt"
SSL_CA_CERT_PATH="./ca.crt"

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
export APP_DB_URI=$(eval echo \$APP_DB_URI_${STAGE_UPPERCASE})
export APP_CORS_ORIGIN="$(eval echo \"\$APP_CORS_ORIGIN_${STAGE_UPPERCASE}\")"
export AWS_S3_CHATBOT_ATTACHMENTS_BUCKET=$(eval echo \$AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_${STAGE_UPPERCASE})

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
echo "SSL key certificate path: ${SSL_KEY_PATH}"
echo "SSL chain certificate path: ${SSL_CERT_PATH}"
echo "SSL CA certificate path: ${SSL_CA_CERT_PATH}"
echo ""

echo ""
echo "Stating application..."

if [ "${CURRENT_FRAMEWORK}" = "fastapi" ]; then
    # Start FastAPI application
    echo "uvicorn ${APP_DIR}.${APP_MAIN_FILE}:app --ssl-keyfile=${SSL_KEY_PATH} --ssl-certfile=${SSL_CERT_PATH} --reload --host 0.0.0.0 --port ${PORT}"
    uvicorn ${APP_DIR}.${APP_MAIN_FILE}:app --reload --host 0.0.0.0 --port ${PORT}  # --ca-certs=${SSL_CA_CERT_PATH}
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
