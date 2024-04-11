#!/bin/sh
# local_ssl_certs_copy.sh
# 2023-11-27 | CR
#
# google: how to automate openssl self signed certificate generation bash
# https://www.jamescoyle.net/how-to/1073-bash-script-to-create-an-ssl-certificate-key-and-request-csr
# https://gist.github.com/adamrunner/285746ca0f22b0f2e10192427e0b703c
#

echo ""
echo "Copy SSL certificates (crt/key) to a destination directory."

# if [ "$#" -ne 2 ]; then
#     echo "Usage: $0 DOMAIN DESTINATION_DIRECTORY"
#     exit 1
# fi

set -o allexport; source .env; set +o allexport ;

if [ "${APP_NAME}" = "" ]; then
    echo "ERROR: APP_NAME environment variable not defined"
    exit 1
fi

# Required
domain="$1"
destination_dir="$2"

export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

if [ "${domain}" = "" ]; then
    if [ "${APP_LOCAL_DOMAIN_NAME}" = "" ]; then
        domain="app.${APP_NAME_LOWERCASE}.local"
    else
        domain="${APP_LOCAL_DOMAIN_NAME}"
    fi
fi

if [ "${destination_dir}" = "" ]; then
    if [ "${FRONTEND_PATH}" = "" ]; then
        echo "FRONTEND_PATH environment variable is not defined"
        exit 1
    else
        destination_dir="${FRONTEND_PATH}"
    fi
fi

# Directories
src_directory="."

echo ""
echo "domain: ${domain}"
echo "src_directory: ${src_directory}"
echo "destination_dir: ${destination_dir}"
echo ""

cp $src_directory/${domain}.key $destination_dir/${domain}.key
cp $src_directory/${domain}.crt $destination_dir/${domain}.crt
cp $src_directory/${domain}.chain.crt $destination_dir/${domain}.chain.crt
cp $src_directory/ca.crt $destination_dir/ca.crt

echo ""
echo "Done!"
echo ""
