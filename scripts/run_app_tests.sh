#!/bin/sh
#
# sh scripts/run_app_tests.sh
# 2022-02-17 | CR
# Run test script, with mount and unmount the local docker mongodb container
#
ERROR_MSG=""

# Detault app port for the test (can be changed in ".env")
TEST_APP_URL="http://localhost:5001"

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`" ;
SCRIPTS_DIR="`pwd`" ;
cd "${REPO_BASEDIR}"

if [ -f "${REPO_BASEDIR}/.env" ]; then
    set -o allexport; . "${REPO_BASEDIR}/.env"; set +o allexport ;
fi

export HTTP_SERVER_URL="${TEST_APP_URL}"
MONGO_DOCKER_CONTAINER_NAME="mongo-db"
CHALICE_ON=1
PERFORM_TEST=1

if [ "$ERROR_MSG" = "" ]; then
    if ! docker ps > /dev/null 2>&1;
    then
        ERROR_MSG="Docker is not running"
    fi
fi

if [ "${ERROR_MSG}" = "" ]; then
    echo ".env file backup..."
    if ! BKP_FILE=$("${SCRIPTS_DIR}/back_file_w_date.sh" ${REPO_BASEDIR}/.env); then
        ERROR_MSG="Doing the ${REPO_BASEDIR}/.env file backup: ${BKP_FILE}"
    else
        echo "Backup file: ${BKP_FILE}"
    fi
fi

if [ "$ERROR_MSG" = "" ]; then
    echo "Verifying the MongoDb docker container running..."
    if docker ps | grep ${MONGO_DOCKER_CONTAINER_NAME} -q
    then
        echo "Active MongoDb docker container found..."
        MONGO_DOCKER_ACTIVE=1
    else
        echo "Active MongoDb docker container NOT found..."
        MONGO_DOCKER_ACTIVE=0
    fi
    if [ "${MONGO_DOCKER_ACTIVE}" = "0" ]; then
        if ! sh ${SCRIPTS_DIR}/mongo/run_mongo_docker.sh up '1'
        then
            ERROR_MSG="Running ${SCRIPTS_DIR}/mongo/run_mongo_docker.sh up '1'"
        fi
        docker ps ;
    fi
fi

if [ "$ERROR_MSG" = "" ]; then
    if [ ${CHALICE_ON} -eq 1 ]; then
        echo "Preparing test .env file..."
        APP_SECRET_KEY="${APP_SECRET_KEY}"
        APP_SUPERADMIN_EMAIL=${APP_SUPERADMIN_EMAIL/@/\\@}
        # mv .env .env.bak
        cp ./tests/.env.for_test .env
        perl -i -pe"s/\+APP_SECRET_KEY\+/${APP_SECRET_KEY}/g" ".env" ;
        perl -i -pe"s/\+APP_SUPERADMIN_EMAIL\+/${APP_SUPERADMIN_EMAIL}/g" ".env" ;
        echo "Finished preparing test .env file..."
    else
        export APP_DB_URI=mongodb://root:example@127.0.0.1 ;
    fi
fi

if [ "$ERROR_MSG" = "" ]; then
    echo ""
    echo "Reloading .env'..."
    set -o allexport; . "${REPO_BASEDIR}/.env"; set +o allexport ;
    export GS_LOCAL_ENVIR="true"
    if [ ${CHALICE_ON} -eq 1 ]; then
        echo ""
        echo "Running tests with pipenv..."
        echo ""
        echo "Web to be server used:"
        echo "HTTP_SERVER_URL: ${HTTP_SERVER_URL}"
        echo "Database to be used:"
        echo "APP_DB_NAME: ${APP_DB_NAME}"
        echo "APP_DB_URI: ${APP_DB_URI}"
        echo ""
        echo "Press ENTER to begin the test..."
        read any_key
        pipenv install --dev
        if [ "$1" = "" ]; then
            pipenv run pytest tests --junitxml=report.xml
        else
            pipenv run pytest tests/$1
        fi
    else
        echo ""
        echo "Running tests with python -m pytest..."
        echo ""
        python3 -m venv venv ;
        source venv/bin/activate ;
        pip3 install -r requirements.txt ;
        pip install pytest coverage ;
        python -m pytest ;
        deactivate ;
    fi
    echo ""
    echo "Tests run finished..."
    echo ""
fi

if [ "$ERROR_MSG" = "" ]; then
    if [ "${MONGO_DOCKER_ACTIVE}" = "0" ]; then
        sh ${SCRIPTS_DIR}/mongo/run_mongo_docker.sh down ;
    fi
fi

if [ "${ERROR_MSG}" = "" ]; then
    echo "Restoring .env file from ${BKP_FILE}..."
    if ! cp ${BKP_FILE} ${REPO_BASEDIR}/.env;
    then
        ERROR_MSG="Restoring the ${REPO_BASEDIR}/.env file backup: ${BKP_FILE}"
    else
        echo "${REPO_BASEDIR}/.env file restored..."
        rm ${BKP_FILE}
    fi
else
    echo "WARNING: Restore of .env file from ${BKP_FILE} wasn't done. Please restore manually!"
fi

echo ""
if [ "${ERROR_MSG}" = "" ]; then
    echo "Done!"
else
    echo "ERROR: ${ERROR_MSG}"
fi
echo ""
