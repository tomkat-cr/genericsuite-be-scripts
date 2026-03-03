#!/bin/bash
# scripts/run_create_supad.sh
# 2024-09-09 | CR
# Prerequisites:
#   MongoDB:
#       https://www.mongodb.com/docs/mongodb-shell/install/
#       brew install mongosh
#   DynamoDB:
#       https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
#       curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
#       sudo installer -pkg AWSCLIV2.pkg -target /
#   Postgres:
#       https://www.postgresql.org/download/
#       brew install postgresql
#
REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

set -o allexport ; . .env ; set +o allexport ;

echo ""
echo "Super Admin Creation Script"
echo ""

if [ "${STAGE}" = "" ]; then
    STAGE="$1"
fi
if [ "${STAGE}" = "" ]; then
    echo "Error: STAGE envvar is not set."
    exit 1
fi

echo "Stage: ${STAGE}"

if [ "${ENVIRONMENT}" = "" ]; then
    ENVIRONMENT="$1"
fi
if [ "${ENVIRONMENT}" = "" ]; then
    ENVIRONMENT="${STAGE}"
fi

ENVIRONMENT=$(echo "${STAGE}" | tr '[:upper:]' '[:lower:]')
echo "Environment: ${ENVIRONMENT}"

if [ "${PROTOCOL}" = "" ]; then
    PROTOCOL="$2"
fi
if [ "${PROTOCOL}" = "" ]; then
    PROTOCOL="http"
fi

echo "Protocol: ${PROTOCOL}"

if [ "${DOMAIN_NAME}" = "" ]; then
    DOMAIN_NAME="$3"
fi
if [ "${DOMAIN_NAME}" = "" ]; then
    EXTRA_PARAMS=""
    if [ "${ENVIRONMENT}" = "dev" ]; then
        EXTRA_PARAMS="local"
    fi
    . "${SCRIPTS_DIR}/get_domain_name.sh" "${ENVIRONMENT}" "${EXTRA_PARAMS}"
fi

if [ -z "${DOMAIN_NAME}" ]; then
    echo "Error: Could not determine domain name."
    exit 1
fi

BACKEND_LOCAL_PORT="${BACKEND_LOCAL_PORT}"
if [ "${ENVIRONMENT}" = "dev" ] && [ -n "${BACKEND_LOCAL_PORT}" ]; then
    DOMAIN_NAME="${DOMAIN_NAME}:${BACKEND_LOCAL_PORT}"
fi

echo "Domain name: ${DOMAIN_NAME}"

if [ "${API_VERSION}" = "" ]; then
    API_VERSION="v1"
fi

if [ -z "$APP_SUPERADMIN_EMAIL" ] || [ -z "$APP_SECRET_KEY" ]; then
    echo "Error: APP_SUPERADMIN_EMAIL and/or APP_SECRET_KEY environment variables are not set."
    exit 1
fi

echo ""
echo "Create initial user: ${APP_SUPERADMIN_EMAIL}"
echo ""

# Combine username and APP_SECRET_KEY with a colon
CREDENTIALS="${APP_SUPERADMIN_EMAIL}:${APP_SECRET_KEY}"

# Encode the credentials using base64
BASIC_AUTH=$(printf %s "$CREDENTIALS" | base64 -w 0)

echo "Credentials: ${APP_SUPERADMIN_EMAIL}:*****"
echo "Basic auth: ${BASIC_AUTH}"

echo ""
echo "Running the user creation..."
echo ""

if ! curl --location --request POST "${PROTOCOL}://${DOMAIN_NAME}/${API_VERSION}/users/supad-create" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Basic ${BASIC_AUTH}" \
    --data ''
then
    echo "ERROR: initial user creation wasn't done"
    exit 1
fi

echo ""
echo "Done!"
