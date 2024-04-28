#!/bin/bash
# scripts/secure_local_server/run.sh
# 2023-12-01 | CR
# Make sure it's executable:
# chmod +x scripts/secure_local_server/run.sh
#

docker_dependencies() {
  if ! docker ps > /dev/null 2>&1;
  then
      # To restart Docker app:
      # $ killall Docker
      echo ""
      echo "Trying to open Docker Desktop..."
      if ! open /Applications/Docker.app
      then
          echo ""
          echo "Could not run Docker Desktop automatically"
          echo ""
          exit 1
      else
          sleep 20
      fi
  fi

  if ! docker ps > /dev/null 2>&1;
  then
      echo ""
      echo "Docker is not running"
      echo ""
      exit 1
  fi

  if ! docker ps | grep dns-server -q
  then
      echo ""
      echo "0)" make local_dns
      echo ""
      make local_dns
  fi
}

ssl_certificates_verification() {
    cd "${REPO_BASEDIR}"
    echo "Verifying if SSL certificates exist..."
    echo "Current directory: $(pwd)"
    echo ""
    CREATE_SSL_CERTS="0"
    if [ ! -f app.${APP_NAME_LOWERCASE}.local.key ];then
        CREATE_SSL_CERTS="1"
    fi
    if [ ! -f app.${APP_NAME_LOWERCASE}.local.crt ];then
        CREATE_SSL_CERTS="1"
    fi
    if [ ! -f app.${APP_NAME_LOWERCASE}.local.chain.crt ];then
        CREATE_SSL_CERTS="1"
    fi
    if [ ! -f ca.crt ];then
        CREATE_SSL_CERTS="1"
    fi
    if [ "${CREATE_SSL_CERTS}" = "1" ]; then
        echo "Generating SSL certificates..."
        echo ""
        make create_ssl_certs
    fi
    cd "${SCRIPTS_DIR}"
}

generate_requirements() {
    echo "Verifying if Pipfile is newer than requirements.txt..."
    echo ""
    cd "${REPO_BASEDIR}"
    ls -la Pipfile
    ls -la requirements.txt
    echo ""
    if [[ Pipfile -nt requirements.txt ]]; then
        echo "Re-generating requirements..."
        sh ${SCRIPTS_DIR}/../aws/run_aws.sh pipfile
        echo "Re-generating requirements Finished."
        cd "${SCRIPTS_DIR}"
        echo "Stopping current Docker Containers..."
        docker-compose down
        echo "Stopping current Docker Containers finished."
    fi
    cd "${SCRIPTS_DIR}"
    echo ""
}

docker_dependencies

if [ "$#" -ne 2 ]; then
    echo "Run the local backend server over a secure connection."
    echo "Usage: $0 ACTION STAGE"
    echo "ACTION can be: run, down, monitor, logs"
    echo "STAGE can be: dev, qa, staging, prod"
    exit 1
fi

export REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
export SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

export TMP_WORKING_DIR="/tmp"

# Load environment variables from .env
# set -o allexport ; source .env ; set +o allexport
. ${SCRIPTS_DIR}/../set_app_dir_and_main_file.sh

if [ "${CURRENT_FRAMEWORK}" = "" ]; then
    echo "CURRENT_FRAMEWORK environment variable must be defined"
    exit 1
fi

if [ "${APP_NAME}" = "" ]; then
    echo "APP_NAME environment variable must be defined"
    exit 1
fi

export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
export STAGE="$2"
ACTION="$1"

cd "${SCRIPTS_DIR}"

echo ""
echo "Local Backend Server over a secure connection"
echo "Action: ${ACTION}"
echo "Stage (STAGE): ${STAGE}"
echo ""
echo "App name (APP_NAME): ${APP_NAME} (${APP_NAME_LOWERCASE})"
echo "Current framework (CURRENT_FRAMEWORK): ${CURRENT_FRAMEWORK}"
echo "Python entry point (APP_DIR.APP_MAIN_FILE): ${APP_DIR}.${APP_MAIN_FILE}"
echo ""
echo "Scripts directory (SCRIPTS_DIR): ${SCRIPTS_DIR}"
echo "Repository base directory (REPO_BASEDIR): ${REPO_BASEDIR}"
echo ""

prepare_nginx_conf() {
    echo "Preparing Nginx configuration..."
    echo ""
    cd "${SCRIPTS_DIR}"
    cp ${SCRIPTS_DIR}/nginx.conf.template ${TMP_WORKING_DIR}/nginx.conf.tmp
    perl -i -pe "s|APP_NAME_LOWERCASE_placeholder|${APP_NAME_LOWERCASE}|g" "${TMP_WORKING_DIR}/nginx.conf.tmp"
}

if [ "${ACTION}" = "" ] || [ "${ACTION}" = "run" ]; then
    ssl_certificates_verification
    prepare_nginx_conf
    echo "Running the local backend server over a secure connection."
    echo ""
    generate_requirements
    docker-compose up -d
    docker ps
    docker logs sls-backend -f
fi

if [ "${ACTION}" = "down" ];then
    echo "Stopping the local backend server over a secure connection."
    echo ""
    docker-compose down
fi

if [ "${ACTION}" = "logs" ];then
    echo "Showing the logs of the local backend server over a secure connection."
    echo ""
    docker logs secure_local_server-nginx-1
    docker logs sls-backend
fi

if [ "${ACTION}" = "monitor" ];then
    echo "Monitoring the logs of local backend server over a secure connection."
    echo ""
    docker ps
    docker logs sls-backend -f
fi

echo ""
