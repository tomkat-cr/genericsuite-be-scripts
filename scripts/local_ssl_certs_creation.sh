#!/bin/sh
# local_ssl_certs_creation.sh
# 2023-11-27 | CR
#
# google: how to automate openssl self signed certificate generation bash
# https://www.jamescoyle.net/how-to/1073-bash-script-to-create-an-ssl-certificate-key-and-request-csr
# https://gist.github.com/adamrunner/285746ca0f22b0f2e10192427e0b703c
#
echo ""
echo "Create auto-signed SSL certificates (crt/key)"

# if [ "$#" -ne 1 ]; then
#     echo "Create auto-signed SSL certificates (crt/key)"
#     echo "Usage: $0 DOMAIN"
#     exit 1
# fi

# Stop script on any error
set -e

# Default values

if [ "${SSL_CERT_GEN_METHOD}" = "" ]; then
    SSL_CERT_GEN_METHOD="mkcert"
    # SSL_CERT_GEN_METHOD="office-addin-dev-certs"
    # SSL_CERT_GEN_METHOD="openssl"
fi

set -o allexport; source .env; set +o allexport ;

if [ "${APP_NAME}" = "" ]; then
    echo "ERROR: APP_NAME environment variable not defined"
    exit 1
fi
export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

if [ "${APP_DOMAIN_NAME}" = "" ]; then
    APP_DOMAIN_NAME="${APP_NAME_LOWERCASE}.com"
fi

# Required
domain=$1
if [ "${domain}" = "" ]; then
    if [ "${APP_LOCAL_DOMAIN_NAME}" = "" ]; then
        domain="app.${APP_NAME_LOWERCASE}.local"
    else
        domain="${APP_LOCAL_DOMAIN_NAME}"
    fi
fi

destination_dir="$2"
if [ "${destination_dir}" = "" ]; then
    destination_dir="."
fi

# Directories
directory_csr="/tmp"
directory_key="${destination_dir}"
directory_crt="${destination_dir}"

cert_key="$directory_key/${domain}.key"
cert_crt="$directory_crt/${domain}.crt"
cert_chain="$directory_crt/${domain}.chain.crt"
cert_ca="$directory_crt/ca.crt"

if [ "${SSL_CERT_GEN_METHOD}" = "mkcert" ]; then
    # Generate and Trust a Local Certificate Authority
    # Use a tool like mkcert to create a local Certificate Authority (CA) and generate trusted SSL certificates for your development environment.
    # https://github.com/FiloSottile/mkcert

    # 1) Install mkcert in MacOS:
    brew install mkcert nss

    # 2) Install the local CA:
    mkcert -install

    # 3) Generate a certificate for the local domain name, e.g. app.exampleapp.local, in the current directory:
    mkcert -key-file "${cert_key}" -cert-file "${cert_crt}" "${domain}"

    mkcert_cert_ca_path="$(mkcert -CAROOT)/rootCA.pem"

    echo ""
    echo "Copying: '${mkcert_cert_ca_path}' to '${cert_ca}'"
    if ! cp -p "${mkcert_cert_ca_path}" "${cert_ca}"
    then
        echo ""
        echo "Error copying mkcert CA certificate"
        exit 1
    fi
    echo ""
    echo "Concatenating: '${cert_crt}' and '${cert_ca}' to '${cert_chain}'"
    if ! cat "${cert_crt}" "${cert_ca}" > "${cert_chain}"
    then
        echo ""
        echo "Error concatenating mkcert CA certificate and certificate"
        exit 1
    fi

elif [ "${SSL_CERT_GEN_METHOD}" = "office-addin-dev-certs" ]; then
    src_directory="${HOME}/.office-addin-dev-certs"

    echo "You'll be asked for your user's password to generate the SSL keys..."
    echo "Press ENTER to proceed, Ctrl-C to stop"
    read key_pressed

    if [ -d $src_directory ]; then
        rm $src_directory/localhost.key
        rm $src_directory/localhost.crt
        rm $src_directory/ca.crt
    fi

    if [[ -f $directory_crt/${domain}.chain.crt || -d $directory_crt/${domain}.chain.crt ]]; then
        rm -rf $directory_crt/${domain}.chain.crt
    fi
    if [[ -f $directory_key/${domain}.key || -d $directory_key/${domain}.key ]]; then
        rm -rf $directory_key/${domain}.key
    fi
    if [[ -f $directory_crt/${domain}.crt || -d $directory_crt/${domain}.crt ]]; then
        rm -rf $directory_crt/${domain}.crt
    fi
    if [[ -f $directory_crt/ca.crt || -d $directory_crt/ca.crt ]]; then
        rm -rf $directory_crt/ca.crt
    fi

    # npm install -D office-addin-dev-certs
    npx office-addin-dev-certs install --domains ${domain}

    cat $src_directory/localhost.crt $src_directory/ca.crt > $directory_crt/${domain}.chain.crt
    cp $src_directory/localhost.key $directory_key/${domain}.key
    cp $src_directory/localhost.crt $directory_crt/${domain}.crt
    cp $src_directory/ca.crt $directory_crt/ca.crt

else
    # Required
    commonname=$domain

    # Change to your company details
    country="US"
    state="Florida"
    locality="Fort Lauderdale"
    organization="${APP_DOMAIN_NAME}"
    organizationalunit="IT"
    email="info@$domain"

    # Optional
    password=dummypassword

    if [ -z "$domain" ]
    then
        echo "Argument not present."
        echo "Usage $0 [common name]"
        echo "E.g. $0 app.${APP_NAME_LOWERCASE}.local"
        exit 1
    fi

    echo "Generating key request for $domain"

    # Generate a key
    openssl genrsa -des3 -passout pass:$password -out $directory_key/${domain}.key 2048

    # Remove passphrase from the key. Comment the line out to keep the passphrase
    echo "Removing passphrase from key"
    openssl rsa -in $directory_key/${domain}.key -passin pass:$password -out $directory_key/${domain}.key

    # Create the request
    echo "Creating CSR"
    openssl req -new -key $directory_key/${domain}.key -out $directory_csr/$domain.csr -passin pass:$password -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"

    # Generate the cert (good for 1 years)
    echo "Generating certificate"
    openssl x509 -req -days 365 -in $directory_csr/$domain.csr -signkey $directory_key/${domain}.key -out $directory_crt/${domain}.crt 

    # Creating the ca.crt file
    echo "Creating ca.crt file"
    cp -p $directory_crt/${domain}.crt $directory_crt/ca.crt

    # Creating the chain file
    echo "Creating chain file"
    cat $directory_crt/${domain}.crt $directory_crt/ca.crt > $directory_crt/${domain}.chain.crt

    echo ""
    echo "---------------------------"
    echo "-----Below is your CSR-----"
    echo "---------------------------"
    echo "Filespec: $directory_csr/$domain.csr"
    echo "---------------------------"
    echo
    cat $directory_csr/$domain.csr
fi

echo
echo "---------------------------"
echo "-----Below is your Key-----"
echo "---------------------------"
echo "Filespec: $cert_key"
echo "---------------------------"
echo
cat $cert_key

echo
echo "-----------------------------------"
echo "-----Below is your Certificate-----"
echo "-----------------------------------"
echo "Filespec: $cert_crt"
echo "-----------------------------------"
echo
cat $cert_crt 

echo
echo "-----------------------------------------"
echo "-----Below is your CA Certificate-----"
echo "-----------------------------------------"
echo "Filespec: $cert_ca"
echo "-----------------------------------------"
echo
cat $cert_ca 

echo
echo "-----------------------------------------"
echo "-----Below is your Chain Certificate-----"
echo "-----------------------------------------"
echo "Filespec: $cert_chain"
echo "-----------------------------------------"
echo
cat $cert_chain 

echo ""
echo "Done!"
echo ""
