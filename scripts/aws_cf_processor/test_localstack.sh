
#!/bin/bash -xeu
# test_localstack.sh
# 2024-07-16 |} CR

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

BASE_DIR="$(pwd)"
# Get the real script directory
SCRIPTS_DIR="$( cd -- "$(dirname "$BASH_SOURCE")" >/dev/null 2>&1 ; pwd -P )"
cd "${BASE_DIR}"

echo ""
echo "Checking .env file..."
echo ""

if [ ! -f .env ]; then
    echo "ERROR: .env file does not exist. Please create it and set LOCALSTACK_AUTH_TOKEN."
    exit 1
fi

set -o allexport; . .env ; set +o allexport ;

if [ -z "${LOCALSTACK_AUTH_TOKEN}" ]; then
    echo "ERROR: LOCALSTACK_AUTH_TOKEN not set"
    exit 1
fi

WORK_DIR="/tmp/localstack_ec2_test"

echo ""
echo "Checking working directory: ${WORK_DIR}"
echo ""

mkdir -p "${WORK_DIR}"
if ! cd "${WORK_DIR}"
then
    echo "ERROR: cannot change to the working directory: ${WORK_DIR}"
    exit 1
fi

echo ""
echo "Checking venv..."
echo ""

if [ -d venv ]; then
    . venv/bin/activate
else
    python3 -m venv venv
    . venv/bin/activate
    pip install --force-reinstall --no-cache --upgrade pip awscli-local
    pip freeze > requirements.txt
fi

echo ""
echo "Creating ./user_script.sh..."
echo ""

cat <<EOF2 > ./user_script.sh
#!/bin/bash -xeu

apt update
apt install python3 -y
python3 -m http.server 8000

EOF2

echo ""
echo "Checking localstack..."
echo ""

if ! localstack --version
then
    brew install localstack/tap/localstack-cli
fi

echo ""
echo "Checking docker..."
echo ""

docker_dependencies

echo ""
echo "Cleaning previous localstack execution..."
echo ""

${DOCKER_CMD} stop localstack-main
${DOCKER_CMD} rm localstack-main
localstack stop
# sleep 20

echo ""
echo "Starting localstack..."
echo "IMPORTANT: if localstack won't start due to port 443 issues, set 'Allow privileged port mapping (requires password)' in the Docker Desktop configuration"
echo ""

localstack start &
sleep 20

if ! localstack status
then
    echo "ERROR: localstack could not be started"
    exit 1
fi

echo ""
echo "AWS Resources (after):"
echo ""
awslocal ec2 describe-key-pairs | jq
awslocal ec2 describe-instances | jq
awslocal ec2 describe-security-groups | jq
echo ""

rm -rf key.pem

awslocal ec2 create-key-pair \
    --key-name my-key \
    --query 'KeyMaterial' \
    --output text | tee key.pem

SECURITY_GROUP_NAME="default"

echo "SECURITY_GROUP_NAME: ${SECURITY_GROUP_NAME}"

awslocal ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP_NAME} \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

awslocal ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP_NAME} \
    --protocol tcp \
    --port 8000 \
    --cidr 0.0.0.0/0

SECURITY_GROUP_IDS=$(awslocal ec2 describe-security-groups \
    --filters Name=group-name,Values=${SECURITY_GROUP_NAME} \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

echo "SECURITY_GROUP_IDS: ${SECURITY_GROUP_IDS}"

chmod 400 key.pem

awslocal ec2 run-instances \
    --image-id ami-ff0fea8310f3 \
    --count 1 \
    --instance-type t3.nano \
    --key-name my-key \
    --security-group-ids "${SECURITY_GROUP_IDS}" \
    --user-data file://./user_script.sh | jq

EC2_IP=$(awslocal ec2 describe-instances \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "EC2_IP: ${EC2_IP}"

echo ""
echo "AWS Resources (before):"
echo ""
awslocal ec2 describe-key-pairs | jq
awslocal ec2 describe-instances | jq
awslocal ec2 describe-security-groups | jq

echo ""
echo "localstack logs"
echo ""
localstack logs

echo ""
echo "Access the EC2 instance using this command:"
echo "ssh -i "${WORK_DIR}/key.pem" root@${EC2_IP} -p 22"
# echo "ssh -p 12862 -i key.pem root@127.0.0.1"
echo ""
echo "And test with:"
echo "curl ${EC2_IP}:8000"
echo "curl \"http://${EC2_IP}:8000\""
