#!/bin/sh
# run_tests.sh
# 2023-05-31 | CR
# Plain run test script, assuming the local docker mongodb container is already running
#
REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

PEM_TOOL="uv"

if [ -f ".env" ]; then
    set -o allexport; . ".env"; set +o allexport ;
fi

APP_SECRET_KEY="${APP_SECRET_KEY}"
APP_SUPERADMIN_EMAIL=${APP_SUPERADMIN_EMAIL/@/\\@}
mv .env .env.bak
cp ./tests/.env.for_test .env
perl -i -pe"s/\+APP_SECRET_KEY\+/${APP_SECRET_KEY}/g" ".env" ;
perl -i -pe"s/\+APP_SUPERADMIN_EMAIL\+/${APP_SUPERADMIN_EMAIL}/g" ".env" ;

bash ${SCRIPTS_DIR}/../run_pem.sh install_dev
if [ "$1" = "" ]; then
    ${PEM_TOOL} run pytest tests --junitxml=report.xml
else
    ${PEM_TOOL} run pytest $1 --junitxml=report.xml
fi

cp .env.bak .env
