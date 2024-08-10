#!/bin/sh
#
# sh scripts/mongo/run_mongo_docker.sh
# 2023-05-21 | CR
#
ERROR=""
#
# cd "`dirname "$0"`" ;
# SCRIPTS_DIR="`pwd`" ;
# REPO_BASEDIR="${SCRIPTS_DIR}/../.."
REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
#
ACTION="$1"
#
if [ "${RUN_LOCAL_APP}" = "" ]; then
    RUN_LOCAL_APP="$2"
fi
if [ "${RUN_LOCAL_APP}" = "" ]; then
    # The local app needs to be started by the tests with "make run"
    # to use the local docker mongo database, so RUN_LOCAL_APP
    # or $2 parameter must be "1". Defaults to "0"
    RUN_LOCAL_APP="0"
fi
#
if [ "${STAGE}" = "" ]; then
    STAGE="$3"
fi
#
echo ""
echo "ACTION: ${ACTION}"
echo "RUN_LOCAL_APP: ${RUN_LOCAL_APP}"
echo "STAGE: ${STAGE}"
#
if cd "${REPO_BASEDIR}"
then
    # REPO_BASEDIR="`pwd`" ;
    echo ""
    echo "Reading '${REPO_BASEDIR}/.env'..."
    echo ""
    if [ -f "${REPO_BASEDIR}/.env" ]; then
        set -o allexport; . "${REPO_BASEDIR}/.env"; set +o allexport ;
    fi
    #
    if [ "${APP_NAME}" = "" ]; then
        echo "APP_NAME environment variable must be defined"
        exit 1
    fi
    if [ "${CURRENT_FRAMEWORK}" = "" ]; then
        echo "CURRENT_FRAMEWORK environment variable must be defined"
        exit 1
    fi
else
    ERROR="Could not change directory to: ${REPO_BASEDIR}"
fi
#
if [ "${ACTION}" == "" ] || [ "${ACTION}" == "up" ] || [ "${ACTION}" == "run" ]; then
    if [ "${ERROR}" == "" ]; then
        echo ""
        echo "Starting MongoDb docker container..."
        echo ""
        if docker-compose -f ${SCRIPTS_DIR}/mongodb_stack_for_test.yml up -d
        then
            echo ""
            echo "MongoDb docker container started successfully."
            echo ""
            export APP_DB_NAME=mongo
            export APP_DB_URI=mongodb://root:example@127.0.0.1:27017/
            docker ps ;
        else
            ERROR="ERROR: could not start mongo docker container" ;
        fi
        #
        if [ "${ERROR}" == "" ]; then
            echo ""
            echo "Starting Lambda configuration for local MongoDb on docker..."
            echo ""
            if sh ${SCRIPTS_DIR}/../aws/set_chalice_cnf.sh mongo_docker
            then
                echo ""
                echo "Lambda configuration for local MongoDb on docker ran successfully."
                echo ""
            else
                ERROR="ERROR: running ${SCRIPTS_DIR}/../aws/set_chalice_cnf.sh"
            fi
        fi
        #
        if [ "${ERROR}" == "" ]; then
            if [ "${STAGE}" == "dev" ]; then
                if [ "${APP_DB_ENGINE_DEV}" == "DYNAMO_DB" ]; then
                    echo ""
                    echo "Creating DynamoDB tables on the Dev environment..."
                    echo ""
                    if ! sh ${SCRIPTS_DIR}/../aws_dynamodb/generate_dynamodb_cf/generate_dynamodb_cf.sh create_tables dev
                    then
                        ERROR="ERROR: running 'sh ${SCRIPTS_DIR}/../aws_dynamodb/generate_dynamodb_cf/generate_dynamodb_cf.sh create_tables dev'"
                    fi
                fi
            fi
        fi
        #
        if [ "${ERROR}" == "" ]; then
            echo ""
            echo "Please remember to perform the 'supad-create'"
            echo ""
            if [ "${RUN_LOCAL_APP}" = "1" ]; then
                echo "Starting ${APP_NAME} API over local MongoDb on docker..."
                echo ""
                if make run
                then
                    echo "${APP_NAME} API over local MongoDb on docker ran successfully."
                else
                    ERROR="ERROR: running ${REPO_BASEDIR}/make api"
                fi
            fi
        fi
    fi
fi
#
if [ "${ACTION}" == "down" ]; then
    if [ "${ERROR}" == "" ]; then
        echo "Starting MongoDb local docker container unmount..."
        echo "docker-compose -f ${SCRIPTS_DIR}/mongodb_stack_for_test.yml down"
        if docker-compose -f "${SCRIPTS_DIR}/mongodb_stack_for_test.yml" down
        then
            ERROR="MongoDb local docker container UNMOUNTED successfully."
        fi
    fi
fi
#
if [ "${ERROR}" == "" ]; then
    echo "MongoDb docker container processing done."
else
    echo ${ERROR}
fi
