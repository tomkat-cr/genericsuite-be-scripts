#!/bin/sh
# File: scripts/mongo/db_mongo_backup.sh
# 2022-03-12 | CR
# Prerequisite:
#   https://www.mongodb.com/docs/database-tools/installation/installation/
#   brew install mongodb-database-tools
#
REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

DUMP_DIR="/tmp/mongodb_backup_tmp"

echo "";
echo "MongoDB Backup";

STAGE="$1"
DUMP_FINAL_DIR="$2"

abort_with_help() {
    echo "";
    echo ${ERROR_MSG}
    echo "";
    echo "Usage: $0 STAGE DUMP_FINAL_DIR"
    echo "  STAGE: database environment (dev, qa, staging, demo, prod)"
    echo "  DUMP_FINAL_DIR: where the backup .zip file will be placed"
    echo "";
    exit 1
}

write_end_date_time() {
    echo "";
    echo ${OUTPUT_MSG}
    echo "End: `date +%Y-%m-%d` `date +%H:%M:%S`"
    echo "End: `date +%Y-%m-%d` `date +%H:%M:%S`" >> "${LOG_FILE_NAME}"
}

write_message() {
    echo "";
    echo ${OUTPUT_MSG}
    echo "" >> "${LOG_FILE_NAME}"
    echo ${OUTPUT_MSG} >> "${LOG_FILE_NAME}"
}

write_message_with_log_date() {
    write_message
    write_end_date_time
}

abort_with_log_date() {
    OUTPUT_MSG="${ERROR_MSG}"
    write_message_with_log_date
    exit 1
}

if [ "${STAGE}" = "" ]; then
    ERROR_MSG="ERROR: Stage not supplied";
    abort_with_help
fi

if [ "${DUMP_FINAL_DIR}" = "" ]; then
    ERROR_MSG="ERROR: dump target directory not supplied";
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
    ERROR_MSG="ERROR: Database name must be set (APP_DB_NAME_[stage])"
    abort_with_help
fi
if [ "${APP_DB_URI}" = "" ]; then
    ERROR_MSG="ERROR: Database connection URI must be set (APP_DB_URI_[stage])"
    abort_with_help
fi
if [ "${APP_DB_ENGINE}" != "MONGO_DB" ]; then
    ERROR_MSG="ERROR: App Engine must be 'MONGO_DB' (APP_DB_ENGINE_[stage]). Currently is '${APP_DB_ENGINE}' for ${APP_DB_NAME} in ${STAGE})"
    abort_with_help
fi

mkdir -p "${DUMP_DIR}"

mkdir -p "${DUMP_FINAL_DIR}"
cd "${DUMP_FINAL_DIR}"
DUMP_FINAL_DIR=`pwd`

DATE_TIME_PART="`date +%Y-%m-%d`_`date +%H-%M`";#
ZIP_FILE_NAME="${DUMP_FINAL_DIR}/bkp-mongodb-${APP_DB_NAME}-${DATE_TIME_PART}.zip";#
LOG_FILE_NAME="${DUMP_FINAL_DIR}/bkp-mongodb-${APP_DB_NAME}-${DATE_TIME_PART}.log";#

echo "" >> "${LOG_FILE_NAME}"
OUTPUT_MSG="Backup database: ${APP_DB_NAME}"
write_message
OUTPUT_MSG="Stage: ${STAGE}"
write_message
OUTPUT_MSG="Dump target directory: ${DUMP_FINAL_DIR}"
write_message
OUTPUT_MSG="Dump temp directory: ${DUMP_DIR}"
write_message
OUTPUT_MSG="Begin: `date +%Y-%m-%d` `date +%H:%M:%S`"
write_message
OUTPUT_MSG=""
write_message

cd "${DUMP_DIR}"

if [ "${STAGE_UPPERCASE}" = "DEV" ]; then
    OUTPUT_MSG="mongodump --authenticationDatabase=admin --uri=${APP_DB_URI} --db=${APP_DB_NAME}"
    write_message
    if ! mongodump --authenticationDatabase=admin --uri=${APP_DB_URI} --db=${APP_DB_NAME} >> "${LOG_FILE_NAME}"
    then
        ERROR_MSG="ERROR: mongodump failed for ${APP_DB_NAME}" >> "${LOG_FILE_NAME}"
        abort_with_log_date
    fi
else
    OUTPUT_MSG="mongodump --uri=******** --db=${APP_DB_NAME}"
    write_message
    if ! mongodump --uri=${APP_DB_URI} --db=${APP_DB_NAME} >> "${LOG_FILE_NAME}"
    then
        ERROR_MSG="ERROR: mongodump failed for ${APP_DB_NAME}"
        abort_with_log_date
    fi
fi

echo "";
echo "Dump temp directory: ${DUMP_DIR}"
echo "Dump directory content:"
echo "";
ls -lah ${DUMP_DIR};
ls -lah ${DUMP_DIR}/dump;
if ! ls -lah "${DUMP_DIR}/dump/${APP_DB_NAME}"
then
    ERROR_MSG="ERROR: Dump directory content is empty"
    abort_with_log_date
else
    OUTPUT_MSG="Dump temp directory: ${DUMP_DIR}/dump/${APP_DB_NAME}"
    write_message
    OUTPUT_MSG="Dump directory content:"
    write_message
    ls -lah "${DUMP_DIR}/dump/${APP_DB_NAME}" >> "${LOG_FILE_NAME}"
fi

OUTPUT_MSG="zip -r -q ${ZIP_FILE_NAME} ${DUMP_DIR}/dump/${APP_DB_NAME}"
write_message

cd "${DUMP_DIR}/dump/${APP_DB_NAME}"
if ! zip -r -q "${ZIP_FILE_NAME}" . >> "${LOG_FILE_NAME}"
then
    ERROR_MSG="ERROR: Dump directory content is empty"
    abort_with_log_date
fi

OUTPUT_MSG="Backup created:"
write_message
OUTPUT_MSG=$(ls -lah ${ZIP_FILE_NAME})
write_message
OUTPUT_MSG=$(ls -lah ${LOG_FILE_NAME})
write_message_with_log_date
echo ""