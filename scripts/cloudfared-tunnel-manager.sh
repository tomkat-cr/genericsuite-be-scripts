#!/bin/bash
# cloudfared-tunnel-manager.sh
# Cloudflare Tunnel Manager
# 2026-01-31 | CR

# Official Cloudflare Documentation:
# https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/create-local-tunnel/

# To implement Cloudflare Tunnel, set the following variables in the ".env" files (backend and frontend, or monorepo):

# 1. RUN_PROTOCOL="https" (to turn on https mode)

# 2. USE_CONTAINERS_ENGINE_APP=0 (to turn off Docker/Podman completely, so it doesn't start the SLS-secure local server when RUN_PROTOCOL="https")

# 3. RUN_PROTOCOL_AND_PORT_REPLACEMENT=0 (to turn off automatic protocol and port replacement for local development environment variables APP_CORS_ORIGIN (assigned from APP_CORS_ORIGIN_{STAGE}), APP_FE_URL (assigned from APP_FE_URL_{STAGE}), and APP_API_URL (assigned from APP_API_URL_{STAGE}) depending on RUN_PROTOCOL value)

# 4. Set the following envvars:
#   APP_NAME: The name of the app
#   FRONTEND_LOCAL_PORT: The port of the frontend
#   BACKEND_LOCAL_PORT: The port of the backend
#   CF_HOSTING_DOMAIN: The domain of the Cloudflare account
#   CF_CONFIG_FILE (optional): The path to the config file. Default: ${HOME}/.cloudflared/config-${CF_FRONTEND_SUBDOMAIN}.yml

# The subdomains will be:
#   ${APP_NAME in lowercase}-dev
#   ${APP_NAME in lowercase}-dev-api
#
# Example:
# For APP_NAME="exampleapp" and CF_HOSTING_DOMAIN="exampledomain.com":
# - The frontend hostname will be: https://exampleapp-dev.exampledomain.com
# - The backend API hostname will be: https://exampleapp-dev-api.exampledomain.com
#
# Then the backend and frontend (or monorepo) ".env" files should have the following variables and values:
#
# * Backend:
#   APP_CORS_ORIGIN_QA_LOCAL=https://exampleapp-dev.exampledomain.com
#
# * Frontend:
#   APP_API_URL_DEV=https://exampleapp-dev-api.exampledomain.com
#   APP_FE_URL_DEV=https://exampleapp-dev.exampledomain.com

check_cloudflare_cli() {
  echo ""
  echo "1. Checking CloudFared Tunnel CLI"
  if ! command -v cloudflared &> /dev/null
  then
    echo "1.1. Installing CloudFared Tunnel CLI"
    if ! brew install cloudflared
    then
      echo "ERROR: could not install the cloudflared CLI with brew"
      echo "Please install it manually. For more information, visit:"
      echo "https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/create-local-tunnel"
      exit 1
    fi
  fi
}

cloudflare_login() {
  echo ""
  echo "2. Authenticating cloudflared"
  if ! cloudflared tunnel login
  then
    echo "ERROR: could not authenticate cloudflared"
    echo "If you want to cancel, press Ctrl+C now..."
    read
  fi
}

tunnel_list() {
  echo ""
  echo "3.1. Get the tunnel list"
  if ! cloudflared tunnel list
  then
    echo "ERROR: could not run 'cloudflared tunnel list'"
    exit 1
  fi
}

create_tunnel() {
  echo ""
  echo "3. Creating a tunnel and give it a name"
  if ! cloudflared tunnel create ${CF_FRONTEND_SUBDOMAIN}
  then
    echo "ERROR: could not create the tunnel: '${CF_FRONTEND_SUBDOMAIN}'"
    exit 1
  fi

  tunnel_list

  echo ""
  echo "3.2. Getting the tunnel ID"
  TUNNEL_ID=$(cloudflared tunnel list | awk 'NR==3{print $1}')
  if [ ! $? -eq 0 ]; then
    echo "ERROR: could not get the tunnel ID"
    exit 1
  fi

  if [ -z "${TUNNEL_ID}" ]; then
    echo "ERROR: could not get the tunnel ID"
    exit 1
  else
    echo "Tunnel ID: ${TUNNEL_ID}"
  fi

  echo ""
  echo "3.3. Getting the tunnel name"
  TUNNEL_NAME=$(cloudflared tunnel list | awk 'NR==3{print $2}')
  if [ ! $? -eq 0 ]; then
    echo "ERROR: could not get the tunnel name"
    exit 1
  fi

  echo ""
  echo "3.4. Confirm that the tunnel has been successfully created"
  if [ "${TUNNEL_NAME}" != "${CF_FRONTEND_SUBDOMAIN}" ]; then
    echo "ERROR: the tunnel name does not match the expected name"
    exit 1
  fi

  # 4. Create a configuration file
  cat > "${CF_CONFIG_FILE}" <<END \

tunnel: ${TUNNEL_ID}
credentials-file: ${HOME}/.cloudflared/${TUNNEL_ID}.json

ingress:
  - hostname: ${CF_FRONTEND_SUBDOMAIN}.${CF_HOSTING_DOMAIN}
    service: http://localhost:${FRONTEND_LOCAL_PORT}
  - hostname: ${CF_BACKEND_SUBDOMAIN}.${CF_HOSTING_DOMAIN}
    service: http://localhost:${BACKEND_LOCAL_PORT}
  - service: http_status:404
END

  # 5. Start routing traffic
  cloudflared tunnel route dns -f ${CF_FRONTEND_SUBDOMAIN} ${CF_FRONTEND_SUBDOMAIN}.${CF_HOSTING_DOMAIN}
  cloudflared tunnel route dns -f ${CF_BACKEND_SUBDOMAIN} ${CF_BACKEND_SUBDOMAIN}.${CF_HOSTING_DOMAIN}
}

run_tunnel() {
  # 6. Run the tunnel to proxy incoming traffic from the tunnel to any number of services running locally on your origin.
  cloudflared tunnel --config "${CF_CONFIG_FILE}" run
}

check_tunnel() {
  # 7. Check the tunnel
  cloudflared tunnel info ${CF_FRONTEND_SUBDOMAIN}
}

delete_tunnel() {
  cloudflared tunnel delete ${CF_FRONTEND_SUBDOMAIN}
}

check_requirements() {
  local missin_vars=""
  if [ -z "${FRONTEND_LOCAL_PORT}" ]; then
    missin_vars="${missin_vars} FRONTEND_LOCAL_PORT"
  fi
  if [ -z "${BACKEND_LOCAL_PORT}" ]; then
    missin_vars="${missin_vars} BACKEND_LOCAL_PORT"
  fi
  if [ -z "${CF_HOSTING_DOMAIN}" ]; then
    missin_vars="${missin_vars} CF_HOSTING_DOMAIN"
  fi
  if [ -z "${APP_NAME}" ]; then
    missin_vars="${missin_vars} APP_NAME"
  fi
  if [ ! -z "${missin_vars}" ]; then
    echo ""
    echo "ERROR: missing required variables:${missin_vars}"
    echo ""
    exit 1
  fi

  if [ -z "${ACTION}" ]; then
    ACTION="$1"
  fi
  if [ -z "${ACTION}" ]; then
    echo "ERROR: missing required variable (ACTION)"
    exit 1
  fi

  APP_NAME_LOWERCASE=$(echo "${APP_NAME}" | tr '[:upper:]' '[:lower:]')
  CF_FRONTEND_SUBDOMAIN="${APP_NAME_LOWERCASE}-dev"
  CF_BACKEND_SUBDOMAIN="${CF_FRONTEND_SUBDOMAIN}-api"

  if [ -z "${CF_CONFIG_FILE}" ]; then
    CF_CONFIG_FILE="${HOME}/.cloudflared/config-${CF_FRONTEND_SUBDOMAIN}.yml"
  fi
}

report_urls() {
  echo ""
  echo "Cloudflare Tunnel URLs:"
  echo "Frontend URL: https://${CF_FRONTEND_SUBDOMAIN}.${CF_HOSTING_DOMAIN}"
  echo "Backend URL: https://${CF_BACKEND_SUBDOMAIN}.${CF_HOSTING_DOMAIN}"
  echo ""
}

set -o allexport; source .env; set +o allexport ;

check_requirements

if [ "${ACTION}" = "create" ]; then
  check_cloudflare_cli
  cloudflare_login
  create_tunnel
elif [ "${ACTION}" = "run" ]; then
  report_urls
  run_tunnel
elif [ "${ACTION}" = "list" ]; then
  tunnel_list
elif [ "${ACTION}" = "check" ]; then
  check_tunnel
elif [ "${ACTION}" = "delete" ]; then
  delete_tunnel
elif [ "${ACTION}" = "login" ]; then
  cloudflare_login
else
  echo "ERROR: unknown action '${ACTION}'.\nIt must be one of: create, run, list, check, delete"
  exit 1
fi
