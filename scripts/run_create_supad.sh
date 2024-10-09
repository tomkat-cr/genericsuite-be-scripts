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
#
REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

STAGE="$1"
if [ "${STAGE}" != "dev" ]; then
    echo "Error: Invalid stage: ${STAGE}"
    exit 1
fi

PROTOCOL="$2"
if [ "${PROTOCOL}" = "" ]; then
    PROTOCOL="http"
fi

DOMAIN_NAME="$3"
if [ "${DOMAIN_NAME}" = "" ]; then
    set -o allexport ; . .env ; set +o allexport ;
    . "${SCRIPTS_DIR}/get_domain_name.sh" dev local
fi

if [ -z "${DOMAIN_NAME}" ]; then
    echo "Error: Could not determine domain name."
    exit 1
fi

if [ -z "$APP_SUPERADMIN_EMAIL" ] || [ -z "$APP_SECRET_KEY" ]; then
    set -o allexport ; . .env ; set +o allexport ;
fi
if [ -z "$APP_SUPERADMIN_EMAIL" ] || [ -z "$APP_SECRET_KEY" ]; then
    echo "Error: APP_SUPERADMIN_EMAIL and/or APP_SECRET_KEY environment variables are not set."
    exit 1
fi

# Verify existence of the user $APP_SUPERADMIN_EMAIL in the users table
CREATE_USER="0"

echo "Database engine: ${APP_DB_ENGINE_DEV}"

if [ "${APP_DB_ENGINE_DEV}" == "DYNAMO_DB" ]; then
    if [ "${DYNAMDB_PREFIX}" = "" ]; then
        DYNAMDB_PREFIX=$(eval echo \$DYNAMDB_PREFIX_${STAGE_UPPERCASE})
        if [ "${DYNAMDB_PREFIX}" = "" ]; then
            DYNAMDB_PREFIX="${APP_NAME_LOWERCASE}_${STAGE}_"
        fi
    fi
    ENDPOINT_URL="${DYNAMODB_LOCAL_ENDPOINT_URL}"
    if [ "${ENDPOINT_URL}" = "" ]; then
        ENDPOINT_URL="http://127.0.0.1:8000"
    fi
    if [ "${AWS_REGION}" = "" ]; then
        echo "AWS_REGION envvar is not set"
        exit 1
    fi
    if ! which aws > /dev/null
    then
        echo "ERROR: please install aws-cli"
        exit 1
    fi
    echo "aws dynamodb scan --table-name ${DYNAMDB_PREFIX}users --endpoint-url ${ENDPOINT_URL} --region ${AWS_REGION} | jq -r \".Items[] | select(.email == \\\"${APP_SUPERADMIN_EMAIL}\\\")\""
    QUERY_RESULT=$(aws dynamodb scan --table-name ${DYNAMDB_PREFIX}users --endpoint-url ${ENDPOINT_URL} --region ${AWS_REGION} | jq -r ".Items[] | select(.email == \"${APP_SUPERADMIN_EMAIL}\")")
    echo "DynamoDB query result: ${QUERY_RESULT}"
    if [ "${QUERY_RESULT}" = "" ]; then
        CREATE_USER="1"
    fi
fi

if [ "${APP_DB_ENGINE_DEV}" == "MONGO_DB" ]; then
    # Verify existence of the user $APP_SUPERADMIN_EMAIL in the Local MongoDB users table
    ENDPOINT_URL="${MONGODB_LOCAL_ENDPOINT_URL}"
    if [ "${ENDPOINT_URL}" = "" ]; then
        ENDPOINT_URL="mongodb://127.0.0.1:27017"
    fi
    if ! which mongosh
    then
        echo "ERROR: please install mongosh"
        exit 1
    fi
    if ! echo "use ${APP_DB_NAME_DEV} ; db.users.find()" | mongosh
    then
        CREATE_USER="1"
    fi
fi

if [ "${CREATE_USER}" = "0" ]; then
    echo "Create initial user operation aborted..."
    exit 0
fi

echo ""
echo "Create initial user: ${APP_SUPERADMIN_EMAIL}"
echo ""

# Combine username and APP_SECRET_KEY with a colon
CREDENTIALS="${APP_SUPERADMIN_EMAIL}:${APP_SECRET_KEY}"

# Encode the credentials using base64
BASIC_AUTH=$(echo -n "$CREDENTIALS" | base64)

echo "Running the user creation..."

if ! curl --location --request POST "${PROTOCOL}://${DOMAIN_NAME}/users/supad-create" \
--header 'Content-Type: application/json' \
--header "Authorization: Basic ${BASIC_AUTH}" \
--data ''
then
    echo "ERROR: initial user creation wasn't done"
    exit 1
fi

echo ""
echo ""
echo "Done!"
