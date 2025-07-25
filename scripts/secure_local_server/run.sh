#!/bin/bash
# scripts/secure_local_server/run.sh
# 2023-12-01 | CR
# Run the secure HTTPS local server with self-signed SSL certificates, NginX and Docker.
# Make sure it's executable:
# chmod +x scripts/secure_local_server/run.sh
#

docker_dependencies() {
    echo ""
    echo "Checking container engine '${CONTAINERS_ENGINE}'..."
    if ! source "${SCRIPTS_DIR}/../container_engine_manager.sh" start "${CONTAINERS_ENGINE}" "${OPEN_CONTAINERS_ENGINE_APP}"
    then
        echo "" 
        echo "Could not run container engine '${CONTAINERS_ENGINE}' automatically"
        echo ""
        exit 1
    fi

    if [ -z "${DOCKER_CMD}" ]; then
        echo ""
        echo "DOCKER_CMD is not set"
        echo ""
        exit 1
    fi

    if ! ${DOCKER_CMD} ps | grep dns-server -q
    then
        echo ""
        echo "0) make local_dns"
        echo ""
        make local_dns
    fi
}

ssl_certificates_verification() {
    cd "${REPO_BASEDIR}"
    echo ""
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
    echo ""
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
        ${DOCKER_COMPOSE_CMD} down
        echo "Stopping current Docker Containers finished."
    fi
    cd "${SCRIPTS_DIR}"
    echo ""
}

prepare_nginx_conf() {
    echo ""
    echo "Preparing Nginx configuration..."
    echo ""
    mkdir -p "${TMP_WORKING_DIR}"
    rm -rf "${TMP_WORKING_DIR}/nginx.conf.tmp"
    # if ! cp "${SCRIPTS_DIR}/nginx.conf.template" "${TMP_WORKING_DIR}/nginx.conf.tmp" ; then
    if ! mkdir -p "${TMP_WORKING_DIR}/conf.d/" ; then
        echo "Could not create conf.d directory"
        exit 1
    fi
    if ! cp "${SCRIPTS_DIR}/conf.d"/* "${TMP_WORKING_DIR}/conf.d"/ ; then
        echo "Could not copy conf.d directory to: ${TMP_WORKING_DIR}/conf.d/"
        exit 1
    fi
    if ! perl -i -pe "s|APP_NAME_LOWERCASE_placeholder|${APP_NAME_LOWERCASE}|g" "${TMP_WORKING_DIR}/conf.d/gs_app.conf"
    then
        echo "Could not replace APP_NAME_LOWERCASE_placeholder"
        exit 1
    fi
    echo ""
    echo "Nginx.conf file path: ${TMP_WORKING_DIR}/conf.d/gs_app.conf"
    if ! ls -lah "${TMP_WORKING_DIR}/conf.d/gs_app.conf" ; then
        echo "Could not prepare Nginx.conf file"
    fi
}

prepare_docker_conf() {
    echo ""
    echo "Preparing Docker configuration..."
    echo ""
    rm -rf "${TMP_WORKING_DIR}/Dockerfile"
    rm -rf "${TMP_WORKING_DIR}/docker-compose.yml"
    if ! cp ${SCRIPTS_DIR}/Dockerfile "${TMP_WORKING_DIR}/Dockerfile"; then
        echo "Could not copy Dockerfile"
        exit 1
    fi
    if ! cp ${SCRIPTS_DIR}/docker-compose.yml "${TMP_WORKING_DIR}/docker-compose.yml"; then
        echo "Could not copy docker-compose.yml"
        exit 1
    fi
    local gs_be_ai_local="0"
    if grep -q "-e ..\/genericsuite-be-ai" "${REPO_BASEDIR}/requirements.txt"; then
        gs_be_ai_local="1"
    elif grep -q "..\/genericsuite-be-ai" "${REPO_BASEDIR}/requirements.txt"; then
        gs_be_ai_local="1"
    fi
    if [ "${gs_be_ai_local}" = "1" ]; then
        echo "Local Genericsuite-be-ai requirements found... replacing: # - \${REPO_BASEDIR}/../genericsuite-be-ai:/genericsuite-be-ai..."
        echo ""
        export LOCAL_GE_BE_AI_REPO="/genericsuite-be-ai"
        # https://wiki.ultraedit.com/Perl_regular_expressions
        perl -i -pe "s|# - \\$\{REPO_BASEDIR}\/\.\.\/genericsuite-be-ai\:\/genericsuite-be-ai$|- \\$\{REPO_BASEDIR}\/\.\.\/genericsuite-be-ai\:${LOCAL_GE_BE_AI_REPO}|g" "${TMP_WORKING_DIR}/docker-compose.yml"
    fi
    local gs_be_core_local="0"
    if grep -q "-e ..\/genericsuite-be" "${REPO_BASEDIR}/requirements.txt"; then
        gs_be_core_local="1"
    elif grep -q "..\/genericsuite-be" "${REPO_BASEDIR}/requirements.txt"; then
        gs_be_core_local="1"
    fi
    if [ "${gs_be_core_local}" = "1" ]; then
        echo "Local Genericsuite-be requirements found... replacing: # - \${REPO_BASEDIR}/../genericsuite-be:/genericsuite-be..."
        echo ""
        export LOCAL_GE_BE_REPO="/genericsuite-be"
        perl -i -pe "s|# - \\$\{REPO_BASEDIR}\/\.\.\/genericsuite-be\:\/genericsuite-be$|- \\$\{REPO_BASEDIR}\/\.\.\/genericsuite-be\:${LOCAL_GE_BE_REPO}|g" "${TMP_WORKING_DIR}/docker-compose.yml"
    fi
    echo "Requirements file path: ${REPO_BASEDIR}/requirements.txt"
    ls -lah "${REPO_BASEDIR}/requirements.txt"
    echo ""
    echo "Dockerfile path: ${TMP_WORKING_DIR}/Dockerfile"
    ls -lah "${TMP_WORKING_DIR}/Dockerfile"
    echo ""
    echo "Docker Compose file path: ${TMP_WORKING_DIR}/docker-compose.yml"
    ls -lah ${TMP_WORKING_DIR}/docker-compose.yml
}

prepare_environment() {
    # Verify if SSL certificates exist... if not, generate it
    ssl_certificates_verification
    # Prepare Nginx configuration in tmp dir
    prepare_nginx_conf
    # Generate requirements.txt if it's outdated
    generate_requirements
    # Prepare Docker configuration in tmp dir
    prepare_docker_conf
}

stop_sls_docker_containers() {
    cd "${TMP_WORKING_DIR}"
    ${DOCKER_COMPOSE_CMD} down
    ${DOCKER_CMD} stop sls-backend
    ${DOCKER_CMD} rm sls-backend
    ${DOCKER_CMD} stop sls-nginx
    ${DOCKER_CMD} rm sls-nginx
}

start_sls_docker_containers() {
    # Prepare environment
    prepare_environment
    # Run the App in the docker container from the tmp dir.
    cd "${TMP_WORKING_DIR}"
    echo ""
    echo "Running the local backend server over a secure connection..."
    echo "BACKEND_LOCAL_PORT: ${BACKEND_LOCAL_PORT}"
    echo "BACKEND_DEBUG_LOCAL_PORT: ${BACKEND_DEBUG_LOCAL_PORT}"
    echo ""
    if ! ${DOCKER_COMPOSE_CMD} up -d ; then
        echo ""
        echo "ERROR: Could not run the local backend server over a secure connection [1]."
        echo ""
        exit 1
    fi
    ${DOCKER_CMD} ps
    # Leave the logs view while the container is running
    ${DOCKER_COMPOSE_CMD} logs -f
}

restart_sls_docker_containers() {
    # Restart the App in the docker container from the tmp dir.
    cd "${TMP_WORKING_DIR}"
    if ! ${DOCKER_COMPOSE_CMD} restart; then
        echo ""
        echo "ERROR: Could not restart the local backend server over a secure connection [1]."
        echo ""
        exit 1
    fi
    ${DOCKER_CMD} ps
    # Leave the logs view while the container is running
    ${DOCKER_COMPOSE_CMD} logs -f
}

# ..................
# Start process
# ..................

export REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
export SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

docker_dependencies

if [ "$#" -ne 2 ]; then
    echo ""
    echo "Run the local backend server over a secure connection."
    echo "Usage: $0 ACTION STAGE"
    echo "ACTION can be: run, down, monitor, logs"
    echo "STAGE can be: dev, qa, staging, prod"
    exit 1
fi

export TMP_WORKING_DIR="/tmp/sls"

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

if [ "$BACKEND_LOCAL_PORT" = "" ]; then
    export BACKEND_LOCAL_PORT="5001"
fi

if [ "$BACKEND_DEBUG_LOCAL_PORT" = "" ]; then
    export BACKEND_DEBUG_LOCAL_PORT="5002"
fi

export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
export STAGE="$2"
ACTION="$1"

export LOCAL_GE_BE_AI_REPO=""
export LOCAL_GE_BE_REPO=""

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
echo "Ports:"
echo "Backend local port (BACKEND_LOCAL_PORT): ${BACKEND_LOCAL_PORT}"
echo "Backend debug local port (BACKEND_DEBUG_LOCAL_PORT): ${BACKEND_DEBUG_LOCAL_PORT}"
echo ""
echo "Docker command (DOCKER_CMD): ${DOCKER_CMD}"
echo ""

if [ "${ACTION}" = "" ] || [ "${ACTION}" = "run" ]; then
    if ! ${DOCKER_CMD} ps | grep sls-backend
    then
        echo ""
        echo "Running the local backend server over a secure connection."
        echo ""
        # Start SLS docker containers
        start_sls_docker_containers
    else
        # Attach to the container to see server activity
        echo ""
        echo "The local backend server is already running."
        echo "Do you want to 0) Restart, 1) Rebuild, 2) Attach or 3) View Logs (default) ? (0/1/2/3)"
        read ANSWER
        if [ "${ANSWER}" = "0" ]; then
            # >> Restart:
            restart_sls_docker_containers
        elif [ "${ANSWER}" = "1" ]; then
            # >> Rebuild:
            cd "${TMP_WORKING_DIR}"
            # Stop SLS docker containers
            stop_sls_docker_containers
            # Start SLS docker containers
            start_sls_docker_containers
        elif [ "${ANSWER}" = "2" ]; then
            # >> Attach:
            # key sequence to detach from docker-compose up
            # https://github.com/docker/compose/issues/4560
            # CTRL-Z, then disown %1 to release the job
            echo ""
            echo "Attaching to the container to see server activity."
            echo "To detach from the container, press Ctrl+Z and run:"
            echo "disown %1"
            echo ""
            ${DOCKER_CMD} attach sls-backend
        else
            # >> View Logs:
            echo ""
            echo "Viewing the logs of the local backend server over a secure connection."
            echo "To stop logs view, press Ctrl+C."
            echo ""
            ${DOCKER_COMPOSE_CMD} logs -f
        fi
    fi
fi

if [ "${ACTION}" = "down" ];then
    echo "Stopping the local backend server over a secure connection."
    echo ""
    # Stop SLS docker containers
    stop_sls_docker_containers
fi

if [ "${ACTION}" = "logs" ];then
    echo "Showing the logs of the local backend server over a secure connection."
    echo ""
    ${DOCKER_CMD} logs secure_local_server-nginx-1
    ${DOCKER_CMD} logs sls-backend
fi

if [ "${ACTION}" = "logs_nginx" ];then
    echo "Showing the logs of the local backend server over a secure connection."
    echo ""
    ${DOCKER_CMD} logs secure_local_server-nginx-1
    ${DOCKER_CMD} logs sls-nginx
fi

if [ "${ACTION}" = "monitor" ];then
    echo "Monitoring the logs of local backend server over a secure connection."
    echo ""
    ${DOCKER_CMD} ps
    ${DOCKER_CMD} logs sls-backend -f
fi

if [ "${ACTION}" = "monitor_nginx" ];then
    echo "Monitoring the logs of local backend server over a secure connection."
    echo ""
    ${DOCKER_CMD} ps
    ${DOCKER_CMD} logs sls-nginx -f
fi

echo ""
