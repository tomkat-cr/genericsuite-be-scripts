#!/bin/sh
# File: scripts/mongo/db_mongo_restore.sh
# 2022-03-12 | CR
# Prerequisite:
#   https://www.mongodb.com/docs/database-tools/installation/installation/
#   brew install mongodb-database-tools
#
DUMP_DIR="/tmp/mongodb_restore_tmp"

echo "";
echo "MongoDB Restore";
echo "";

STAGE="$1"
RESTORE_FILE_PATH="$2"

abort_with_help() {
    echo "";
    echo ${ERROR_MSG}
    echo "";
    echo "Usage: $0 STAGE RESTORE_FILE_PATH"
    echo "  STAGE: database environment (dev, qa, staging, demo, prod)"
    echo "  RESTORE_FILE_PATH: the backup .zip file path to be restored (made by GenericSuite's db_mongo_backup.sh)"
    echo "";
    exit 1
}

if [ "${STAGE}" = "" ]; then
    ERROR_MSG="ERROR: Stage not supplied";
    abort_with_help
fi

if [ ! -f "${RESTORE_FILE_PATH}" ]; then
    ERROR_MSG="ERROR: Source dump .zip file path doesn't exist: ${RESTORE_FILE_PATH}";
    abort_with_help
fi

if [ ! -f ".env" ]; then
    echo "ERROR: '.env. file does not exist'";
    exit 1
fi

set -o allexport; . ".env"; set +o allexport ;

STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')
APP_DB_ENGINE=$(eval echo \$APP_DB_ENGINE_${STAGE_UPPERCASE})
APP_DB_NAME=$(eval echo \$APP_DB_NAME_${STAGE_UPPERCASE})
APP_DB_URI=$(eval echo \$APP_DB_URI_${STAGE_UPPERCASE})

if [ "${APP_DB_NAME}" = "" ]; then
    ERROR_MSG="ERROR: Target Database name must be supplied";
    abort_with_help
fi
if [ "${APP_DB_URI}" = "" ]; then
    ERROR_MSG="ERROR: APP_DB_URI must be set";
    abort_with_help
fi
if [ "${APP_DB_ENGINE}" != "MONGO_DB" ]; then
    ERROR_MSG="ERROR: App Engine must be 'MONGO_DB' (currently is '${APP_DB_ENGINE}' for ${APP_DB_NAME} in ${STAGE})";
    abort_with_help
fi
if [ "${STAGE_UPPERCASE}" = "PROD" ]; then
    echo "ERROR: Production database cannot be restored by this option";
    exit 1
fi

REPO_BASEDIR=`pwd`
DUMP_FINAL_DIR="${DUMP_DIR}/dump/${APP_DB_NAME}"
mkdir -p "${DUMP_FINAL_DIR}"
cd "${DUMP_FINAL_DIR}"
DUMP_FINAL_DIR=`pwd`
cd "${REPO_BASEDIR}"

echo "Restore database: ${APP_DB_NAME}"
echo ""
echo "From:"
echo "${RESTORE_FILE_PATH}"
ls -lah "${RESTORE_FILE_PATH}"
echo ""
echo "Stage: ${STAGE}"
echo "Dump temp directory:"
echo "${DUMP_FINAL_DIR}"
echo ""

# Unzip the ${RESTORE_FILE_PATH} into ${DUMP_FINAL_DIR}
if ! unzip -o "${RESTORE_FILE_PATH}" -d "${DUMP_FINAL_DIR}"
then
    echo "ERROR: Failed to unzip the file: ${RESTORE_FILE_PATH}"
    exit 1
fi

# mongorestore --db=$2 --uri ${APP_DB_URI} ./dump/$1 ;
if [ "${STAGE_UPPERCASE}" = "DEV" ]; then
    mongorestore --authenticationDatabase=admin --drop --db=${APP_DB_NAME} --uri=${APP_DB_URI} "${DUMP_FINAL_DIR}"
else
    mongorestore --db=${APP_DB_NAME} --drop --uri=${APP_DB_URI} "${DUMP_FINAL_DIR}"
fi

echo ""
echo "Done!"
echo ""
