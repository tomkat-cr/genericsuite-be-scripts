#!/bin/sh
# scripts/aws/run_aws.sh
# 2023-02-02 | CR
#
set -o allexport ; . .env ; set +o allexport ;

if [ "${APP_NAME}" = "" ]; then
    echo "APP_NAME not set"
    exit 1
fi

export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

# APP_DIR='chalicelib'
APP_DIR='lib'
AWS_STACK_NAME='${APP_NAME_LOWERCASE}-be-stack'

SSL_KEY_PATH="./app.${APP_NAME_LOWERCASE}.local.key"
SSL_CERT_PATH="./app.${APP_NAME_LOWERCASE}.local.chain.crt"
SSL_CA_CERT_PATH="./ca.crt"

# RUN_METHOD="uvicorn"
# RUN_METHOD="gunicorn"
# RUN_METHOD="chalice"
RUN_METHOD="chalice_docker"

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

echo "SCRIPTS_DIR: ${SCRIPTS_DIR}"
echo "REPO_BASEDIR: ${REPO_BASEDIR}"

ENV_FILESPEC=""
if [ -f "${REPO_BASEDIR}/.env" ]; then
    ENV_FILESPEC="${REPO_BASEDIR}/.env"
fi
if [ "$ENV_FILESPEC" != "" ]; then
    set -o allexport; source ${ENV_FILESPEC}; set +o allexport ;
fi

if [ "$PORT" = "" ]; then
    PORT="5001"
fi

if [ "$2" = "" ]; then
    STAGE="dev"
else
    STAGE="$2"
fi
STAGE_UPPERCASE=$(echo $STAGE | tr '[:lower:]' '[:upper:]')

if [ "$1" = "shell" ]; then
	pipenv shell
    pipenv --python ${PYTHON_VERSION}
fi

if [ "$1" = "pipfile" ]; then
	# pipenv shell
    pipenv --python ${PYTHON_VERSION}
    pipenv lock
    pipenv requirements > ${REPO_BASEDIR}/requirements.txt
fi

if [ "$1" = "clean" ]; then
    echo "Cleaning..."
    cd ${REPO_BASEDIR}/${APP_DIR} ;
    deactivate ;
    rm -rf __pycache__ ;
    rm -rf ../__pycache__ ;
    rm -rf bin ;
    rm -rf include ;
    rm -rf instance ;
    rm -rf lib ;
    rm -rf src ;
    rm -rf pyvenv.cfg ;
    rm -rf .vercel/cache ;
    rm -rf ../.vercel/cache ;
    rm -rf ../node_modules ;
    rm requirements.txt
    rm ../requirements.txt
    rm -rf var ;
    ls -lah
fi

if [[ "$1" = "test" ]]; then
    # echo "Error: no test specified" && exit 1
    echo "Run test..."
    python -m pytest
    echo "Done..."
fi

if [[ "$1" = "run_local" || "$1" = "" ]]; then
    cd ${REPO_BASEDIR}

    echo ""
    echo "Stage = ${STAGE}"
    echo "Port = ${PORT}"
    echo "RUN_METHOD = ${RUN_METHOD}"
    echo ""

    export IP_ADDRESS=$(sh ${SCRIPTS_DIR}/../get_localhost_ip.sh)
    export APP_DB_ENGINE=$(eval echo \$APP_DB_ENGINE_${STAGE_UPPERCASE})
    export APP_DB_NAME=$(eval echo \$APP_DB_NAME_${STAGE_UPPERCASE})
    export APP_DB_URI=$(eval echo \$APP_DB_URI_${STAGE_UPPERCASE})
    export APP_FRONTEND_AUDIENCE=$(eval echo \$APP_FRONTEND_AUDIENCE_${STAGE_UPPERCASE})
    export APP_CORS_ORIGIN="$(eval echo \"\$APP_CORS_ORIGIN_${STAGE_UPPERCASE}\")"
    export AWS_S3_CHATBOT_ATTACHMENTS_BUCKET=$(eval echo \$AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_${STAGE_UPPERCASE})
  
    if [ "${CURRENT_FRAMEWORK}" = "chalice" ]; then
        echo "Run over: 1) http [chalice], 2) https [chalice_docker], 3) use current [${RUN_METHOD}] (1/2/3) ?"
        read choice
        while [[ ! $choice =~ ^[123]$ ]]; do
            echo "Please enter 1 or 2"
            read choice
        done
        if [ $choice = "2" ]; then
            RUN_METHOD="chalice_docker"
        else
            RUN_METHOD="chalice"
            make down_qa
        fi
    fi
    if [ "${RUN_METHOD}" = "chalice" ]; then
        echo "sh ${SCRIPTS_DIR}/set_chalice_cnf.sh ${STAGE}" http
        sh ${SCRIPTS_DIR}/set_chalice_cnf.sh ${STAGE} http
        echo ""
        echo "pipenv run chalice local --host 0.0.0.0 --port ${PORT} --stage ${STAGE}"
        echo ""
        pipenv run chalice local --host 0.0.0.0 --port ${PORT} --stage ${STAGE} --autoreload
    fi

    if [ "${RUN_METHOD}" = "chalice_docker" ]; then
        echo "${SCRIPTS_DIR}/../secure_local_server/run.sh"
        ${SCRIPTS_DIR}/../secure_local_server/run.sh "run" ${STAGE}
    fi

    if [ "${RUN_METHOD}" = "gunicorn" ]; then
        echo "pipenv run run gunicorn --bind 0.0.0.0:${PORT} app:application --reload --certfile=${SSL_CERT_PATH} --keyfile=${SSL_KEY_PATH}" --forwarded-allow-ips="${IP_ADDRESS}"
        echo ""
        pipenv run gunicorn  app:application \
            --bind 0.0.0.0:${PORT} \
            --reload \
            --workers=2 \
            --certfile="${SSL_CERT_PATH}" \
            --keyfile="${SSL_KEY_PATH}" \
            --ciphers="TLSv1.2" \
            --proxy-protocol \
            --limit-request-field_size=200000 \
            --forwarded-allow-ips="${IP_ADDRESS},127.0.0.1,0.0.0.0" \
            --do-handshake-on-connect \
            --strip-header-spaces \
            --env PORT=${PORT} \
            --env APP_STAGE="${STAGE}"
    fi

    if [ "${RUN_METHOD}" = "uvicorn" ]; then
        echo "pipenv run uvicorn app:asgi_app --ssl-keyfile=${SSL_KEY_PATH} --ssl-certfile=${SSL_CERT_PATH} --reload --host 0.0.0.0 --port ${PORT}"
        echo ""
        pipenv run uvicorn app:asgi_app --ssl-keyfile=${SSL_KEY_PATH} --ssl-certfile=${SSL_CERT_PATH} --reload --host 0.0.0.0 --port ${PORT}  # --ca-certs=${SSL_CA_CERT_PATH}
    fi
fi

if [ "$1" = "run" ]; then
    cd ${REPO_BASEDIR}
    echo ""
    echo "PRODUCCION RUNNING: pipenv run chalice local --port ${PORT} --stage PROD"
    echo ""
    pipenv run chalice local --host 0.0.0.0 --port ${PORT} --stage prod
fi

if [ "$1" = "deploy" ]; then
    # This must be run first (and it's run by "make"):
    #    pipenv requirements > ${REPO_BASEDIR}/requirements.txt
    # Check option "pipfile"
    # Change to your Chalice project directory
    cd ${REPO_BASEDIR}
    pipenv run chalice package .chalice/deployment
    pipenv run chalice deploy --stage ${STAGE}
    if [ "${STAGE}" = "qa" ]; then
        perl -i -pe "s|APP_CORS_ORIGIN_QA=.*|APP_CORS_ORIGIN_QA=${APP_CORS_ORIGIN_QA_LOCAL}|g" "${ENV_FILESPEC}"
    fi
fi

if [ "$1" = "create_stack" ]; then
    aws cloudformation deploy --template-file "${REPO_BASEDIR}/.chalice/dynamodb_cf_template.yaml" --stack-name "${AWS_STACK_NAME}"
fi

if [ "$1" = "describe_stack" ]; then
    aws cloudformation describe-stack-events --stack-name "${AWS_STACK_NAME}"
fi

if [ "$1" = "delete_app" ]; then
    # Delete application
    cd ${REPO_BASEDIR}
    pipenv run chalice delete --stage ${STAGE}
fi

if [ "$1" = "delete_stack" ]; then
    # Delete DynamoDb tables
    aws cloudformation delete-stack --stack-name "${AWS_STACK_NAME}"
fi
