#!/bin/sh
if [ "${BASE_DIR}" = "" ]; then
    export BASE_DIR="." ;
fi
if [ ! -d "${BASE_DIR}/logs" ]; then
    mkdir -p "${BASE_DIR}/logs" ;
fi
echo "" > "${BASE_DIR}/logs/app_general.log"
