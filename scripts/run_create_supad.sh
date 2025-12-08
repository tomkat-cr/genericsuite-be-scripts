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

echo "Domain name: ${DOMAIN_NAME}"

if [ "${API_VERSION}" = "" ]; then
    API_VERSION="v1"
fi

if [ -z "$APP_SUPERADMIN_EMAIL" ] || [ -z "$APP_SECRET_KEY" ]; then
    echo "Error: APP_SUPERADMIN_EMAIL and/or APP_SECRET_KEY environment variables are not set."
    exit 1
fi

if [ "${CHECKING}" = "" ]; then
    CHECKING="0"
fi

if [ "${CHECKING}" = "1" ]; then
    STAGE_UPPERCASE=$(echo "${STAGE}" | tr '[:lower:]' '[:upper:]')
    echo "Stage uppercase: ${STAGE_UPPERCASE}"

    if [ "${STAGE_UPPERCASE}" = "DEV" ]; then

        echo "Container engine: ${CONTAINERS_ENGINE}"
        if [ "${CONTAINERS_ENGINE}" = "" ]; then
            echo "Error: CONTAINERS_ENGINE envvar is not set."
            exit 1
        fi

        if [ -z "${DOCKER_CMD}" ];then
            if ! . ${SCRIPTS_DIR}/container_engine_manager.sh start "${CONTAINERS_ENGINE}" "${OPEN_CONTAINERS_ENGINE_APP}"; then
                echo "ERROR: Running ${SCRIPTS_DIR}/container_engine_manager.sh start \"${CONTAINERS_ENGINE}\" \"${OPEN_CONTAINERS_ENGINE_APP}\""
                exit 1
            fi
        fi

        echo "Containers engine command: ${DOCKER_CMD}"
        if [ -z "${DOCKER_CMD}" ];then
            echo "Error: DOCKER_CMD envvar is not set."
            exit 1
        fi

    fi


    # Verify existence of the user $APP_SUPERADMIN_EMAIL in the users table
    CREATE_USER="0"

    export APP_DB_ENGINE=$(eval echo \$APP_DB_ENGINE_${STAGE_UPPERCASE})
    export APP_DB_NAME=$(eval echo \$APP_DB_NAME_${STAGE_UPPERCASE})
    export APP_DB_URI=$(eval echo \$APP_DB_URI_${STAGE_UPPERCASE})
    export DYNAMDB_PREFIX=$(eval echo \$DYNAMDB_PREFIX_${STAGE_UPPERCASE})

    echo "Database engine: ${APP_DB_ENGINE}"
    echo "Database name: ${APP_DB_NAME}"
    # echo "Database URI: ${APP_DB_URI}"
    echo "DynamoDB prefix: ${DYNAMDB_PREFIX}"
    echo ""

    if [ "${APP_DB_ENGINE}" == "" ]; then
        echo "Error: APP_DB_ENGINE envvar is not set."
        exit 1
    fi

    if [ "${APP_DB_ENGINE}" == "DYNAMODB" ]; then
        if [ "${DYNAMDB_PREFIX}" = "" ]; then
            echo "Error: DYNAMDB_PREFIX envvar is not set."
            exit 1
        fi
        if [ "${AWS_REGION}" = "" ]; then
            echo "AWS_REGION envvar is not set"
            exit 1
        fi

        if [ "${APP_DB_URI}" != "" ]; then
            APP_DB_URI="--endpoint-url ${APP_DB_URI}"
        fi

        if ! which aws > /dev/null
        then
            echo "ERROR: please install aws-cli"
            echo "For more info, visit:"
            echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
            exit 1
        fi

        echo "aws dynamodb scan --table-name ${DYNAMDB_PREFIX}users ${APP_DB_URI} --region ${AWS_REGION} | jq -r \".Items[] | select(.email == \\\"${APP_SUPERADMIN_EMAIL}\\\")\""

        QUERY_RESULT=$(aws dynamodb scan --table-name ${DYNAMDB_PREFIX}users ${APP_DB_URI} --region ${AWS_REGION} | jq -r ".Items[] | select(.email == \"${APP_SUPERADMIN_EMAIL}\")")
        echo "DynamoDB query result: ${QUERY_RESULT}"

        if [ "${QUERY_RESULT}" = "" ]; then
            CREATE_USER="1"
        fi

    elif [ "${APP_DB_ENGINE}" == "MONGODB" ]; then
        
        if [ "${APP_DB_NAME}" == "" ]; then
            echo "Error: APP_DB_NAME envvar is not set."
            exit 1
        fi

        # Verify existence of the user $APP_SUPERADMIN_EMAIL in the Local MongoDB users table

        if [ "${APP_DB_URI}" = "" ]; then
            echo "Error: APP_DB_URI envvar is not set."
            exit 1
        fi
        if [ "${APP_DB_NAME}" = "" ]; then
            echo "Error: APP_DB_NAME envvar is not set."
            exit 1
        fi

        if ! which mongosh
        then
            echo "ERROR: please install mongosh"
            echo "E.g. brew install mongosh"
            exit 1
        fi

        if ! mongosh "${APP_DB_URI}" "${APP_DB_NAME}" "db.users.find()"
        then
            CREATE_USER="1"
        fi

    elif [ "${APP_DB_ENGINE}" == "POSTGRES" ]; then

        if [ "${APP_DB_URI}" = "" ]; then
            echo "Error: APP_DB_URI envvar is not set."
            exit 1
        fi
        if [ "${APP_DB_NAME}" = "" ]; then
            echo "Error: APP_DB_NAME envvar is not set."
            exit 1
        fi

        # Check postgres cli is installed
        if ! which psql
        then
            echo "ERROR: please install postgres-cli"
            echo "E.g. brew install postgresql"
            # echo "E.g. brew install libpq && brew link --force libpq && psql --version"
            exit 1
        fi

        # Verify existence of the user $APP_SUPERADMIN_EMAIL in the Local Postgres users table

        # db_response=$(${DOCKER_CMD} exec postgres-local psql -q -U user -d pass -h localhost -p 5432 -d "${APP_DB_NAME}" -c "SELECT * FROM users WHERE email = '${APP_SUPERADMIN_EMAIL}';")

        # Regular expression to capture components of the URL
        # Format: scheme://[user[:password]@]host[:port][/dbname][?params]
        REGEX="^postgresql://([^:]+):([^@]+)@([^:]+):?([0-9]+)?/([^?]+)?(.*)"

        POSTGRES_URL="${APP_DB_URI}/${APP_DB_NAME}"

        if [[ $POSTGRES_URL =~ $REGEX ]]; then
            DB_USER="${BASH_REMATCH[1]}"
            DB_PASSWORD="${BASH_REMATCH[2]}"
            DB_HOST="${BASH_REMATCH[3]}"
            DB_PORT="${BASH_REMATCH[4]}"
            DB_NAME="${BASH_REMATCH[5]}"
            # Optional: extract query parameters if needed
            # DB_PARAMS="${BASH_REMATCH[6]}"

            echo "User:     $DB_USER"
            # echo "Password: $DB_PASSWORD"
            echo "Host:     $DB_HOST"
            echo "Port:     $DB_PORT"
            echo "Database: $DB_NAME"
            echo ""
        else
            echo "Invalid PostgreSQL URL format"
            exit 1
        fi

        if db_response=$(PGPASSWORD="$DB_PASSWORD" psql -q -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT * FROM users WHERE email = '${APP_SUPERADMIN_EMAIL}';")
        then
            echo "db_response: ${db_response}"
            # If db_response contains "(0 rows)", it means the user doesn't exist
            if [[ "${db_response}" == *"(0 rows)"* ]]; then
                CREATE_USER="1"
            fi
        else
            echo "Error: ${db_response}"
            exit 1
        fi

    else
        echo "Error: APP_DB_ENGINE value is not valid: ${APP_DB_ENGINE}"
        exit 1
    fi

    if [ "${CREATE_USER}" = "0" ]; then
        echo ""
        echo "Create initial user operation aborted... ${APP_SUPERADMIN_EMAIL} user already exists."
        echo ""
        exit 0
    fi
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
