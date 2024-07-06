#!/bin/bvash
# run-create-key-pair.sh
# 2024-06-29 | CR

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

STAGE="$1"

set -o allexport; . .env ; set +o allexport ;

# Validations
if [ "${STAGE}" = "" ]; then
    echo ""
    echo "ERROR: STAGE is not defined"
    exit_abort
fi
if [ "${AWS_LAMBDA_FUNCTION_NAME}" = "" ]; then
    echo ""
    echo "ERROR: AWS_LAMBDA_FUNCTION_NAME is not defined"
    exit_abort
fi

AWS_LAMBDA_FUNCTION_NAME_AND_STAGE=$(echo ${AWS_LAMBDA_FUNCTION_NAME}-${STAGE} | tr '[:upper:]' '[:lower:]')

KEY_PAIR_NAME="${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}-ec2-key-pair"
echo ""
echo "Checking if key pair ${KEY_PAIR_NAME} exists..."
echo ""
aws ec2 describe-key-pairs --key-names "${KEY_PAIR_NAME}" > /dev/null 2>&1
if [ $? -eq 0 ]
then
    echo "Key pair ${KEY_PAIR_NAME} already exists."
    exit 0
fi
# Delete existing key pair file
if [ -f ${HOME}/.ssh/${KEY_PAIR_NAME}.pem ]; then
    echo "Key pair ${KEY_PAIR_NAME} already exists. Removing it..."
    if ! rm -rf ${HOME}/.ssh/${KEY_PAIR_NAME}.pem; then
        echo "ERROR: Could not delete existing key pair."
        exit 1
    fi
fi
echo ""
echo "Creating ${KEY_PAIR_NAME}..."
echo ""
aws ec2 create-key-pair --key-name "${KEY_PAIR_NAME}" --query 'KeyMaterial' --output text > ${HOME}/.ssh/${KEY_PAIR_NAME}.pem
chmod 400 ${HOME}/.ssh/${KEY_PAIR_NAME}.pem
if [ $? -ne 0 ]
then
    echo "ERROR: Key pair could not be created."
    ls -lah ${HOME}/.ssh/${KEY_PAIR_NAME}.pem
    exit 1
fi
if [ ! -f ${HOME}/.ssh/${KEY_PAIR_NAME}.pem ]; then
    echo "ERROR: Key pair was not created."
    exit 1
fi
# if the key pair file has 0kb, error
if [ ! -s ${HOME}/.ssh/${KEY_PAIR_NAME}.pem ]; then
    echo "ERROR: Key pair file is empty."
    exit 1
fi
echo ""
echo "Created ${KEY_PAIR_NAME}."
echo ""
echo "To use this key pair, run:"
echo "  export AWS_EC2_KEY_PAIR_FILE=\${HOME}/.ssh/${KEY_PAIR_NAME}.pem"
echo ""
