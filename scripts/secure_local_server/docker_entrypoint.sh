#!/bin/bash
# scripts/secure_local_server/docker_entrypoint.sh
# 2023-12-01 | CR
# Make sure it's executable:
# chmod +x scripts/secure_local_server/docker_entrypoint.sh

cd /app

# Load environment variables from .env
set -o allexport ; . .env ; set +o allexport

# Install OS dependencies
apt-get update -y
apt-get install -y git

# Install Python dependencies
pip install --trusted-host pypi.python.org -r requirements.txt

ls -la

APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
STAGE_UPPERCASE=$(echo $STAGE | tr '[:lower:]' '[:upper:]')

SSL_KEY_PATH="./app.${APP_NAME_LOWERCASE}.local.key"
SSL_CERT_PATH="./app.${APP_NAME_LOWERCASE}.local.chain.crt"
SSL_CA_CERT_PATH="./ca.crt"

PORT="8000"

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

if [ "${CURRENT_FRAMEWORK}" = "fastapi" ]; then
    echo "uvicorn ${APP_DIR}.${APP_MAIN_FILE}:app --ssl-keyfile=${SSL_KEY_PATH} --ssl-certfile=${SSL_CERT_PATH} --reload --host 0.0.0.0 --port ${PORT}"
    # uvicorn ${APP_DIR}.${APP_MAIN_FILE}:app --ssl-keyfile=${SSL_KEY_PATH} --ssl-certfile=${SSL_CERT_PATH} --reload --host 0.0.0.0 --port ${PORT}  # --ca-certs=${SSL_CA_CERT_PATH}
    uvicorn ${APP_DIR}.${APP_MAIN_FILE}:app --reload --host 0.0.0.0 --port ${PORT}  # --ca-certs=${SSL_CA_CERT_PATH}
fi

if [ "${CURRENT_FRAMEWORK}" = "flask" ]; then
    # gunicorn ${APP_DIR}.${APP_MAIN_FILE}:app \
    #         --bind 0.0.0.0:${PORT} \
    #         --reload \
    #         --workers=2 \
    #         --certfile="${SSL_CERT_PATH}" \
    #         --keyfile="${SSL_KEY_PATH}" \
    #         --ciphers="TLSv1.2" \
    #         --proxy-protocol \
    #         --limit-request-field_size=200000 \
    #         --forwarded-allow-ips="${IP_ADDRESS},127.0.0.1,0.0.0.0" \
    #         --do-handshake-on-connect \
    #         --strip-header-spaces \
    #         --env PORT=${PORT} \
    #         --env APP_STAGE="${STAGE}"
    gunicorn ${APP_DIR}.${APP_MAIN_FILE}:app \
            --bind 0.0.0.0:${PORT} \
            --reload \
            --workers=2
fi

if [ "${CURRENT_FRAMEWORK}" = "chalice" ]; then
    # Start your Chalice application locally
    echo "chalice local --host 0.0.0.0 --port ${PORT} --stage "${STAGE}" --autoreload"
    chalice local --host 0.0.0.0 --port ${PORT} --stage "${STAGE}" --autoreload
fi
echo ""
