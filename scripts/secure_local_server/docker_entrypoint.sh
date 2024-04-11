#!/bin/bash
# scripts/secure_local_server/docker_entrypoint.sh
# 2023-12-01 | CR
# Make sure it's executable:
# chmod +x scripts/secure_local_server/docker_entrypoint.sh

cd /app

# Load environment variables from .env
set -o allexport
source .env
set +o allexport

# Install OS dependencies
apt-get update -y
apt-get install -y git

# Install Python dependencies
pip install --trusted-host pypi.python.org -r requirements.txt

ls -la

APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
SSL_KEY_PATH="./app.${APP_NAME_LOWERCASE}.local.key"
SSL_CERT_PATH="./app.${APP_NAME_LOWERCASE}.local.chain.crt"
SSL_CA_CERT_PATH="./ca.crt"

PORT="8000"

echo ""
echo "Current App: ${APP_NAME}"
echo "Stage: ${STAGE}"
echo "Current Framework: ${CURRENT_FRAMEWORK}"
echo "Python version: $(python --version)"
echo "Port: ${PORT}"
echo "SSL key certificate path: ${SSL_KEY_PATH}"
echo "SSL chain certificate path: ${SSL_CERT_PATH}"
echo "SSL CA certificate path: ${SSL_CA_CERT_PATH}"
echo ""

if [ "${CURRENT_FRAMEWORK}" = "fastapi" ]; then
    echo "uvicorn app:asgi_app --ssl-keyfile=${SSL_KEY_PATH} --ssl-certfile=${SSL_CERT_PATH} --reload --host 0.0.0.0 --port ${PORT}"
    uvicorn app:asgi_app --ssl-keyfile=${SSL_KEY_PATH} --ssl-certfile=${SSL_CERT_PATH} --reload --host 0.0.0.0 --port ${PORT}
fi

if [ "${CURRENT_FRAMEWORK}" = "flask" ]; then
    gunicorn lib.index:app \
            --bind 0.0.0.0:${PORT} \
            --reload \
            --log-level debug \
            --workers=2 \
            --certfile="${SSL_CERT_PATH}" \
            --keyfile="${SSL_KEY_PATH}" \
            --ciphers="TLSv1.2" \
            --forwarded-allow-ips="${IP_ADDRESS},127.0.0.1,0.0.0.0" \
            --env PORT=${PORT} \
            --env APP_STAGE="${STAGE}"
fi

if [ "${CURRENT_FRAMEWORK}" = "chalice" ]; then
    # Start your Chalice application locally
    echo "chalice local --host 0.0.0.0 --port ${PORT} --stage "${STAGE}" --autoreload"
    chalice local --host 0.0.0.0 --port ${PORT} --stage "${STAGE}" --autoreload
fi
echo ""
