#!/bin/sh
# File: scripts/mongo/db_mongo_restore.sh
# 2022-03-12 | CR
# Prerequisite: yum/apt/brew install mongodb-database-tools
#

# cd "`dirname "$0"`" ;
# SCRIPTS_DIR="`pwd`" ;
# cd ../.. # set repo root as current dir
REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

if [ -f ".env" ]; then
    set -o allexport; . ".env"; set +o allexport ;
fi
DO_RESTORE=1
if [ "$1" = "" ]; then
    echo "";
    echo "ERROR: Source database name must be supplied";
    DO_RESTORE=0
else 
    if [ ! -d "`pwd`/dump/$1/" ]; then
        echo "";
        echo "ERROR: Source database dump dir \"`pwd`/dump/$1\" doesn't exist";
        DO_RESTORE=0
        pwd
    fi
fi
if [ "$2" = "" ]; then
    echo "";
    echo "ERROR: Target database name must be supplied";
    DO_RESTORE=0
fi
if [ "${APP_DB_URI}" = "" ]; then
    echo "";
    echo "ERROR: APP_DB_URI must be set";
    echo "";
    DO_RESTORE=0
fi
if [ ${DO_RESTORE} -eq 1 ]; then
    echo "";
    echo "Restore database: $1 | into: $2";
    echo "";
    echo "Dump/$1 directory content:";
    echo "";
    ls -lah ./dump/$1
    echo "";
    mongorestore --db=$2 --uri ${APP_DB_URI} ./dump/$1 ;
    echo "";
fi
