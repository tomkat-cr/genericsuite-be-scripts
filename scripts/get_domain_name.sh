#!/bin/bash
# scripts/get_domain_name.sh
# 2024-05-09 | CR

# Get domain name according to the given stage
# Usage:
# . scripts/get_domain_name.sh "${STAGE}" [local]

. "$(pwd)/.env"

STAGE="$1"
LOCAL_HOSTNAME_ASSIGNMENT="$2"

export DOMAIN_NAME=""

if [ "${STAGE}" = "prod" ];then
  export DOMAIN_NAME="api.${APP_DOMAIN_NAME}"
fi

if [ "${STAGE}" = "qa" ];then
  export DOMAIN_NAME="api-qa.${APP_DOMAIN_NAME}"
fi

if [ "${STAGE}" = "staging" ];then
  export DOMAIN_NAME="api-staging.${APP_DOMAIN_NAME}"
fi

if [ "${STAGE}" = "demo" ];then
  export DOMAIN_NAME="api-demo.${APP_DOMAIN_NAME}"
fi

if [ "${STAGE}" = "dev" ];then
  if [ "${LOCAL_HOSTNAME_ASSIGNMENT}" = "" ];then
    export DOMAIN_NAME="api-dev.${APP_DOMAIN_NAME}"
  else
    if [ "${APP_LOCAL_DOMAIN_NAME}" != "" ]; then
      export DOMAIN_NAME="${APP_LOCAL_DOMAIN_NAME}"
    else
      APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
      if [ "${APP_LOCAL_PORT}" = "" ]; then
          export APP_LOCAL_PORT="5001"
      fi
      DOMAIN_NAME_ONLY="app.${APP_NAME_LOWERCASE}.local"
      export DOMAIN_NAME="${DOMAIN_NAME_ONLY}:${APP_LOCAL_PORT}"
    fi
  fi
fi

if [ "${DOMAIN_NAME}" = "" ];then
  echo "ERROR: invalid STAGE (${STAGE}). Cannot set DOMAIN_NAME."
  exit 1
else
  echo "DOMAIN_NAME: ${DOMAIN_NAME}"
fi
echo ""
