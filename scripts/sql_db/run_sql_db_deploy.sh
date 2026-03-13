#!/bin/bash
# run_sql_db_deploy.sh
# Create Postgres and MySQL tables using SQL scripts.
# 2025-11-30 | CR
# Usage:
# scripts/sql_db/run_sql_db_deploy.sh ACTION TARGET STAGE DEBUG

clear
echo ""
echo "================"
echo "POSTGRES BUILDER"
echo "================"
echo ""

remove_temp_files() {
    if [ "${TMP_BUILD_DIR}" != "" ]; then
        if [ -d "${TMP_BUILD_DIR}" ]; then
            echo "CLEAN-UP: Removing temporary files"
            if rm -rf "${TMP_BUILD_DIR}"
            then
                echo "CLEAN-UP Done"
            else
                echo "CLEAN-UP Failed"
            fi
        fi
    fi
}

exit_abort() {
    echo ""
    echo "Aborting..."
    echo ""
    remove_temp_files
    echo ""
    sh ${SCRIPTS_DIR}/../show_date_time.sh
    exit 1
}

# Basic Variables
REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

AWS_CF_PROCESSOR_SCRIPT="${SCRIPTS_DIR}/../aws_cf_processor/run-cf-deployment.sh"

# Default values
if [ "${CICD_MODE}" = "" ]; then
    CICD_MODE="0"
fi
if [ "${TMP_BUILD_DIR}" = "" ]; then
    TMP_BUILD_DIR="/tmp/${APP_NAME_LOWERCASE}_sql_db_tmp"
fi

# Script parameters
if [ "$1" != "" ]; then
    ACTION="$1"
fi
if [ "$2" != "" ]; then
    TARGET="$2"
fi
if [ "$3" != "" ]; then
    STAGE="$3"
fi
if [ "$4" != "" ]; then
    DEBUG="$4"
fi

# Script parameters validations
if [ "${ACTION}" = "" ]; then
    # echo "ERROR: ACTION not set. Options: create, update, delete, describe"
    echo "ERROR: ACTION not set. Options: run, destroy, describe, list_tables"
    exit_abort
fi
if [ "${TARGET}" = "" ]; then
    echo "ERROR: TARGET not set. Options: postgres, mysql"
    exit_abort
fi
if [ "${STAGE}" = "" ]; then
    echo "ERROR: STAGE not set. Options: dev, qa, staging, demo, prod"
    exit_abort
fi

prepare_working_environment() {
    # Get and validate environment variables
    set -o allexport ; . .env ; set +o allexport ;

    if [ "${APP_NAME}" = "" ]; then
        echo "ERROR: APP_NAME environment variable not set"
        exit_abort
    fi

    if [ "${AWS_REGION}" = "" ]; then
        echo "ERROR: AWS_REGION not set"
        exit_abort
    fi

    if [ "${APP_DOMAIN_NAME}" = "" ]; then
        echo "ERROR: APP_DOMAIN_NAME not set"
        exit_abort
    fi

    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output json --no-paginate | jq -r '.Account')
    if [ "${AWS_ACCOUNT_ID}" = "" ]; then
        echo "ERROR: AWS_ACCOUNT_ID not set"
        if [ "${ENGINE}" != "localstack" ]; then
            exit_abort
        fi
    fi

    # Working variables
    STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')
    APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

    # Temporary template file
    # TMP_CF_TEMPLATE_FILE="${TMP_BUILD_DIR}/template.yaml"

    CF_STACK_NAME_P1="${APP_NAME_LOWERCASE}-${STAGE}-postgres"
    CF_TEMPLATE_FILE_P1="cf-template-postgres.yml"
}

run_cf_templates_creation() {
    if [ "${TARGET}" = "postgres" ] || [ "${TARGET}" = "mysql" ]; then
        local cf_template_file_p1_path="${REPO_BASEDIR}/scripts/sql_db/${CF_TEMPLATE_FILE_P1}"

        # DynamoDB template parameters
        CF_STACK_PARAMETERS="ParameterKey=AppName,ParameterValue='${APP_NAME_LOWERCASE}' ParameterKey=AppStage,ParameterValue='${STAGE}'"

        # Validate the create DynamoDB template
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "validate" "${STAGE}" "${CF_STACK_NAME_P1}" "${CF_STACK_PARAMETERS}" "${cf_template_file_p1_path}" ""
        then
            exit_abort
        fi

        # Run the create DynamoDB template
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "run" "${STAGE}" "${CF_STACK_NAME_P1}" "${CF_STACK_PARAMETERS}" "${cf_template_file_p1_path}" ""
        then
            exit_abort
        fi

        # List DynamoDB tables
        list_tables
    fi
}

run_cf_templates_destroy() {
    if [ "${TARGET}" = "postgres" ] || [ "${TARGET}" = "mysql" ]; then
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "destroy" "${STAGE}" "${CF_STACK_NAME_P1}" "" "" ""
        then
            exit_abort
        fi
    fi
}

run_cf_templates_describe() {
    if [ "${TARGET}" = "postgres" ] || [ "${TARGET}" = "mysql" ]; then
        if ! sh ${AWS_CF_PROCESSOR_SCRIPT} "describe" "${STAGE}" "${CF_STACK_NAME_P1}" "" "" ""
        then
            exit_abort
        fi
    fi
}

get_postgres_credentials() {
    # Regular expression to capture components of the URL
    # Format: scheme://[user[:password]@]host[:port][/dbname][?params]
    REGEX="^postgresql://([^:]+):([^@]+)@([^:]+):?([0-9]+)?/([^?]+)?(.*)"

    POSTGRES_URL="${APP_DB_URI}/${APP_DB_NAME}"

    if [[ $POSTGRES_URL =~ $REGEX ]]; then
        export DB_USER="${BASH_REMATCH[1]}"
        export DB_PASSWORD="${BASH_REMATCH[2]}"
        export DB_HOST="${BASH_REMATCH[3]}"
        export DB_PORT="${BASH_REMATCH[4]}"
        export DB_NAME="${BASH_REMATCH[5]}"
        # Optional: extract query parameters if needed
        export DB_PARAMS="${BASH_REMATCH[6]}"

        echo "Postgres configuration:"
        echo "User:     $DB_USER"
        # echo "Password: $DB_PASSWORD"
        echo "Host:     $DB_HOST"
        echo "Port:     $DB_PORT"
        echo "Database: $DB_NAME"
        echo ""
    else
        echo "Invalid Postgres URL format"
        exit 1
    fi
}

get_mysql_credentials() {
    # Regular expression to capture components of the URL
    # Format: scheme://[user[:password]@]host[:port][/dbname][?params]
    REGEX="^mysql://([^:]+):([^@]+)@([^:]+):?([0-9]+)?/([^?]+)?(.*)"

    MYSQL_URL="${APP_DB_URI}/${APP_DB_NAME}"

    if [[ $MYSQL_URL =~ $REGEX ]]; then
        export DB_USER="${BASH_REMATCH[1]}"
        export DB_PASSWORD="${BASH_REMATCH[2]}"
        export DB_HOST="${BASH_REMATCH[3]}"
        export DB_PORT="${BASH_REMATCH[4]}"
        export DB_NAME="${BASH_REMATCH[5]}"
        # Optional: extract query parameters if needed
        export DB_PARAMS="${BASH_REMATCH[6]}"

        echo "MySQL configuration:"
        echo "User:     $DB_USER"
        # echo "Password: $DB_PASSWORD"
        echo "Host:     $DB_HOST"
        echo "Port:     $DB_PORT"
        echo "Database: $DB_NAME"
        echo ""
    else
        echo "Invalid MySQL URL format"
        exit 1
    fi
}

run_postgres_sql() {
    local sql_query="$1"
    get_postgres_credentials
    DB_RESPONSE_ERROR="false"
    if ! DB_RESPONSE=$(PGPASSWORD="$DB_PASSWORD" psql -q -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "${sql_query}")
    then
        DB_RESPONSE_ERROR="true"
    fi
}

run_mysql_sql() {
    local sql_query="$1"
    get_mysql_credentials
    DB_RESPONSE_ERROR="false"
    if ! DB_RESPONSE=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASSWORD}" -e "USE ${DB_NAME}; ${sql_query};")
    then
        DB_RESPONSE_ERROR="true"
    fi
}

list_tables() {
    if [ "${TARGET}" = "postgres" ]; then
        echo ""
        echo "Listing Postgres tables..."
        echo ""
    

        run_postgres_sql "SELECT table_name FROM information_schema.tables WHERE table_schema='public';"
        if [ "${DB_RESPONSE_ERROR}" = "false" ]; then
            echo "db_response: ${DB_RESPONSE}"
        else
            echo ""
            echo "Error listing tables. Press any key to continue or CTRL+C to exit..."
            read response
        fi
    fi

    if [ "${TARGET}" = "mysql" ]; then
        echo ""
        echo "Listing MySQL tables..."
        echo ""
    
        run_mysql_sql "SHOW TABLES;"
        if [ "${DB_RESPONSE_ERROR}" = "false" ]; then
            echo "db_response: ${DB_RESPONSE}"
        else
            echo ""
            echo "Error listing tables. Press any key to continue or CTRL+C to exit..."
            read response
        fi
    fi

    echo ""
    echo "Listing superadmin user..."
    echo ""

    SQL_QUERY="SELECT * FROM users WHERE email = '${APP_SUPERADMIN_EMAIL}';"

    if [ "${TARGET}" = "postgres" ]; then
        CORRECT_RESPONSE="(0 rows)"
        run_postgres_sql "${SQL_QUERY}"
    elif [ "${TARGET}" = "mysql" ]; then
        CORRECT_RESPONSE="Empty set"
        run_mysql_sql "${SQL_QUERY}"
    fi

    if [ "${DB_RESPONSE_ERROR}" = "false" ]; then
        echo "db_response: ${DB_RESPONSE}"
        # If db_response contains "(0 rows)", it means the user doesn't exist
        if [[ "${DB_RESPONSE}" == *"${CORRECT_RESPONSE}"* ]]; then
            echo "Superadmin user doesn't exist"
        fi
    else
        echo ""
        echo "Error listing superadmin user. Press any key to continue or CTRL+C to exit..."
        read response
    fi
}

localstack_venv() {
    if [ ! -d "venv" ]; then
        echo "[INFO|EC2] - Creating virtual environment..."
        python3 -m venv venv
        if [ -f localstack_requirements.txt ]; then
            pip install -r localstack_requirements.txt
        fi
    fi
    . venv/bin/activate
}

set_database_parameters() {
    export APP_DB_ENGINE=$(eval echo \$APP_DB_ENGINE_${STAGE_UPPERCASE})
    export APP_DB_NAME=$(eval echo \$APP_DB_NAME_${STAGE_UPPERCASE})
    export APP_DB_URI=$(eval echo \$APP_DB_URI_${STAGE_UPPERCASE})
    if [ "${APP_DB_ENGINE}" != "POSTGRES" ]; then
        echo "Error: APP_DB_ENGINE envvar is not set to POSTGRES: ${APP_DB_ENGINE}"
        exit 1
    fi
    if [ "${APP_DB_URI}" = "" ]; then
        echo "Error: APP_DB_URI envvar is not set."
        exit 1
    fi
    if [ "${APP_DB_NAME}" = "" ]; then
        echo "Error: APP_DB_NAME envvar is not set."
        exit 1
    fi
}

check_requirements() {
    if [ "${TARGET}" = "postgres" ]; then
        # Check postgres cli is installed
        if ! which psql
        then
            echo "ERROR: please install postgres-cli"
            echo "E.g. brew install postgresql"
            exit 1
        fi
    fi
    if [ "${TARGET}" = "mysql" ]; then
        # Check mysql cli is installed
        if ! which mysql
        then
            echo "ERROR: please install mysql-cli"
            echo "E.g. brew install mysql"
            exit 1
        fi
    fi
}

show_summary() {
    echo "Action (ACTION): ${ACTION}"
    echo "Stage (STAGE): ${STAGE}"
    echo "Target (TARGET): ${TARGET}"
    echo ""
    echo "* Parameters from the '.env' file:"
    echo ""
    echo "Repository base directory (REPO_BASEDIR): ${REPO_BASEDIR}"
    echo "Application name (APP_NAME): ${APP_NAME}"
    echo ""
    echo "* Working parameters:"
    echo ""
    echo "Postgres prefix for the tables: ${APP_NAME_LOWERCASE}_${STAGE}_"
    echo ""

    if [ "${CICD_MODE}" = "0" ]; then
        echo "Press Enter to proceed with the `echo ${TARGET} | tr '[:lower:]' '[:upper:]'` CloudFormation Stack processing..."
        read -r
    fi
}

# Main

prepare_working_environment
show_summary

set_database_parameters
check_requirements

ERROR="1"

if [ "${ACTION}" = "run" ]; then
    run_cf_templates_creation
    ERROR="0"
fi

if [ "${ACTION}" = "destroy" ]; then
    ERROR="0"
    run_cf_templates_destroy
fi

if [ "${ACTION}" = "describe" ]; then
    run_cf_templates_describe
    ERROR="0"
fi

if [ "${ACTION}" = "list_tables" ]; then
    list_tables
    ERROR="0"
fi

remove_temp_files

if [ "${ERROR}" = "1" ]; then
    echo ""
    echo "Unknown action: '${ACTION}'"
    exit_abort
fi

echo "Done"
echo ""
