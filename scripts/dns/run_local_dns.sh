#!/bin/bash
# run_local_dns.sh
# 2023-11-27 | CR

docker_dependencies() {
    if ! source "${SCRIPTS_DIR}/../container_engine_manager.sh" start "${CONTAINERS_ENGINE}" "${OPEN_CONTAINERS_ENGINE_APP}"
    then
        echo ""
        echo "Could not run container engine '${CONTAINERS_ENGINE}' automatically"
        echo ""
        exit 1
    fi

    if [ "${DOCKER_CMD}" = "" ]; then
        echo ""
        echo "DOCKER_CMD is not set"
        echo ""
        exit 1
    fi
}

prepare_podman() {
    if [ "${CONTAINERS_ENGINE}" = "podman" ]; then
        echo ">> Running: podman machine ssh \"sudo sysctl -w net.ipv4.ip_unprivileged_port_start=53\""
        podman machine ssh "sudo sysctl -w net.ipv4.ip_unprivileged_port_start=53"
    fi
}

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
CURRENT_SCRIPT_DIR="`pwd`"
cd "${REPO_BASEDIR}"

echo "Local DNS server starting..."

# Assumes it's run from the project root directory...
set -o allexport; . .env ; set +o allexport ;

docker_dependencies
prepare_podman

if [ "${APP_NAME}" = "" ]; then
    echo "APP_NAME environment variable must be defined"
    exit 1
fi

if [ "${LOCAL_DNS_DISABLED}" = "1" ]; then
    echo "DNS local server skipped..."
    exit 0
fi

export TMP_WORKING_DIR="/tmp"

export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

# These settings can be overwritten by the ".env" file
# export SCRIPTS_DIR="./scripts"
export SCRIPTS_DIR="${CURRENT_SCRIPT_DIR}/.."
export DNS_SERVER_PASSW="dns_password"
export DNS_DOMAIN_NAME="app.${APP_NAME_LOWERCASE}.local"
ACTION="$1"

# Get the local IP
IP_ADDRESS=$(sh ${SCRIPTS_DIR}/get_localhost_ip.sh)

# Removes the VPN IP address if it exists
IP_ADDRESS_VPN=$(echo $IP_ADDRESS | awk '{print $2}')
IP_ADDRESS=$(echo $IP_ADDRESS | awk '{print $1}')

echo ""

# Get env vars from ".env" file
set -o allexport; . .env ; set +o allexport ;

if [ "${FRONTEND_LOCAL_PORT}" = "" ]; then
    FRONTEND_LOCAL_PORT="3000"
fi

if [ "${ACTION}" = "down" ]; then
    ${DOCKER_COMPOSE_CMD} -f ${SCRIPTS_DIR}/dns/docker-compose.yml down
fi

if [ "${ACTION}" = "rebuild" ]; then
    ${DOCKER_COMPOSE_CMD} -f ${SCRIPTS_DIR}/dns/docker-compose.yml down
    ${DOCKER_CMD} image rm dns-dns-server
    ACTION=""
fi

if [ "${ACTION}" = "restart" ]; then
    ${DOCKER_COMPOSE_CMD} -f ${SCRIPTS_DIR}/dns/docker-compose.yml down
    ACTION=""
fi

if [ "${ACTION}" = "enter" ]; then
    echo "Password: ${DNS_SERVER_PASSW}"
    ${DOCKER_CMD} exec -ti dns-server bash
fi

if [ "${ACTION}" = "test" ]; then
    echo "Local IP address: ${IP_ADDRESS}"
    if [ "${IP_ADDRESS_VPN}" != "" ]; then
        echo "VPN IP address: ${IP_ADDRESS_VPN}"
    fi
    echo ""
    echo "Make sure to add the IP address '${IP_ADDRESS}' to this computer's DNS configuration."
    echo "The current DNS configuration is:"
    scutil --dns
    echo ""
    echo "The next nslookup should point to that IP..."
    if [ "${IP_ADDRESS_VPN}" != "" ]; then
        # Add local IP address to DNS servers when VPN is on
        # sudo bash -c "echo 'nameserver ${IP_ADDRESS}' > /etc/resolver/${DNS_DOMAIN_NAME}"
        echo "but because the VPN is on, the nslookup and ping won't work..."
    fi
    echo ""
    echo nslookup ${DNS_DOMAIN_NAME} localhost
    nslookup ${DNS_DOMAIN_NAME} localhost
    echo ""
    echo ping ${DNS_DOMAIN_NAME}
    ping ${DNS_DOMAIN_NAME} -c 3
    echo ""

    if [ "${IP_ADDRESS_VPN}" != "" ]; then
        # Add local IP address to DNS servers when VPN is on
        # sudo bash -c "echo 'nameserver ${IP_ADDRESS}' > /etc/resolver/${DNS_DOMAIN_NAME}"
        echo "To make the '${DNS_DOMAIN_NAME}' domain to work locally, you better add IP address '${IP_ADDRESS}' to the 'hosts' file mannually:"
        echo "$ sudo nano /etc/hosts"
        echo ""
        echo "And add this line:"
        echo "${IP_ADDRESS} ${DNS_DOMAIN_NAME}"
        echo ""
    fi

    echo "Local DNS test finished."
    echo ""
fi

if [ "${ACTION}" = "" ]; then

    # This will be added to the DNS configuration file "/etc/bind/named.conf"
    echo "Creating ${TMP_WORKING_DIR}/dns/config/named-to-add.conf"
    mkdir -p ${TMP_WORKING_DIR}/dns/config
    cat > ${TMP_WORKING_DIR}/dns/config/named-to-add.conf <<EOF
zone "${DNS_DOMAIN_NAME}" {
    type master;
    file "/etc/bind/zones/${DNS_DOMAIN_NAME}";
};
EOF

    # This will be the domain zone configuration file
    echo "Creating ${TMP_WORKING_DIR}/dns/config/zones/${DNS_DOMAIN_NAME}"
    mkdir -p ${TMP_WORKING_DIR}/dns/config/zones
    cat > ${TMP_WORKING_DIR}/dns/config/zones/${DNS_DOMAIN_NAME} <<EOF
\$TTL    604800
@       IN      SOA     ${DNS_DOMAIN_NAME}. admin.${DNS_DOMAIN_NAME}. (
                            2023112601 ; Serial
                            604800     ; Refresh
                            86400      ; Retry
                            2419200    ; Expire
                            604800 )   ; Negative Cache TTL

@       IN      NS      ${DNS_DOMAIN_NAME}.
@       IN      A       ${IP_ADDRESS}
EOF
    echo "Copying ${TMP_WORKING_DIR}/dns/docker-compose.yml"
    cp ${SCRIPTS_DIR}/dns/docker-compose.yml ${TMP_WORKING_DIR}/dns/docker-compose.yml
    echo "Creating ${TMP_WORKING_DIR}/dns/Dockerfile"
    cp ${SCRIPTS_DIR}/dns/Dockerfile.template ${TMP_WORKING_DIR}/dns/Dockerfile
    perl -i -pe "s|APP_NAME_LOWERCASE_placeholder|${APP_NAME_LOWERCASE}|g" "${TMP_WORKING_DIR}/dns/Dockerfile"

    if ! source "${SCRIPTS_DIR}/container_engine_manager.sh" start "${CONTAINERS_ENGINE}" "${OPEN_CONTAINERS_ENGINE_APP}"
    then
        echo ""
        echo "Could not run container engine '${CONTAINERS_ENGINE}' automatically"
        echo ""
        exit 1
    fi

    if [ "${DOCKER_CMD}" = "" ]; then
        echo "" 
        echo "DOCKER_CMD is empty"
        exit_abort
    fi

    # Restart the DNS contaier to apply the new configuration
    if ${DOCKER_CMD} ps | grep dns-server -q
    then
        ${DOCKER_CMD} restart dns-server
    else
        ${DOCKER_COMPOSE_CMD} -f ${TMP_WORKING_DIR}/dns/docker-compose.yml up -d
    fi

    # Refresh the forntend/backend ".env" files to reflect the new domain name
    sh ${SCRIPTS_DIR}/change_local_ip_for_dev.sh ${DNS_DOMAIN_NAME}

    echo ""
    echo "All is set!"
    echo ""
    echo "Local DNS domain '${DNS_DOMAIN_NAME}' is pointing to IP address '${IP_ADDRESS}'."
    echo "Now the App can be accessed by using: http://${DNS_DOMAIN_NAME}:${FRONTEND_LOCAL_PORT}"
    if [ "${IP_ADDRESS_VPN}" != "" ]; then
        echo "VPN IP address: ${IP_ADDRESS_VPN}"
    fi
    echo ""
    echo "IMPORTANT: Please remember to re-start the local backend server."
    echo ""
    echo "If the local IP changes, make sure to do:"
    echo "  1) Run 'make local_dns_rebuild'"
    echo "  2) Copy the 'IP address' reported by the previous command."
    echo "  3) Run 'make restart_qa'"
    echo "  4) Add the 'IP address' to the DNS Servers in your computer's 'Network > DNS servers' settings. The new DNS Server 'IP address' must be the first one in the list of DNS servers."
    echo "  5) Restart the computer's WiFi or LAN network connection."
    echo ""
    echo "If you change the App you're developing, make sure to do:"
    echo "  1) Run 'make local_dns_rebuild'"
    echo "  1) Run 'make restart_qa'"
    echo ""
fi

${DOCKER_CMD} ps
