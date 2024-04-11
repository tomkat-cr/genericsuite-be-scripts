#!/bin/bash
# run_local_dns.sh
# 2023-11-27 | CR

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
CURRENT_SCRIPT_DIR="`pwd`"
cd "${REPO_BASEDIR}"

echo "Local DNS server starting..."

# Assumes it's run from the project root directory...
set -o allexport; . .env ; set +o allexport ;

if [ "${APP_NAME}" = "" ]; then
    echo "APP_NAME environment variable must be defined"
    exit 1
fi
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

if [ "${ACTION}" = "down" ]; then
    docker-compose -f ${SCRIPTS_DIR}/dns/docker-compose.yml down
fi

if [ "${ACTION}" = "rebuild" ]; then
    docker-compose -f ${SCRIPTS_DIR}/dns/docker-compose.yml down
    docker image rm dns-dns-server
    ACTION=""
fi

if [ "${ACTION}" = "restart" ]; then
    docker-compose -f ${SCRIPTS_DIR}/dns/docker-compose.yml down
    ACTION=""
fi

if [ "${ACTION}" = "enter" ]; then
    echo "Password: ${DNS_SERVER_PASSW}"
    docker exec -ti dns-server bash
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
    echo "Creating ${SCRIPTS_DIR}/dns/config/named-to-add.conf"
    mkdir -p ${SCRIPTS_DIR}/dns/config
    cat > ${SCRIPTS_DIR}/dns/config/named-to-add.conf <<EOF
zone "${DNS_DOMAIN_NAME}" {
    type master;
    file "/etc/bind/zones/${DNS_DOMAIN_NAME}";
};
EOF

    # This will be the domain zone configuration file
    echo "Creating ${SCRIPTS_DIR}/dns/config/zones/${DNS_DOMAIN_NAME}"
    mkdir -p ${SCRIPTS_DIR}/dns/config/zones
    cat > ${SCRIPTS_DIR}/dns/config/zones/${DNS_DOMAIN_NAME} <<EOF
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
    echo "Creating ${SCRIPTS_DIR}/dns/Dockerfile"
    cp ${SCRIPTS_DIR}/dns/Dockerfile.template ${SCRIPTS_DIR}/dns/Dockerfile
    perl -i -pe "s|APP_NAME_LOWERCASE_placeholder|${APP_NAME_LOWERCASE}|g" "${SCRIPTS_DIR}/dns/Dockerfile"

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

    # Restart the DNS contaier to apply the new configuration
    if docker ps | grep dns-server -q
    then
        docker restart dns-server
    else
        docker-compose -f ${SCRIPTS_DIR}/dns/docker-compose.yml up -d
    fi

    # Refresh the forntend/backend ".env" files to reflect the new domain name
    sh ${SCRIPTS_DIR}/change_local_ip_for_dev.sh ${DNS_DOMAIN_NAME}

    echo ""
    echo "All is set!"
    echo ""
    echo "Local DNS domain '${DNS_DOMAIN_NAME}' is pointing to IP address '${IP_ADDRESS}'."
    echo "Now the App can be accessed by using: http://${DNS_DOMAIN_NAME}:3000"
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
fi

docker ps
