#!/bin/bash
# scripts/get_domain_name_dev.sh
# 2024-05-10 | CR
#
# Mount a NGINX container to perfom an external to local bypass to server the URL mask DEV_MASK_EXT_HOSTNAME.
#
exit_abort() {
  echo "Usage:"
  echo "  source scripts/get_domain_name_dev.sh STAGE APP_DOMAIN_NAME SELF_SCRIPTS_DIR"
  echo "where..."
  echo "  STAGE: dev, qa, staging, demo, prod"
  echo "  APP_DOMAIN_NAME: domain name of the application. E.g. exampleapp.com"
  echo "  SELF_SCRIPTS_DIR: scripts directory"
  exit 1
}

stop_local_ngnx() {
  # If the nginx docker container nginx-dev-mask-ext is running, stop it
  echo "Stopping nginx docker container 'nginx-dev-mask-ext'..."
  ${DOCKER_CMD} stop nginx-dev-mask-ext

  # If the nginx docker container nginx-dev-mask-ext is running, remove it  
  echo "Removing nginx docker container 'nginx-dev-mask-ext'..."
  ${DOCKER_CMD} rm nginx-dev-mask-ext
}

enable_bridge_proxy() {
  echo "Enable bridge proxy..."

  echo "Get the IP address of the domain"
  DOMAIN_IP=$(host ${DOMAIN_NAME_ONLY} | awk '/has address/ { print $4 ; exit }')

  echo "IP address wasn't found with the 'host' command. Trying with 'ping'..."
  if [ -z "${DOMAIN_IP}" ]; then
    DOMAIN_IP=$(ping -c 1 -t 1 ${DOMAIN_NAME_ONLY} | awk '/^PING/ { print $3 }' | perl -pe 's/\(//g' | perl -pe 's/\)//g' | perl -pe 's/\://g')
  fi

  # If the IP address is still not found, exit with an error
  if [ -z "${DOMAIN_IP}" ]; then
    echo "Error: Could not resolve IP address for ${DOMAIN_NAME_ONLY}"
    exit 1
  else
    echo "Domain IP: ${DOMAIN_IP}"
  fi

  # Set default values if not provided

  # External masking hostname
  export DEV_MASK_EXT_HOSTNAME="${URL_MASK_EXTERNAL_HOSTNAME}"
  MASK_EXT_HOSTNAME_ONLY="${URL_MASK_EXTERNAL_HOSTNAME}"

  # Set External protocol
  if echo "${DEV_MASK_EXT_HOSTNAME}" | grep -q "^http://"; then
    URL_MASK_EXTERNAL_PROTOCOL="http"
    # Remove protocol http
    DEV_MASK_EXT_HOSTNAME="$(echo "${DEV_MASK_EXT_HOSTNAME}" | perl -pi -e "s/http:\/\///g")"
    MASK_EXT_HOSTNAME_ONLY="$(echo "${MASK_EXT_HOSTNAME_ONLY}" | perl -pi -e "s/http:\/\///g")"
  fi
  if echo "${DEV_MASK_EXT_HOSTNAME}" | grep -q "^https://"; then
    URL_MASK_EXTERNAL_PROTOCOL="https"
    # Remove protocol https
    DEV_MASK_EXT_HOSTNAME="$(echo "${DEV_MASK_EXT_HOSTNAME}" | perl -pi -e "s/https:\/\///g")"
    MASK_EXT_HOSTNAME_ONLY="$(echo "${MASK_EXT_HOSTNAME_ONLY}" | perl -pi -e "s/https:\/\///g")"
  fi

  # === DEFAULT VALUE === #
  # If protocol wasn't specified on the DEV_MASK_EXT_HOSTNAME, set the default value
  export URL_MASK_EXTERNAL_PROTOCOL=${URL_MASK_EXTERNAL_PROTOCOL:-"http"}
  # === DEFAULT VALUE === #
  
  # Nginx port

  # === DEFAULT VALUE === #
  if [ "${URL_MASK_EXTERNAL_PROTOCOL}" = "http" ]; then
    DEV_MASK_INT_PORT_80=${DEV_MASK_INT_PORT_80:-"8015"}
    DEV_MASK_INT_PORT_443=${DEV_MASK_INT_PORT_443:-"8016"}
  else
    DEV_MASK_INT_PORT_443=${DEV_MASK_INT_PORT_443:-"8015"}
    DEV_MASK_INT_PORT_80=${DEV_MASK_INT_PORT_80:-"8016"}
  fi
  # === DEFAULT VALUE === #

  # Try to extract the port number from URL_MASK_EXTERNAL_HOSTNAME
  echo "Extract port number from DEV_MASK_EXT_HOSTNAME: ${DEV_MASK_EXT_HOSTNAME}"
  if echo "${DEV_MASK_EXT_HOSTNAME}" | grep -q ":"; then
    DEV_MASK_EXT_PORT="$(echo "${DEV_MASK_EXT_HOSTNAME}" | awk -F':' '{print $NF}')"
    echo "Extracted DEV_MASK_EXT_PORT: ${DEV_MASK_EXT_PORT}"
    MASK_EXT_HOSTNAME_ONLY="$(echo "${DEV_MASK_EXT_HOSTNAME}" | perl -pi -e "s/\:${DEV_MASK_EXT_PORT}//g")"
  fi
  if [ "${DEV_MASK_EXT_PORT}" = "" ]; then
    echo "DEV_MASK_EXT_HOSTNAME doesn't have the port number, assign default value"
    # === DEFAULT VALUE === #
    DEV_MASK_EXT_PORT="33815"
    # === DEFAULT VALUE === #
    echo "Adding the port number ${DEV_MASK_EXT_PORT} to ${DEV_MASK_EXT_HOSTNAME}"
    export DEV_MASK_EXT_HOSTNAME="${DEV_MASK_EXT_HOSTNAME}:${DEV_MASK_EXT_PORT}"
  fi

  # Add the configureed protocol
  export DEV_MASK_EXT_HOSTNAME="${URL_MASK_EXTERNAL_PROTOCOL}://${DEV_MASK_EXT_HOSTNAME}"

  # SSL Certificates
  DEV_MASK_EXT_SSL_CERT_KEY=${DEV_MASK_EXT_SSL_CERT_KEY:-"${REPO_BASEDIR}/${MASK_EXT_HOSTNAME_ONLY}.key"}
  DEV_MASK_EXT_SSL_CERT_CRT=${DEV_MASK_EXT_SSL_CERT_CRT:-"${REPO_BASEDIR}/${MASK_EXT_HOSTNAME_ONLY}.crt"}
  DEV_MASK_EXT_SSL_CERT_CA=${DEV_MASK_EXT_SSL_CERT_CA:-"${REPO_BASEDIR}/ca.crt"}
  if [ ! -f "${DEV_MASK_EXT_SSL_CERT_KEY}" ];then
    echo ""
    echo "SSL certificate file not found: ${DEV_MASK_EXT_SSL_CERT_KEY}"
    echo "Creating it..."
    sh ${SELF_SCRIPTS_DIR}/local_ssl_certs_creation.sh "${MASK_EXT_HOSTNAME_ONLY}"
  fi

  # Report all variables
  echo ""
  echo "NGINX Configuration:"
  echo "  Domain name: ${DOMAIN_NAME_ONLY}"
  if [ "${URL_MASK_EXTERNAL_PROTOCOL}" = "http" ]; then
    echo "  DEV_MASK_EXT_PORT catch: ${DEV_MASK_EXT_PORT}:80"
  else
    echo "  DEV_MASK_EXT_PORT catch: ${DEV_MASK_EXT_PORT}:443"
  fi
  echo "  DEV_MASK_EXT_SSL_CERT_KEY volume: ${DEV_MASK_EXT_SSL_CERT_KEY}:/etc/nginx/certs/server.key:ro"
  echo "  DEV_MASK_EXT_SSL_CERT_CRT volume: ${DEV_MASK_EXT_SSL_CERT_CRT}:/etc/nginx/certs/server.crt:ro"
  echo "  DEV_MASK_EXT_SSL_CERT_CA volume: ${DEV_MASK_EXT_SSL_CERT_CA}:/etc/nginx/certs/ca.crt:ro"
  echo "  Proxy Pass:"
  echo "    FROM: ${DEV_MASK_EXT_HOSTNAME}"
  echo "    TRHU: 127.0.0.1:${DEV_MASK_INT_PORT_443}"
  echo "    TO: http://${DOMAIN_IP}:${BACKEND_LOCAL_PORT}"
  echo ""

  # If the nginx docker container nginx-dev-mask-ext is running, stop it
  stop_local_ngnx

  # Preparing the NGNX confing file
  echo "Preparing the NGNX confing file..."

  rm -rf "${TMP_BUILD_DIR}/get_domain_name_nginx.conf"
  cat > "${TMP_BUILD_DIR}/get_domain_name_nginx.conf" <<END \

# get_domain_name_nginx.conf
# 2024-05-11 | CR
worker_processes 4;
events {
    worker_connections 1024;
}
http {
    include mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    server {
        listen 80;
        server_name HOSTNAME_placeholder;
        location / {
            proxy_pass PROXY_PASS_placeholder;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
    server {
        listen 443 ssl;
        server_name HOSTNAME_placeholder;
        ssl_certificate /etc/nginx/certs/server.crt;
        ssl_certificate_key /etc/nginx/certs/server.key;
        # ssl_ca_certificate /etc/nginx/certs/ca.crt;
        # ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH;
        # ssl_prefer_server_ciphers on;
        # ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        location / {
            proxy_pass PROXY_PASS_placeholder;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
}
END
  # perl -pi -e "s/HOSTNAME_placeholder/${DOMAIN_IP}/g" ${TMP_BUILD_DIR}/get_domain_name_nginx.conf
  perl -pi -e "s/HOSTNAME_placeholder/${DOMAIN_NAME_ONLY}/g" ${TMP_BUILD_DIR}/get_domain_name_nginx.conf
  perl -pi -e "s/PROXY_PASS_placeholder/http:\/\/${DOMAIN_IP}:${BACKEND_LOCAL_PORT}/g" ${TMP_BUILD_DIR}/get_domain_name_nginx.conf

  # Start the nginx docker container
  echo "Starting nginx docker container 'nginx-dev-mask-ext'..."
  ${DOCKER_CMD} run -d \
    --name nginx-dev-mask-ext \
    -p ${DEV_MASK_INT_PORT_443}:443 \
    -p ${DEV_MASK_INT_PORT_80}:80 \
    -v ${DEV_MASK_EXT_SSL_CERT_KEY}:/etc/nginx/certs/server.key:ro \
    -v ${DEV_MASK_EXT_SSL_CERT_CRT}:/etc/nginx/certs/server.crt:ro \
    -v ${DEV_MASK_EXT_SSL_CERT_CA}:/etc/nginx/certs/ca.crt:ro \
    -v ${TMP_BUILD_DIR}/get_domain_name_nginx.conf:/etc/nginx/nginx.conf \
    nginx:latest \
    nginx -c /etc/nginx/nginx.conf \
    -g "daemon off;"

  echo ""
  echo "NGINX docker container 'nginx-dev-mask-ext' is running."
  echo "You can access the domain name ${DOMAIN_NAME_ONLY} with the following URL:"
  echo "  ${DEV_MASK_EXT_HOSTNAME}"
  echo "Check the logs with:"
  echo "  $ ${DOCKER_CMD} logs -f nginx-dev-mask-ext"
  echo ""
  echo "Configure the 'Virtual Servers / Port Forwarding' in your Internet Router"
  echo "For example:"
  echo ""
  if [ "${URL_MASK_EXTERNAL_PROTOCOL}" = "http" ]; then
    echo "Description: GS_Fwd_Srv_80"
    echo "Inbound Port: ${DEV_MASK_EXT_PORT} to ${DEV_MASK_EXT_PORT}"
    echo "Format: TCP"
    echo "Private IP Address: ${DOMAIN_IP}"
    echo "Local Port: ${DEV_MASK_INT_PORT_80} to ${DEV_MASK_INT_PORT_80}"
  else
    echo "Description: GS_Fwd_Srv_443"
    echo "Inbound Port: ${DEV_MASK_EXT_PORT} to ${DEV_MASK_EXT_PORT}"
    echo "Format: TCP"
    echo "Private IP Address: ${DOMAIN_IP}"
    echo "Local Port: ${DEV_MASK_INT_PORT_443} to ${DEV_MASK_INT_PORT_443}"
  fi
  echo ""

  # Check if the nginx docker container nginx-dev-mask-ext is running
  echo "Checking if nginx docker container 'nginx-dev-mask-ext' is running..."
  if ! ${DOCKER_CMD} ps -a | grep nginx-dev-mask-ext
  then
    echo "Error: nginx docker container 'nginx-dev-mask-ext' is not running."
    exit 1
  fi
}

enable_ngrok() {
  echo "Enable ngrok..."
  # Detect if ngrok is installed in the package.json
  NGROK_INSTALLED=$(grep -c "ngrok" package.json)
  if [ "${NGROK_INSTALLED}" -eq 0 ]; then
    echo "Installing ngrok..."
    npm install --save-dev ngrok
    echo "Starting ngrok..."
  else
    echo "ngrok is installed in package.json"
  fi
  # Login to ngrok
  if [ "${NGROK_AUTH_TOKEN}" = "" ]; then
    echo ""
    echo "Login to Ngrok. If you don't have an account, click on the 'Sign up for free!' button."
    echo "Press Enter and a new Browser window will open."
    read any_key
    echo ""
    echo "Opening https://dashboard.ngrok.com/login"
    open https://dashboard.ngrok.com/login
    echo "In the Ngrok dashboard page, go to the 'Getting started > Your Authtoken' option and copy the Auth Token."
    echo "Then paste your Ngrok Authtoken here and press Enter:"
    read new_ngrok_auth_token
    echo ""
    export NGROK_AUTH_TOKEN=${new_ngrok_auth_token}
    # Save the new Auth Token to the exsiting .env file (if it doesn't exist there yet)
    if ! grep -q "NGROK_AUTH_TOKEN" .env; then
      echo "" >> .env
      echo "# NGROK auth token" >> .env
      echo "NGROK_AUTH_TOKEN=${NGROK_AUTH_TOKEN}" >> .env
    fi
  fi
  # Check if ngrok is running, if not start it in another terminal window
  NGROK_PID=$(pgrep ngrok)
  if [ "${NGROK_PID}" = "" ]; then
    osascript -e "tell app \"Terminal\"
                  activate
                  do script \"cd ${REPO_BASEDIR} && node_modules/ngrok/bin/ngrok config add-authtoken ${NGROK_AUTH_TOKEN} && node_modules/ngrok/bin/ngrok http ${PORT}\"
              end tell"
    # Wait 5 seconds
    sleep 5
  fi
  # Get the Ngrok public URL
  if curl --output /dev/null --silent --head --fail http://localhost:4040; then
    # Get the public URL from the Ngrok API
    public_url=$(curl --silent http://localhost:4040/api/tunnels | grep -o -E "https://[^\"]*")
    # Assign and print the public URL
    echo "Public URL (DEV_MASK_EXT_HOSTNAME): $public_url"
    export DEV_MASK_EXT_HOSTNAME="$public_url"
  else
    echo "Error: ngrok is not running."
    export DEV_MASK_EXT_HOSTNAME=""
  fi
}

# Start...

TMP_BUILD_DIR="/tmp"
REPO_BASEDIR="`pwd`"

STAGE="$1"
APP_DOMAIN_NAME="$2"
SELF_SCRIPTS_DIR="$3"

if [ "${SELF_SCRIPTS_DIR}" = "" ];then
  cd "`dirname "$0"`"
  SELF_SCRIPTS_DIR="`pwd`"
  cd "${REPO_BASEDIR}"
fi

if [ -z "${DOCKER_CMD}" ];then
  if ! source ${SELF_SCRIPTS_DIR}/container_engine_manager.sh start "${CONTAINER_ENGINE}" "${OPEN_CONTAINERS_ENGINE_APP}"; then
      echo "ERROR: Running ${SELF_SCRIPTS_DIR}/container_engine_manager.sh start \"${CONTAINER_ENGINE}\" \"${OPEN_CONTAINERS_ENGINE_APP}\""
      exit_abort
  fi
fi

if [ -z "${DOCKER_CMD}" ];then
  echo "ERROR: missing DOCKER_CMD."
  exit_abort
fi

if [ "${STAGE}" = "" ];then
  echo "ERROR: missing STAGE."
  exit_abort
fi

if [ "${APP_DOMAIN_NAME}" = "" ];then
  echo "ERROR: missing APP_DOMAIN_NAME."
  exit_abort
fi

if [ "${RUN_PROTOCOL}" = "" ];then
  RUN_PROTOCOL="https"
fi

echo ""
echo ">> get_domain_name_dev.sh:"
echo ""
echo "SELF_SCRIPTS_DIR: ${SELF_SCRIPTS_DIR}"
echo "REPO_BASEDIR: ${REPO_BASEDIR}"
echo ""

# Prepare domain name
if [ "${STAGE}" == "stop_local_ngnx" ];then
  . "${SELF_SCRIPTS_DIR}/get_domain_name.sh" dev local
  STAGE="stop_local_ngnx"
fi

if [ "${STAGE}" = "dev" ];then
  # export DOMAIN_NAME="api-dev.${APP_DOMAIN_NAME}"
  . "${REPO_BASEDIR}/.env"
  export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
  if [ "${APP_LOCAL_DOMAIN_NAME}" != "" ]; then
    export DOMAIN_NAME="${APP_LOCAL_DOMAIN_NAME}"
  else
    if [ "${BACKEND_LOCAL_PORT}" = "" ]; then
        export BACKEND_LOCAL_PORT="5001"
    fi
    DOMAIN_NAME_ONLY="app.${APP_NAME_LOWERCASE}.local"
    export DOMAIN_NAME="${DOMAIN_NAME_ONLY}:${BACKEND_LOCAL_PORT}"
    if [ "${BRIDGE_PROXY_DISABLED}" = "1" ]; then
        echo "Bridge_proxy skipped..."
    else
      if [ "${NGROK_ENABLED}" == "1" ]; then
        enable_ngrok
      else
        if [ "${URL_MASK_EXTERNAL_HOSTNAME}" = "" ]; then
          echo "NGROK_ENABLED is not set. Skipping ngrok setup."
          echo "URL_MASK_EXTERNAL_HOSTNAME is not set..."
          echo "Set URL_MASK_EXTERNAL_HOSTNAME if you want features like AI Vision to work with the local domain '${DOMAIN_NAME}'"
        else
          if [[ "${URL_MASK_EXTERNAL_HOSTNAME}" != *"${APP_DOMAIN_NAME}"* ]]; then
              # If the hostname in URL_MASK_EXTERNAL_HOSTNAME does not contain the domain name, add it
              enable_bridge_proxy
          else
            # If the hostname in URL_MASK_EXTERNAL_HOSTNAME contains the domain name, assign it
            if ! echo "${URL_MASK_EXTERNAL_HOSTNAME}" | grep -q "^http?://"; then
              URL_MASK_EXTERNAL_HOSTNAME="https://${URL_MASK_EXTERNAL_HOSTNAME}"
            fi
            export DEV_MASK_EXT_HOSTNAME="${URL_MASK_EXTERNAL_HOSTNAME}"
          fi
        fi
      fi
    fi
  fi
fi

echo ""
if [ "${STAGE}" = "stop_local_ngnx" ];then
  stop_local_ngnx
  DOMAIN_NAME="NGINX Server stopped for ${DOMAIN_NAME}."
fi

if [ "${DOMAIN_NAME}" = "" ];then
  echo "ERROR: invalid STAGE (${STAGE}). Cannot set DOMAIN_NAME for dev."
  exit 1
else
  echo "DOMAIN_NAME: ${DOMAIN_NAME}"
  if [ "${STAGE}" = "dev" ];then
    echo "DEV_MASK_EXT_HOSTNAME: ${DEV_MASK_EXT_HOSTNAME}"
  fi
fi
echo ""
