#!/bin/sh
# change_local_ip_for_dev.sh
# 2023-11-26 | CR
#
echo "Change the local IP/domain for the dev environment."

BACKEND_BASE_DIR="."
if [ ! -f "${BACKEND_BASE_DIR}/.env" ]; then
    echo "'${BACKEND_BASE_DIR}/.env' does not exist. It's this repository '.env' file..."
    exit 1
fi

set -o allexport; source "${BACKEND_BASE_DIR}/.env"; set +o allexport ;

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 IP_ADDRESS_or_DOMAIN [BACKEND_PORT] [FRONTEND_PORT]"
    exit 1
fi
if [ "${FRONTEND_PATH}" = "" ]; then
    echo "FRONTEND_PATH environment variable not defined"
    exit 1
fi
if [ ! -f "${FRONTEND_PATH}/.env" ]; then
    echo "'${FRONTEND_PATH}/.env' does not exist. Path must be defined in the FRONTEND_PATH environment variable in the .env file..."
    exit 1
fi
IP_ADDRESS_or_DOMAIN=$1
BACKEND_PORT=$2
FRONTEND_PORT=$3
if [ "${BACKEND_PORT}" = "" ]; then
    BACKEND_PORT="5001"
fi
if [ "${FRONTEND_PORT}" = "" ]; then
    FRONTEND_PORT="3000"
fi
HTTP_HTTPS="https"
#
# In the backend:
# APP_CORS_ORIGIN_QA=http://127.0.0.1:3000
# APP_CORS_ORIGIN_QA_LOCAL=http://127.0.0.1:3000
#
perl -i -pe "s|APP_CORS_ORIGIN_QA=.*|APP_CORS_ORIGIN_QA=${HTTP_HTTPS}://${IP_ADDRESS_or_DOMAIN}:${FRONTEND_PORT}|g" "${BACKEND_BASE_DIR}/.env"
perl -i -pe "s|APP_CORS_ORIGIN_QA_LOCAL=.*|APP_CORS_ORIGIN_QA_LOCAL=${HTTP_HTTPS}://${IP_ADDRESS_or_DOMAIN}:${FRONTEND_PORT}|g" ".env"
#
# In the frontend:
# REACT_APP_API_URL=http://127.0.0.1:5001
# REACT_APP_API_URL_DEV=http://127.0.0.1:5001
#
perl -i -pe "s|REACT_APP_API_URL=.*|REACT_APP_API_URL=${HTTP_HTTPS}://${IP_ADDRESS_or_DOMAIN}:${BACKEND_PORT}|g" "${FRONTEND_PATH}/.env"
perl -i -pe "s|REACT_APP_API_URL_DEV=.*|REACT_APP_API_URL_DEV=${HTTP_HTTPS}://${IP_ADDRESS_or_DOMAIN}:${BACKEND_PORT}|g" "${FRONTEND_PATH}/.env"
