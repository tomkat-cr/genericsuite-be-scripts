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

if [ "${STAGE}" = "" ]; then
    STAGE="$1"
fi
if [ "${STAGE}" != "dev" ]; then
    echo "Error: Invalid stage: ${STAGE}"
    exit 1
fi

if [ "${PROTOCOL}" = "" ]; then
    PROTOCOL="$2"
fi
if [ "${PROTOCOL}" = "" ]; then
    PROTOCOL="http"
fi

if [ "${DOMAIN_NAME}" = "" ]; then
    DOMAIN_NAME="$3"
fi
if [ "${DOMAIN_NAME}" = "" ]; then
    set -o allexport ; . .env ; set +o allexport ;
    . "${SCRIPTS_DIR}/get_domain_name.sh" dev local
fi

if [ -z "${DOMAIN_NAME}" ]; then
    echo "Error: Could not determine domain name."
    exit 1
fi

if [ "${API_VERSION}" = "" ]; then
    API_VERSION="v1"
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

if [ "${APP_DB_ENGINE_DEV}" == "DYNAMODB" ]; then
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

if [ "${APP_DB_ENGINE_DEV}" == "MONGODB" ]; then
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
    if ! mongosh "${ENDPOINT_URL}" "${APP_DB_NAME_DEV}" "db.users.find()"
    then
        CREATE_USER="1"
    fi
fi

if [ "${APP_DB_ENGINE_DEV}" == "POSTGRES" ]; then
    # Verify existence of the user $APP_SUPERADMIN_EMAIL in the Local Postgres users table
    # if db_response=$(docker exec postgres-local psql -tAq -U user -d pass -h localhost -p 5432 -d db -c "SELECT * FROM users WHERE email = '${APP_SUPERADMIN_EMAIL}';")
    if db_response=$(docker exec postgres-local psql -q -U user -d pass -h localhost -p 5432 -d db -c "SELECT * FROM users WHERE email = '${APP_SUPERADMIN_EMAIL}';")
    then
        echo "db_response: ${db_response}"
        # If db_response contains "(0 rows)", it means the user doesn't exist
        if [[ "${db_response}" == *"(0 rows)"* ]]; then
            CREATE_USER="1"
        fi
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
