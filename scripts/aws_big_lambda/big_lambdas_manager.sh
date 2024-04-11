#!/bin/bash
# big_lambdas_manager.sh
# 2023-12-10 | CR

# Reference:
# Deploy Python Lambda functions with container images
# https://docs.aws.amazon.com/lambda/latest/dg/python-image.html#python-image-instructions

DEBUG="0"

exit_abort() {
    echo ""
    echo "Aborting..."
    echo ""
    exit 1
}

if [ "$1" = "" ]; then
  echo "Usage: $0 ACTION STAGE FRONTEND_DIRECTORY"
  exit_abort
fi

ask_to_continue() {
    echo "Continue (Y/n)?"
    read choice
    while [[ ! $choice =~ ^[YyNn]$ ]]; do
        echo "Please enter Y or N"
        read choice
    done
    if [ $choice = "n" ]; then
        exit_abort
    fi
}    

ask_for_force_ecr_image_creation() {
  echo "Do you want to perform the AWS ECR image creation (Y/n)?"
  read choice
  while [[ ! $choice =~ ^[YyNn]$ ]]; do
    echo "Please enter Y or N"
    read choice
  done
  if [[ $choice =~ ^[Yy]$ ]]; then
    FORCE_ECR_IMAGE_CREATION="1"
  else
    FORCE_ECR_IMAGE_CREATION="0"
  fi
}

ask_for_app_version() {
    APP_VERSION=$(cat ${REPO_BASEDIR}/version.txt)
    echo "What will be the new App version? (press Enter for default: ${APP_VERSION})"
    read new_version
    if [ "${new_version}" != "" ]; then
        APP_VERSION="${new_version}"
    fi
    echo "New App version will be: ${APP_VERSION}"
    echo "Are you sure (Y/n)?"
    read choice
    while [[ ! $choice =~ ^[YyNn]$ ]]; do
        echo "Please enter Y or N"
        read choice
    done
    if [[ ! $choice =~ ^[Yy]$ ]]; then
        exit_abort
    fi
    write_new_app_version
}

ask_for_frontend_version_assignment() {
  echo "Do you want to assign the version ${APP_VERSION} to the frontend '${FRONTEND_DIRECTORY}' (Y/n)?"
  read choice
  while [[ ! $choice =~ ^[YyNn]$ ]]; do
    echo "Please enter Y or N"
    read choice
  done
  if [[ $choice =~ ^[Yy]$ ]]; then
    if [ -d "${FRONTEND_DIRECTORY}" ]; then
      echo "The frontend path '${FRONTEND_DIRECTORY}' exists..."
      if [ -f "${FRONTEND_DIRECTORY}/version.txt" ]; then
        echo "The frontend '${FRONTEND_DIRECTORY}/version.txt' file exists..."
        echo "All clear!"
        COPY_VERSION_TO_FRONTEND="1"
      else
        echo "ERROR: The frontend '${FRONTEND_DIRECTORY}/version.txt' file does NOT exists."
        exit_abort
      fi
    else
      if [ "${FRONTEND_DIRECTORY}" = "" ]; then
        echo "ERROR: the FRONTEND_DIRECTORY (parameter #3) is missing and it's required to copy the version."
      else
        echo "ERROR: the frontend '${FRONTEND_DIRECTORY}' directory does NOT exist..."
      fi
      exit_abort
    fi
  else
    COPY_VERSION_TO_FRONTEND="0"
  fi
}

perform_frontend_version_assignment() {
  if [ "${COPY_VERSION_TO_FRONTEND}" = "1" ]; then
    if ! echo ${APP_VERSION} > "${FRONTEND_DIRECTORY}/version.txt"
    then
      echo "ERROR: could not assign the version ${APP_VERSION} in the frontend file '${FRONTEND_DIRECTORY}/version.txt'"
      exit_abort
    else
      echo "Successfull version ${APP_VERSION} assignment in the frontend file '${FRONTEND_DIRECTORY}/version.txt'"
    fi
  fi
}

ask_for_sam_guided_deployment() {
    echo "Do you want to do a SAM Automatic (not guided) Deployment (y/n)?"
    read choice
    while [[ ! $choice =~ ^[YyNn]$ ]]; do
        echo "Please enter Y or N"
        read choice
    done
    if [[ $choice =~ ^[Yy]$ ]]; then
      SAM_GUIDED="n"
    else
      SAM_GUIDED="y"
    fi
    echo "Do you want to Force Upload in the SAM Deployment (y/n)?"
    read choice
    while [[ ! $choice =~ ^[YyNn]$ ]]; do
        echo "Please enter Y or N"
        read choice
    done
    if [[ $choice =~ ^[Yy]$ ]]; then
      SAM_FORCED="--force-upload"
    else
      SAM_FORCED=""
    fi
}

write_new_app_version() {
    echo ${APP_VERSION} > ${REPO_BASEDIR}/version.txt
}

ask_for_docker_image_version() {
    echo "What will be the Docker Image version to use? (e.g. latest or a version number)."
    echo "(press Enter for default: ${APP_VERSION})"
    read new_version
    if [ "${new_version}" = "" ]; then
      DOCKER_IMAGE_VERSION="${APP_VERSION}"
    else
      DOCKER_IMAGE_VERSION="${new_version}"
    fi
    echo ""
    echo "Docker image version to be used: ${DOCKER_IMAGE_VERSION}"
    echo "Image URI: ${AWS_DOCKER_IMAGE_URI_BASE}/${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}:${DOCKER_IMAGE_VERSION}"
    echo "Do you agree with that (Y/n)?"
    read choice
    while [[ ! $choice =~ ^[YyNn]$ ]]; do
        echo "Please enter Y or N"
        read choice
    done
    if [[ ! $choice =~ ^[Yy]$ ]]; then
        exit_abort
    fi
    AWS_DOCKER_IMAGE_URI="${AWS_DOCKER_IMAGE_URI_BASE}/${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}:${DOCKER_IMAGE_VERSION}"
}

ask_for_docker_system_prune() {
    echo "Do you want to perform a Docker System Prune to have more free disk space (y/n)?"
    read choice
    while [[ ! $choice =~ ^[YyNn]$ ]]; do
        echo "Please enter Y or N"
        read choice
    done
    if [[ $choice =~ ^[Yy]$ ]]; then
      DOCKER_PRUNE="y"
    else
      DOCKER_PRUNE="n"
    fi
}

docker_system_prune() {
    if [[ ${DOCKER_PRUNE} = "y" ]]; then
      # To handle the error "yum install ... Disk Requirements: ... At least ...MB more space needed on the / filesystem." during the "docker buildx build ..."
      echo ""
      echo docker system prune -a
      docker system prune -a
      echo ""
    fi
}    

verify_docker_image_exist() {
    ERROR_MSG=""
    ECR_REPO_URI=$(aws ecr describe-repositories \
      --repository-names ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} \
      --region ${AWS_REGION} \
      --query 'repositories[0].repositoryUri' \
      --output text
    )
    if [ "${ECR_REPO_URI}" = "" ]; then
        if [ "${FORCE_ECR_IMAGE_CREATION}" = "0" ];then
            ERROR_MSG="ERROR: ECR repository does not exist: ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}"
        else
            echo "ECR repository will be created: ${AWS_DOCKER_IMAGE_URI}"
        fi
    else
        echo "ECR repository exists: ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}..."
        echo "Verifying ECR repository URI: ${AWS_DOCKER_IMAGE_URI}..."
        if aws ecr describe-images --repository-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} --region ${AWS_REGION} --image-ids imageTag=${DOCKER_IMAGE_VERSION} >/dev/null 2>&1
        then
            echo "ECR repository URI exists..."
            if [ "${FORCE_ECR_IMAGE_CREATION}" = "1" ];then
                echo "and it'll be overwritten..."
            else
                echo "and it'll remain the same"
            fi
        else
            if [ "${FORCE_ECR_IMAGE_CREATION}" = "0" ];then
                ERROR_MSG="ERROR: Docker image version '${DOCKER_IMAGE_VERSION}' does not exist in the ECR repository: ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}, and the image creation wasn't ordered..."
                echo ${ERROR_MSG}
            else
                echo "ECR repository URI does not exists and it'll be created..."
            fi
        fi
    fi
    echo ""
}

recover_at_sign() {
    # Replace @ with \@
    APP_SUPERADMIN_EMAIL=${APP_SUPERADMIN_EMAIL//@/\\@}
    APP_SECRET_KEY=${APP_SECRET_KEY//@/\\@}
    APP_DB_URI_DEV=${APP_DB_URI_DEV//@/\\@}
    APP_DB_URI_QA=${APP_DB_URI_QA//@/\\@}
    APP_DB_URI_STAGING=${APP_DB_URI_STAGING//@/\\@}
    APP_DB_URI_PROD=${APP_DB_URI_PROD//@/\\@}
    APP_DB_URI_DEMO=${APP_DB_URI_DEMO//@/\\@}
    APP_DB_URI=${APP_DB_URI//@/\\@}
    SMTP_DEFAULT_SENDER=${SMTP_DEFAULT_SENDER//@/\\@}
    SMTP_USER=${SMTP_USER//@/\\@}
    SMTP_PASSWORD=${SMTP_PASSWORD//@/\\@}
    OPENAI_API_KEY=${OPENAI_API_KEY//@/\\@}
    LANGCHAIN_API_KEY=${LANGCHAIN_API_KEY//@/\\@}
    GOOGLE_API_KEY=${GOOGLE_API_KEY//@/\\@}
    HUGGINGFACE_API_KEY=${HUGGINGFACE_API_KEY//@/\\@}
}

set_env_vars_file() {
    # Prepare env vars and .env file for deployment
    cd "${REPO_BASEDIR}"
    pwd
    echo "sh ${SCRIPTS_DIR}/../aws/set_chalice_cnf.sh ${STAGE} deploy"
    sh ${SCRIPTS_DIR}/../aws/set_chalice_cnf.sh ${STAGE} deploy

    # Relooad env vars from .env file
    set -o allexport; . .env ; set +o allexport ;

    # Replace @ with \@
    recover_at_sign

    cat > "${TMP_BUILD_DIR}/set_env_vars.sh" <<END \

export APP_DB_ENGINE=$(eval echo \$APP_DB_ENGINE_${STAGE_UPPERCASE})
export APP_DB_NAME=$(eval echo \$APP_DB_NAME_${STAGE_UPPERCASE})
export APP_DB_URI=$(eval echo \$APP_DB_URI_${STAGE_UPPERCASE})
export APP_FRONTEND_AUDIENCE=$(eval echo \$APP_FRONTEND_AUDIENCE_${STAGE_UPPERCASE})
export APP_CORS_ORIGIN="$(eval echo \"\$APP_CORS_ORIGIN_${STAGE_UPPERCASE}\")"
export AWS_S3_CHATBOT_ATTACHMENTS_BUCKET=$(eval echo \$AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_${STAGE_UPPERCASE})
export CURRENT_FRAMEWORK="${CURRENT_FRAMEWORK}"
export DEFAULT_LANG="${DEFAULT_LANG}"
export APP_NAME="${APP_NAME}"
export AI_ASSISTANT_NAME="${AI_ASSISTANT_NAME}"
export FLASK_APP="${FLASK_APP}"
export APP_SECRET_KEY="${APP_SECRET_KEY}"
export APP_SUPERADMIN_EMAIL="${APP_SUPERADMIN_EMAIL}"
export GIT_SUBMODULE_URL="${GIT_SUBMODULE_URL}"
export GIT_SUBMODULE_LOCAL_PATH="${GIT_SUBMODULE_LOCAL_PATH}"
export OPENAI_API_KEY="${OPENAI_API_KEY}"
export OPENAI_MODEL="${OPENAI_MODEL}"
export OPENAI_TEMPERATURE="${OPENAI_TEMPERATURE}"
export GOOGLE_API_KEY="${GOOGLE_API_KEY}"
export GOOGLE_CSE_ID="${GOOGLE_CSE_ID}"
export LANGCHAIN_API_KEY="${LANGCHAIN_API_KEY}"
export LANGCHAIN_PROJECT="${LANGCHAIN_PROJECT}"
export HUGGINGFACE_API_KEY="${HUGGINGFACE_API_KEY}"
export HUGGINGFACE_ENDPOINT_URL="${HUGGINGFACE_ENDPOINT_URL}"
export SMTP_SERVER="${SMTP_SERVER}"
export SMTP_PORT="${SMTP_PORT}"
export SMTP_USER="${SMTP_USER}"
export SMTP_PASSWORD="${SMTP_PASSWORD}"
export SMTP_DEFAULT_SENDER="${SMTP_DEFAULT_SENDER}"
END
    set -o allexport; . "${TMP_BUILD_DIR}/set_env_vars.sh" ; set +o allexport ;

    ENV_VARIABLES="{
  CURRENT_FRAMEWORK=${CURRENT_FRAMEWORK},
  DEFAULT_LANG=${DEFAULT_LANG},
  APP_NAME=${APP_NAME},
  AI_ASSISTANT_NAME=${AI_ASSISTANT_NAME},
  APP_DEBUG=${APP_DEBUG},
  APP_STAGE=${APP_STAGE},
  FLASK_APP=${FLASK_APP},
  GIT_SUBMODULE_URL=${GIT_SUBMODULE_URL},
  GIT_SUBMODULE_LOCAL_PATH=${GIT_SUBMODULE_LOCAL_PATH},
  AWS_S3_CHATBOT_ATTACHMENTS_BUCKET=${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET},
  APP_CORS_ORIGIN=${APP_CORS_ORIGIN},
  APP_DB_NAME=${APP_DB_NAME},
  APP_SECRET_KEY=${APP_SECRET_KEY},
  SMTP_USER=${SMTP_USER},
  SMTP_DEFAULT_SENDER=${SMTP_DEFAULT_SENDER},
  APP_SUPERADMIN_EMAIL=${APP_SUPERADMIN_EMAIL},
  SMTP_PORT=${SMTP_PORT},
  APP_FRONTEND_AUDIENCE=${APP_FRONTEND_AUDIENCE},
  APP_DB_URI=${APP_DB_URI},
  OPENAI_TEMPERATURE=${OPENAI_TEMPERATURE},
  GOOGLE_API_KEY="${GOOGLE_API_KEY}"
  GOOGLE_CSE_ID="${GOOGLE_CSE_ID}"
  LANGCHAIN_API_KEY="${LANGCHAIN_API_KEY}"
  LANGCHAIN_PROJECT="${LANGCHAIN_PROJECT}"
  HUGGINGFACE_API_KEY="${HUGGINGFACE_API_KEY}"
  HUGGINGFACE_ENDPOINT_URL="${HUGGINGFACE_ENDPOINT_URL}"
  SMTP_PASSWORD=${SMTP_PASSWORD},
  SMTP_SERVER=${SMTP_SERVER},
  OPENAI_API_KEY=${OPENAI_API_KEY},
  OPENAI_MODEL=${OPENAI_MODEL},
  APP_DB_ENGINE=${APP_DB_ENGINE}
}"
    ENV_VARIABLES_DOCKER_RUN="
  --env CURRENT_FRAMEWORK=\"${CURRENT_FRAMEWORK}\"
  --env DEFAULT_LANG=\"${DEFAULT_LANG}\"
  --env APP_NAME=\"${APP_NAME}\"
  --env APP_DEBUG=\"${APP_DEBUG}\"
  --env APP_STAGE=\"${APP_STAGE}\"
  --env FLASK_APP=\"${FLASK_APP}\"
  --env GIT_SUBMODULE_URL=\"${GIT_SUBMODULE_URL}\"
  --env GIT_SUBMODULE_LOCAL_PATH=\"${GIT_SUBMODULE_LOCAL_PATH}\"
  --env AWS_S3_CHATBOT_ATTACHMENTS_BUCKET=\"${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET}\"
  --env APP_CORS_ORIGIN=\"${APP_CORS_ORIGIN}\"
  --env APP_DB_NAME=\"${APP_DB_NAME}\"
  --env APP_SECRET_KEY=\"${APP_SECRET_KEY}\"
  --env SMTP_USER=\"${SMTP_USER}\"
  --env SMTP_DEFAULT_SENDER=\"${SMTP_DEFAULT_SENDER}\"
  --env APP_SUPERADMIN_EMAIL=\"${APP_SUPERADMIN_EMAIL}\"
  --env SMTP_PORT=\"${SMTP_PORT}\"
  --env APP_FRONTEND_AUDIENCE=\"${APP_FRONTEND_AUDIENCE}\"
  --env APP_DB_URI=\"${APP_DB_URI}\"
  --env OPENAI_TEMPERATURE=\"${OPENAI_TEMPERATURE}\"
  --env GOOGLE_API_KEY=\"${GOOGLE_API_KEY}\"
  --env GOOGLE_CSE_ID=\"${GOOGLE_CSE_ID}\"
  --env LANGCHAIN_API_KEY=\"${LANGCHAIN_API_KEY}\"
  --env LANGCHAIN_PROJECT=\"${LANGCHAIN_PROJECT}\"
  --env HUGGINGFACE_API_KEY=\"${HUGGINGFACE_API_KEY}\"
  --env HUGGINGFACE_ENDPOINT_URL=\"${HUGGINGFACE_ENDPOINT_URL}\"
  --env SMTP_PASSWORD=\"${SMTP_PASSWORD}\"
  --env SMTP_SERVER=\"${SMTP_SERVER}\"
  --env OPENAI_API_KEY=\"${OPENAI_API_KEY}\"
  --env OPENAI_MODEL=\"${OPENAI_MODEL}\"
  --env APP_DB_ENGINE=\"${APP_DB_ENGINE}\"
"
  echo ""
  echo "Variables generation ended."
}

prepare_tmp_build_dir() {
    # How to copy multiple files in one layer using a Dockerfile?
    # https://stackoverflow.com/questions/30256386/how-to-copy-multiple-files-in-one-layer-using-a-dockerfile
    # If you want to copy multiple directories (not their contents) under a destination directory
    # in a single command, you'll need to set up the build context so that your source directories
    # are under a common parent and then COPY that parent.

    echo ""
    echo "Create temporary directories in: ${TMP_BUILD_DIR}"
    echo ""

    echo "Removing existing: ${TMP_BUILD_DIR}"
    rm -rf "${TMP_BUILD_DIR}"

    echo "Create directory: ${TMP_BUILD_DIR}/lib"
    mkdir -p "${TMP_BUILD_DIR}"/lib

    if [ -d genericsuite ]; then
      echo "Create directory: ${TMP_BUILD_DIR}/genericsuite"
      mkdir -p "${TMP_BUILD_DIR}"/genericsuite
    fi
    if [ -d genericsuite_ai ]; then
      echo "Create directory: ${TMP_BUILD_DIR}/genericsuite_ai"
      mkdir -p "${TMP_BUILD_DIR}"/genericsuite_ai
    fi
    if [ -d chalicelib ]; then
      echo "Create directory: ${TMP_BUILD_DIR}/chalicelib"
      mkdir -p "${TMP_BUILD_DIR}"/chalicelib
    fi
    if [ -d fastapilib ]; then
      echo "Create directory: ${TMP_BUILD_DIR}/fastapilib"
      mkdir -p "${TMP_BUILD_DIR}"/fastapilib
    fi
    if [ -d flasklib ]; then
      echo "Create directory: ${TMP_BUILD_DIR}/flasklib"
      mkdir -p "${TMP_BUILD_DIR}"/flasklib
    fi

    echo ""
    echo "Prepare environment variables..."
    set_env_vars_file

    echo ""
    echo "Create SAM Yaml file..."
    create_sam_yaml

    cd "${REPO_BASEDIR}"

    echo ""
    echo "Copy code files started..."

    echo "Copy repo root dir code files"
    if [[ "${CURRENT_FRAMEWORK}" = "chalice" || "${CURRENT_FRAMEWORK}" = "chalice_docker" ]]; then
      # For Chalice framework, copy the initial run application (app.py) to the root build directory
      cp app.py ${TMP_BUILD_DIR}/
    fi
    cp requirements.txt ${TMP_BUILD_DIR}/

    echo "Copy credentials files"
    cp app.${APP_NAME_LOWERCASE}.local.key ${TMP_BUILD_DIR}/
    cp app.${APP_NAME_LOWERCASE}.local.crt ${TMP_BUILD_DIR}/
    cp app.${APP_NAME_LOWERCASE}.local.chain.crt ${TMP_BUILD_DIR}/
    cp ca.crt ${TMP_BUILD_DIR}/

    if [ -d .chalice/deployment/deployment.zip ]; then
      echo "Copy deployment.zip file"
      cp .chalice/deployment/deployment.zip ${TMP_BUILD_DIR}/
    fi

    echo "Copy SAM related files"
    cp ${SCRIPTS_DIR}/template.yml ${TMP_BUILD_DIR}/
    cp ${SCRIPTS_DIR}/samconfig.toml ${TMP_BUILD_DIR}/
    cp ${SCRIPTS_DIR}/run_api_gateway.sh ${TMP_BUILD_DIR}/

    cp ${SCRIPTS_DIR}/docker-compose-big-lambda-${TARGET_OS}.yml ${TMP_BUILD_DIR}/

    cp ${SCRIPTS_DIR}/Dockerfile-big-lambda-${TARGET_OS} ${TMP_BUILD_DIR}/Dockerfile
    # For non-Chalice frameworks, change the initial run command: CMD [ "app.app" ] >> CMD [ "lib/app.app" ]
    if [ "${APP_DIR}" != "." ]; then
      perl -i -pe "s|CMD [ \"app.app\" ]|CMD [ \"${APP_DIR}.${APP_MAIN_FILE}:app\" ]|g" ${TMP_BUILD_DIR}/Dockerfile
    fi

    cp ${SCRIPTS_DIR}/entry-${TARGET_OS}.sh ${TMP_BUILD_DIR}/
    cp ${SCRIPTS_DIR}/prepare_local_docker.sh ${TMP_BUILD_DIR}/

    echo "Prepare local Nginx test configuration"
    cp ${SCRIPTS_DIR}/nginx.conf ${TMP_BUILD_DIR}/
    perl -i -pe "s|APP_NAME_LOWERCASE_placeholder|${APP_NAME_LOWERCASE}|g" "${TMP_BUILD_DIR}/nginx.conf"

    if [[ "${APP_DIR}" != "." && -d ${APP_DIR} ]]; then
      echo "Copy APP_DIR '${APP_DIR}' code files"
      cp -r ${APP_DIR}/* ${TMP_BUILD_DIR}/${APP_DIR}/
    fi
    if [ -d lib ]; then
      echo "Copy 'lib' code files"
      cp -r lib/* ${TMP_BUILD_DIR}/lib/
    fi
    if [ -d genericsuite ]; then
      echo "Copy 'genericsuite' code files"
      cp -r genericsuite/* ${TMP_BUILD_DIR}/genericsuite/
    fi
    if [ -d genericsuite_ai ]; then
      echo "Copy 'genericsuite_ai' code files"
      cp -r genericsuite_ai/* ${TMP_BUILD_DIR}/genericsuite_ai/
    fi
    if [ -d chalicelib ]; then
      echo "Copy 'chalicelib' code files"
      cp -r chalicelib/* ${TMP_BUILD_DIR}/chalicelib/
    fi
    if [ -d fastapilib ]; then
      echo "Copy 'fastapilib' code files"
      cp -r fastapilib/* ${TMP_BUILD_DIR}/fastapilib/
    fi
    if [ -d flasklib ]; then
      echo "Copy 'flasklib' code files"
      cp -r flasklib/* ${TMP_BUILD_DIR}/flasklib/
    fi
    echo ""
    echo "Copy code files finished."

    echo ""
    echo "__pycache__ cleanup started..."
    echo ""
    echo "'${TMP_BUILD_DIR}/lib' __pycache__ cleanup"
    find ${TMP_BUILD_DIR}/lib/ -name "__pycache__" -type d -exec rm -rf {} \;
    if [ -d genericsuite ]; then
      echo "'${TMP_BUILD_DIR}/genericsuite' __pycache__ cleanup"
      find ${TMP_BUILD_DIR}/genericsuite/ -name "__pycache__" -type d -exec rm -rf {} \;
    fi
    if [ -d genericsuite_ai ]; then
      echo "'${TMP_BUILD_DIR}/genericsuite_ai' __pycache__ cleanup"
      find ${TMP_BUILD_DIR}/genericsuite_ai/ -name "__pycache__" -type d -exec rm -rf {} \;
    fi
    if [ -d chalicelib ]; then
      echo "'${TMP_BUILD_DIR}/chalicelib' __pycache__ cleanup"
      find ${TMP_BUILD_DIR}/chalicelib/ -name "__pycache__" -type d -exec rm -rf {} \;
    fi
    if [ -d fastapilib ]; then
      echo "'${TMP_BUILD_DIR}/fastapilib' __pycache__ cleanup"
      find ${TMP_BUILD_DIR}/fastapilib/ -name "__pycache__" -type d -exec rm -rf {} \;
    fi
    if [ -d flasklib ]; then
      echo "'${TMP_BUILD_DIR}/flasklib' __pycache__ cleanup"
      find ${TMP_BUILD_DIR}/flasklib/ -name "__pycache__" -type d -exec rm -rf {} \;
    fi
    echo ""
    echo "__pycache__ cleanup finished."
    
    # Handle chalicelib directory removal
    # for python_file in $(find ${TMP_BUILD_DIR}/ -type f); do
    #     perl -i -pe "s|from chalicelib.|from |g" ${python_file}
    # done

    if [ "${DEBUG}" = "1" ];then
        ls -lahR ${TMP_BUILD_DIR}/*
    fi

    echo ""
    echo "Prepare temporary build directory finished."
}

get_ssl_cert_arn() {
    echo ""
    echo "NOTE: These 3 warnings '-i used with no filenames on the command line, reading from STDIN.' are normal..."
    domain_cleaned=$(echo $domain | perl -i -pe 's|https:\/\/||' | perl -i -pe 's|http:\/\/||' | perl -i -pe 's|:.*||')

    echo ""
    echo "Fetching ACM Certificate ARN for '${domain_cleaned}'..."
    echo "(Originally: '${domain})"
    # ACM_CERTIFICATE_ARN=$(aws acm list-certificates --region ${AWS_REGION} --output text --query "CertificateSummaryList[?DomainName=='${APP_FE_URL}'].CertificateArn | [0]")
    ACM_CERTIFICATE_ARN=$(aws acm list-certificates --output text --query "CertificateSummaryList[?DomainName=='${domain_cleaned}'].CertificateArn | [0]")

    echo ""
    echo "[${domain_cleaned}] ACM Certificate ARN: ${ACM_CERTIFICATE_ARN}"

    if [[ "${ACM_CERTIFICATE_ARN}" = "" || "${ACM_CERTIFICATE_ARN}" = "None" || "${ACM_CERTIFICATE_ARN}" = "null" || "${ACM_CERTIFICATE_ARN}" = "NULL" || "${ACM_CERTIFICATE_ARN}" = "Null" ]]; then
        ACM_CERTIFICATE_ARN=""
        echo "ERROR: ACM Certificate ARN not found for '${domain_cleaned}'"
    fi
}

create_sam_yaml() {
  # https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-function.html

  echo ""
  echo "CREATING sam yaml file (template.yml) | create_sam_yaml()"
  echo ""

  # Prepare domain name
  if [ "${APP_DOMAIN_NAME}" = "" ];then
    APP_DOMAIN_NAME="${APP_NAME_LOWERCASE}.com"
  fi

  DOMAIN_NAME=""
  if [ "${STAGE}" = "prod" ];then
    DOMAIN_NAME="api.${APP_DOMAIN_NAME}"
  else
    if [ "${STAGE}" = "qa" ];then
      DOMAIN_NAME="api-qa.${APP_DOMAIN_NAME}"
    else
      if [ "${STAGE}" = "staging" ];then
        DOMAIN_NAME="api-staging.${APP_DOMAIN_NAME}"
      else
        if [ "${STAGE}" = "demo" ];then
          DOMAIN_NAME="api-demo.${APP_DOMAIN_NAME}"
        fi
      fi
    fi
  fi

  # Prepare samconfig.toml
  cd ${SCRIPTS_DIR}
  if [ ! -f template-sam.yml ];then
    cd convert_json_to_yaml
    sh run_convert_json_to_yaml.sh
    cd ..
  else
    if [ -f "${REPO_BASEDIR}/scripts/aws_big_lambda/template-sam.yml" ]; then
      cp "${REPO_BASEDIR}/scripts/aws_big_lambda/template-sam.yml" template.yml
    else
      cp template-sam.yml template.yml
    fi
  fi

  if [ -f "${REPO_BASEDIR}/scripts/aws/update_additional_envvars.sh" ]; then
      . "${REPO_BASEDIR}/scripts/aws/update_additional_envvars.sh" "./template.yml" "${REPO_BASEDIR}"
  fi

  # Replace @ with \@
  recover_at_sign

  perl -i -pe "s|Runtime: python3.9|#|g" "./template.yml"
  perl -i -pe "s|Runtime: python|#|g" "./template.yml"
  perl -i -pe "s|CodeUri: ./deployment.zip|ImageUri: ${AWS_DOCKER_IMAGE_URI}|g" "./template.yml"
  perl -i -pe "s|Handler: app.app|PackageType: Image|g" "./template.yml"

  if [ "${DOMAIN_NAME}" = "" ];then
    perl -i -pe "s|Domain:|# Domain:|g" "./template.yml"
    perl -i -pe "s|DomainName: api.example.com|# DomainName: api.example.com|g" "./template.yml"
    perl -i -pe "s|CertificateArn: CertificateArn_placeholder|# CertificateArn: CertificateArn_placeholder|g" "./template.yml"
  else
    domain="${DOMAIN_NAME}"
    get_ssl_cert_arn
    if [ "${ACM_CERTIFICATE_ARN}" = "" ]; then
      echo ""
      echo ">>> WARNING: ACM Certificate ARN not found for '${domain}'"
      echo ">>> AWS_SSL_CERTIFICATE_ARN will be used (${AWS_SSL_CERTIFICATE_ARN})" 
      echo ""
      ACM_CERTIFICATE_ARN="${AWS_SSL_CERTIFICATE_ARN}"
    else
      echo ""
      echo "ACM Certificate ARN were found for '${domain}'"
      echo "ACM_CERTIFICATE_ARN: ${ACM_CERTIFICATE_ARN}" 
      echo ""
    fi
    perl -i -pe "s|DomainName: api.example.com|DomainName: ${DOMAIN_NAME}|g" "./template.yml"
    perl -i -pe "s|CertificateArn: CertificateArn_placeholder|CertificateArn: ${ACM_CERTIFICATE_ARN}|g" "./template.yml"
  fi        
  perl -i -pe "s|StageName: api|StageName: ${STAGE}|g" "./template.yml"

  perl -i -pe "s|APP_NAME:.*|APP_NAME: ${APP_NAME}|g" "./template.yml"
  perl -i -pe "s|APP_NAME_LOWERCASE_placeholder|${APP_NAME_LOWERCASE}|g" "./template.yml"
  perl -i -pe "s|APP_NAME_placeholder|${APP_NAME}|g" "./template.yml"

  perl -i -pe "s|CURRENT_FRAMEWORK_placeholder|${CURRENT_FRAMEWORK}|g" "./template.yml"
  perl -i -pe "s|DEFAULT_LANG_placeholder|${DEFAULT_LANG}|g" "./template.yml"

  perl -i -pe "s|AI_ASSISTANT_NAME:.*|AI_ASSISTANT_NAME: ${AI_ASSISTANT_NAME}|g" "./template.yml"
  perl -i -pe "s|APP_VERSION:.*|APP_VERSION: ${APP_VERSION}|g" "./template.yml"
  perl -i -pe "s|APP_DEBUG:.*|APP_DEBUG: ${APP_DEBUG}|g" "./template.yml"

  perl -i -pe "s|APP_STAGE:.*|APP_STAGE: ${STAGE}|g" "./template.yml"
  perl -i -pe "s|APP_STAGE_placeholder|${STAGE}|g" "./template.yml"

  perl -i -pe "s|FLASK_APP:.*|FLASK_APP: ${FLASK_APP}|g" "./template.yml"
  perl -i -pe "s|APP_SECRET_KEY:.*|APP_SECRET_KEY: ${APP_SECRET_KEY}|g" "./template.yml"
  perl -i -pe "s|APP_SUPERADMIN_EMAIL:.*|APP_SUPERADMIN_EMAIL: ${APP_SUPERADMIN_EMAIL}|g" "./template.yml"

  perl -i -pe "s|APP_CORS_ORIGIN:.*|APP_CORS_ORIGIN: ${APP_CORS_ORIGIN}|g" "./template.yml"
  perl -i -pe "s|APP_CORS_ORIGIN_placeholder|${APP_CORS_ORIGIN}|g" "./template.yml"
  perl -i -pe "s|http:\/\/localhost:3000|${APP_CORS_ORIGIN}|g" "./template.yml"
  perl -i -pe "s|APP_FRONTEND_AUDIENCE:.*|APP_FRONTEND_AUDIENCE: ${APP_FRONTEND_AUDIENCE}|g" "./template.yml"

  perl -i -pe "s|APP_DB_ENGINE:.*|APP_DB_ENGINE: ${APP_DB_ENGINE}|g" "./template.yml"
  perl -i -pe "s|APP_DB_NAME:.*|APP_DB_NAME: ${APP_DB_NAME}|g" "./template.yml"
  perl -i -pe "s|APP_DB_URI:.*|APP_DB_URI: ${APP_DB_URI}|g" "./template.yml"

  perl -i -pe "s|GIT_SUBMODULE_URL:.*|GIT_SUBMODULE_URL: ${GIT_SUBMODULE_URL}|g" "./template.yml"
  perl -i -pe "s|GIT_SUBMODULE_LOCAL_PATH:.*|GIT_SUBMODULE_LOCAL_PATH: ${GIT_SUBMODULE_LOCAL_PATH}|g" "./template.yml"

  perl -i -pe "s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET:.*|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET: ${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET}|g" "./template.yml"
  perl -i -pe "s|AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_placeholder|${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET}|g" "./template.yml"

  perl -i -pe "s|SMTP_SERVER:.*|SMTP_SERVER: ${SMTP_SERVER}|g" "./template.yml"
  perl -i -pe "s|SMTP_USER:.*|SMTP_USER: ${SMTP_USER}|g" "./template.yml"
  perl -i -pe "s|SMTP_PORT:.*|SMTP_PORT: ${SMTP_PORT}|g" "./template.yml"
  perl -i -pe "s|SMTP_PASSWORD:.*|SMTP_PASSWORD: ${SMTP_PASSWORD}|g" "./template.yml"
  perl -i -pe "s|SMTP_DEFAULT_SENDER:.*|SMTP_DEFAULT_SENDER: ${SMTP_DEFAULT_SENDER}|g" "./template.yml"

  perl -i -pe "s|OPENAI_TEMPERATURE:.*|OPENAI_TEMPERATURE: ${OPENAI_TEMPERATURE}|g" "./template.yml"
  perl -i -pe "s|OPENAI_API_KEY:.*|OPENAI_API_KEY: ${OPENAI_API_KEY}|g" "./template.yml"
  perl -i -pe "s|OPENAI_MODEL:.*|OPENAI_MODEL: ${OPENAI_MODEL}|g" "./template.yml"

  perl -i -pe"s|GOOGLE_API_KEY:.*|GOOGLE_API_KEY: ${GOOGLE_API_KEY}|g" "./template.yml"
  perl -i -pe"s|GOOGLE_CSE_ID:.*|GOOGLE_CSE_ID: ${GOOGLE_CSE_ID}|g" "./template.yml"

  perl -i -pe"s|LANGCHAIN_API_KEY:.*|LANGCHAIN_API_KEY: ${LANGCHAIN_API_KEY}|g" "./template.yml"
  perl -i -pe"s|LANGCHAIN_PROJECT:.*|LANGCHAIN_PROJECT: ${LANGCHAIN_PROJECT}|g" "./template.yml"

  perl -i -pe"s|HUGGINGFACE_API_KEY:.*|HUGGINGFACE_API_KEY: ${HUGGINGFACE_API_KEY}|g" "./template.yml"
  perl -i -pe"s|HUGGINGFACE_ENDPOINT_URL:.*|HUGGINGFACE_ENDPOINT_URL: ${HUGGINGFACE_ENDPOINT_URL}|g" "./template.yml"

  perl -i -pe "s|http:\/\/localhost:3000|${APP_CORS_ORIGIN}|g" "./template.yml"
  perl -i -pe "s|stage=dev|stage=${STAGE}|g" "./template.yml"

  # Prepare samconfig.toml
  if [ -f "${REPO_BASEDIR}/scripts/aws_big_lambda/template-samconfig.toml" ]; then
    cp "${REPO_BASEDIR}/scripts/aws_big_lambda/template-samconfig.toml" "./samconfig.toml"
  else
    cp template-samconfig.toml samconfig.toml
  fi
  perl -i -pe "s|APP_NAME_LOWERCASE_placeholder|${APP_NAME_LOWERCASE}|g" "./samconfig.toml"
  perl -i -pe "s|APP_NAME_placeholder|${APP_NAME}|g" "./samconfig.toml"
}

build_docker() {
    if [[ Pipfile -nt requirements.txt ]]; then
      make requirements
    fi

    docker_system_prune

    echo "Building Docker image..."
    echo prepare_tmp_build_dir
    prepare_tmp_build_dir

    echo ""
    echo cd ${TMP_BUILD_DIR}
    cd ${TMP_BUILD_DIR}

    echo ""
    echo docker-compose -f docker-compose-big-lambda-${TARGET_OS}.yml down
    docker-compose -f docker-compose-big-lambda-${TARGET_OS}.yml down

    echo ""
    echo "Removing unnecessary files..."
    rm app.${APP_NAME_LOWERCASE}.local.key
    rm app.${APP_NAME_LOWERCASE}.local.crt
    rm app.${APP_NAME_LOWERCASE}.local.chain.crt
    rm ca.crt
    rm deployment.zip
    rm template.yml
    rm samconfig.toml
    rm run_api_gateway.sh
    rm docker-compose-big-lambda-${TARGET_OS}.yml
    rm entry-${TARGET_OS}.sh
    rm prepare_local_docker.sh
    rm nginx.conf

    # Build and test

    echo ""
    if ! docker kill ${LOCAL_LAMBDA_DOCKER_NAME}
    then
      echo ">> R: ${LOCAL_LAMBDA_DOCKER_NAME} container is not running..."
    fi
    if ! docker rm ${LOCAL_LAMBDA_DOCKER_NAME}
    then
      echo ">> R: ${LOCAL_LAMBDA_DOCKER_NAME} container doesn't exist..."
    fi

    set -e

    echo ""
    echo cd ${TMP_BUILD_DIR}
    cd ${TMP_BUILD_DIR}
    pwd

    echo ""
    echo docker buildx build --platform linux/amd64 -t docker-image:${DOCKER_IMAGE_NAME} . 
    docker buildx build --platform linux/amd64 -t docker-image:${DOCKER_IMAGE_NAME} . 

    echo ""
    echo docker run -d --platform linux/amd64 --name ${LOCAL_LAMBDA_DOCKER_NAME} -p 9000:8080 ${ENV_VARIABLES_DOCKER_RUN} docker-image:${DOCKER_IMAGE_NAME}
    docker run -d --platform linux/amd64 --name ${LOCAL_LAMBDA_DOCKER_NAME} -p 9000:8080 ${ENV_VARIABLES_DOCKER_RUN} docker-image:${DOCKER_IMAGE_NAME}

    echo ""
    echo "Wait for the container to finish bootstrap..."
    sleep 5

    echo ""
    echo test_lambda_docker
    test_lambda_docker

    echo ""
    echo cd ${TMP_BUILD_DIR}
    cd ${TMP_BUILD_DIR}
    pwd

    echo ""
    echo docker kill ${LOCAL_LAMBDA_DOCKER_NAME}
    docker kill ${LOCAL_LAMBDA_DOCKER_NAME}

    echo ""
    echo docker rm ${LOCAL_LAMBDA_DOCKER_NAME}
    docker rm ${LOCAL_LAMBDA_DOCKER_NAME}

    # Deploy ECR image

    echo ""
    echo "Deploy ECR image - BEGIN"
    echo ""
    if [ "${FORCE_ECR_IMAGE_CREATION}" = "1" ]; then
      echo ""
      echo "Login ECR"
      echo ""
      echo "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_DOCKER_IMAGE_URI_BASE}"
      aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_DOCKER_IMAGE_URI_BASE}
      
      echo ""
      echo "Create repository"
      echo ""
      echo "aws ecr create-repository --repository-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} --region ${AWS_REGION} --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE"
      if ! ERROR_MSG=$(aws ecr create-repository --repository-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} --region ${AWS_REGION} --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE)
      then
        if [[ $ERROR_MSG == *"RepositoryAlreadyExistsException"* ]]; then
          echo ""
          echo "ECR repo already exists..."
          echo ""
        else
          if [[ $ERROR_MSG == *"Exception"* ]]; then
            echo ""
            echo "ERROR creating the ECR repo..."
            exit_abort
          fi
        fi
      fi
      echo ""
      echo "Tag docker image"
      echo ""
      echo "docker tag docker-image:${DOCKER_IMAGE_NAME} ${AWS_DOCKER_IMAGE_URI}"
      docker tag docker-image:${DOCKER_IMAGE_NAME} ${AWS_DOCKER_IMAGE_URI}
      
      echo ""
      echo "Docker push"
      echo ""
      echo docker push ${AWS_DOCKER_IMAGE_URI}
      docker push ${AWS_DOCKER_IMAGE_URI}
    fi
    echo ""
    echo "Deploy ECR image - END"
    echo ""
}

deploy_with_sam() {
  cd ${SCRIPTS_DIR}

  echo ""
  echo "DEPLOY_WITH_SAM - Begin"
  echo ""
  echo "Current directory:"
  pwd
  echo ""
  if [ "${SAM_GUIDED}" = "y" ]; then
    # Guided SAM deployment
    echo "sam deploy --guided"
    sam deploy --guided
  else
    # Automatic SAM deployment (no prompts after the final confirmation)
    echo sam deploy --template-file template.yml --stack-name ${AWS_STACK_NAME} --region ${AWS_REGION} --config-file samconfig.toml --capabilities CAPABILITY_IAM --no-confirm-changeset --no-disable-rollback ${SAM_FORCED} --save-params --resolve-image-repos
    sam deploy --template-file template.yml --stack-name ${AWS_STACK_NAME} --region ${AWS_REGION} --config-file samconfig.toml --capabilities CAPABILITY_IAM --no-confirm-changeset --no-disable-rollback ${SAM_FORCED} --save-params --resolve-image-repos
    # Remove with perl the entire line beginning with "template_file = ..." from "samconfig.toml" file
    # Because it refers to a local path with some PII, like the username eventually.
    perl -i -pe "s|template_file = .*\n$||g" samconfig.toml
  fi
  echo ""
  echo "DEPLOY_WITH_SAM - End"
  echo ""
  echo "Current directory:"
  pwd
  echo ""
}

deploy_without_sam() {

    # Deploy Lambda Function

    if [  "${FORCE_LAMBDA_CREATION}" = "1" ]; then
      echo ""
      echo "aws lambda delete-function --function-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}"
      aws lambda delete-function --function-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}
    fi
    echo ""
    if ! aws lambda get-function-configuration --function-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} --output json > ${SCRIPTS_DIR}/${JSON_CONFIG_FILE}
    then
      echo aws lambda create-function \
        --function-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} \
        --region ${AWS_REGION} \
        --package-type Image \
        --code ImageUri=${AWS_DOCKER_IMAGE_URI} \
        --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/${AWS_LAMBDA_FUNCTION_ROLE} \
        --environment Variables="${ENV_VARIABLES}" \
        --memory-size ${MEMORY_SIZE:-512}

      aws lambda create-function \
        --function-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} \
        --region ${AWS_REGION} \
        --package-type Image \
        --code ImageUri=${AWS_DOCKER_IMAGE_URI} \
        --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/${AWS_LAMBDA_FUNCTION_ROLE} \
        --environment Variables="${ENV_VARIABLES}" \
        --memory-size ${MEMORY_SIZE:-512} \
        | jq
        # --architectures ${ARCHITECTURES:-arm64}
    else
      echo aws lambda update-function-code \
        --function-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} \
        --image-uri ${AWS_DOCKER_IMAGE_URI} \
        --region ${AWS_REGION}

      aws lambda update-function-code \
        --function-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} \
        --image-uri ${AWS_DOCKER_IMAGE_URI} \
        --region ${AWS_REGION} | jq
    fi
    echo ""

    API_ID=`aws apigateway get-rest-apis | jq -r ".items[] | select(.name == \"${AWS_API_GATEWAY_NAME}\").id"`

    if [ "${API_ID}" = "" ];then
      # Create the API Gateway
      echo "API Gateway doesn''t exist: ${AWS_API_GATEWAY_NAME}"
      exit_abort
    fi

    echo ""
    echo "Adding trigger from the AWS API Gateway to the Lambda function..."

    echo ""
    echo "Trigger: Check if the root resource '/' has ANY method with the correct integration"
    ROOT_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id ${API_ID} | jq -r '.items[] | select(.path == "/") | .id')
    ROOT_RESOURCE_ANY_METHOD=$(aws apigateway get-resource --rest-api-id ${API_ID} --resource-id ${ROOT_RESOURCE_ID} | jq -r '.resourceMethods.ANY')
    if [ -z "${ROOT_RESOURCE_ANY_METHOD}" ]; then
      echo "Creating ANY method integration for the root resource..."
      echo ""

      aws apigateway delete-method \
        --rest-api-id ${API_ID} \
        --resource-id ${ROOT_RESOURCE_ID} \
        --http-method ANY | jq

      echo aws apigateway put-method \
        --rest-api-id ${API_ID} \
        --resource-id ${ROOT_RESOURCE_ID} \
        --http-method ANY \
        --authorization-type NONE \
        --no-api-key-required

      if ! aws apigateway put-method \
        --rest-api-id ${API_ID} \
        --resource-id ${ROOT_RESOURCE_ID} \
        --http-method ANY \
        --authorization-type NONE \
        --no-api-key-required \
        | jq
      then
        echo ""
        echo ">>--> WARNING: ANY method exist in the API Gateway..."
      fi
    else
      echo "The root resource '/' already has an ANY method with the correct integration."
      echo "Response:"
      echo ${ROOT_RESOURCE_ANY_METHOD}
      echo ""
    fi

    echo ""
    echo "Trigger: Put the ANY integration"
    echo ""
    echo aws apigateway put-integration ...

    if ! aws apigateway put-integration \
      --region ${AWS_REGION} \
      --type AWS \
      --http-method ANY \
      --integration-http-method POST \
      --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}/invocations \
      --rest-api-id ${API_ID} \
      --resource-id ${ROOT_RESOURCE_ID} \
      --request-templates "application/json"="'{\"statusCode\":200}'" \
      --passthrough-behavior WHEN_NO_MATCH \
      --content-handling CONVERT_TO_TEXT \
      --cache-namespace "${AWS_API_GATEWAY_NAME}" \
      | jq
    then
      echo ""
      echo ">>--> ERROR: Integration between Lambda and API Gateway could not be created..."
      exit_abort
    fi

    echo ""
    echo "Trigger: Add Permission"
    echo ""
    echo aws lambda add-permission \
      --function-name arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} \
      --statement-id apigateway-test-$(date +%s) \
      --action lambda:InvokeFunction \
      --principal apigateway.amazonaws.com \
      --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*/${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}"
    aws lambda add-permission \
      --function-name arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} \
      --statement-id lambda-apigateway-permission-$(date +%s) \
      --action lambda:InvokeFunction \
      --principal apigateway.amazonaws.com \
      --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*/${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}" \
      | jq

    echo ""
    echo "Trigger added successfully."

    # List API Gateway resources
    echo ""
    echo "List API Gateway resources - BEGIN"
    aws apigateway get-resources --rest-api-id ${API_ID} | jq
    echo ""
    echo "List API Gateway resources - END"
    echo ""

    # ROOT_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id ${API_ID} | jq -r '.items[] | select(.parentId == null) | .id')
    for resource_id in $(aws apigateway get-resources --rest-api-id ${API_ID} | jq -r '.items[]| select(.resourceMethods != null) | .id'); do
      if [ "${resource_id}" = "${ROOT_RESOURCE_ID}" ];then
        echo ""
        echo "'${resource_id}' skipped because it's the root Parent Id..."
        echo ""
      else
        for resource_method in $(aws apigateway get-resource --rest-api-id ${API_ID} --resource-id ${resource_id} | jq -r '.resourceMethods | keys[]'); do
          echo ""
          echo aws apigateway put-integration \
            --rest-api-id ${API_ID} \
            --resource-id ${resource_id} \
            --http-method ${resource_method} \
            --type AWS_PROXY \
            --integration-http-method ${resource_method} \
            --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}/invocations

          aws apigateway put-integration \
            --rest-api-id ${API_ID} \
            --resource-id ${resource_id} \
            --http-method ${resource_method} \
            --type AWS_PROXY \
            --integration-http-method ${resource_method} \
            --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}/invocations | jq
        done
      fi
    done

    # Test Lambda Function

    create_test_payload_json_files
    # perl -i -pe "s|\\n||g" ${TMP_BUILD_DIR}/test_payload.json

    echo ""
    echo aws lambda invoke --function-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} response.json
    aws lambda invoke --function-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} response.json | jq

    echo ""
    echo "1) cat response.json"
    cat response.json

    echo ""
    echo "aws lambda invoke \
      --function-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} \
      --payload file://${TMP_BUILD_DIR}/test_payload_10.json \
      response.json"
    aws lambda invoke \
      --function-name ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE} \
      --payload file://${TMP_BUILD_DIR}/test_payload_10.json \
      response.json

    echo ""
    echo "2) cat response.json"
    cat response.json

    echo ""
    echo rm response.json
    rm response.json

    echo ""
    echo "Deployment done!"
    echo ""
}

run_local_api_gateway() {
    echo ""
    echo "To go to the temporary directory:"
    echo "cd" `pwd`
    echo ""
    echo "To return to the development directory:"
    echo "cd" ${REPO_BASEDIR}
    echo ""

    cd ${TMP_BUILD_DIR}

    # python -m venv venv
    # . venv/bin/activate
    # pip install -r requirements.txt

    sh ./run_api_gateway.sh
}

create_test_payload_json_files() {

  echo ""
  echo "CREATE_TEST_PAYLOAD_JSON_FILES started..."

    # Payload format version
    # https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html#http-api-develop-integrations-lambda.proxy-format

    cat > "${TMP_BUILD_DIR}/test_payload_10.json" <<END
{
  "version": "1.0",
  "resource": "/users/login",
  "path": "/users/login",
  "httpMethod": "GET",
  "headers": {
    "header1": "value1",
    "header2": "value2"
  },
  "multiValueHeaders": {
    "header1": [
      "value1"
    ],
    "header2": [
      "value1",
      "value2"
    ]
  },
  "queryStringParameters": {
    "parameter1": "value1",
    "parameter2": "value"
  },
  "multiValueQueryStringParameters": {
    "parameter1": [
      "value1",
      "value2"
    ],
    "parameter2": [
      "value"
    ]
  },
  "requestContext": {
    "accountId": "${AWS_ACCOUNT_ID}",
    "apiId": "${API_ID}",
    "authorizer": {
      "claims": null,
      "scopes": null
    },
    "domainName": "id.execute-api.us-east-1.amazonaws.com",
    "domainPrefix": "id",
    "extendedRequestId": "request-id",
    "httpMethod": "GET",
    "identity": {
      "accessKey": null,
      "accountId": null,
      "caller": null,
      "cognitoAuthenticationProvider": null,
      "cognitoAuthenticationType": null,
      "cognitoIdentityId": null,
      "cognitoIdentityPoolId": null,
      "principalOrgId": null,
      "sourceIp": "192.0.2.1",
      "user": null,
      "userAgent": "user-agent",
      "userArn": null,
      "clientCert": {
        "clientCertPem": "CERT_CONTENT",
        "subjectDN": "www.example.com",
        "issuerDN": "Example issuer",
        "serialNumber": "a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1",
        "validity": {
          "notBefore": "May 28 12:30:02 2019 GMT",
          "notAfter": "Aug  5 09:36:04 2021 GMT"
        }
      }
    },
    "path": "/users/login",
    "protocol": "HTTP/1.1",
    "requestId": "id=",
    "requestTime": "04/Mar/2020:19:15:17 +0000",
    "requestTimeEpoch": 1583349317135,
    "resourceId": null,
    "resourcePath": "/users/login",
    "stage": "\$default"
  },
  "pathParameters": null,
  "stageVariables": null,
  "body": "Hello from Lambda!",
  "isBase64Encoded": false
}
END

    cat > "${TMP_BUILD_DIR}/test_payload_20.json" <<END
 {
  "version": "2.0",
  "routeKey": "\$default",
  "rawPath": "/users/login",
  "rawQueryString": "parameter1=value1&parameter1=value2&parameter2=value",
  "cookies": [
    "cookie1",
    "cookie2"
  ],
  "headers": {
    "header1": "value1",
    "header2": "value1,value2"
  },
  "queryStringParameters": {
    "parameter1": "value1,value2",
    "parameter2": "value"
  },
  "requestContext": {
    "accountId": "${AWS_ACCOUNT_ID}",
    "apiId": "${API_ID}",
    "authentication": {
      "clientCert": {
        "clientCertPem": "CERT_CONTENT",
        "subjectDN": "www.example.com",
        "issuerDN": "Example issuer",
        "serialNumber": "a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1",
        "validity": {
          "notBefore": "May 28 12:30:02 2019 GMT",
          "notAfter": "Aug  5 09:36:04 2021 GMT"
        }
      }
    },
    "authorizer": {
      "jwt": {
        "claims": {
          "claim1": "value1",
          "claim2": "value2"
        },
        "scopes": [
          "scope1",
          "scope2"
        ]
      }
    },
    "domainName": "id.execute-api.us-east-1.amazonaws.com",
    "domainPrefix": "id",
    "http": {
      "method": "POST",
      "path": "/users/login",
      "protocol": "HTTP/1.1",
      "sourceIp": "192.0.2.1",
      "userAgent": "agent"
    },
    "requestId": "id",
    "routeKey": "\$default",
    "stage": "\$default",
    "time": "12/Mar/2020:19:03:58 +0000",
    "timeEpoch": 1583348638390
  },
  "body": "Hello from Lambda: ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}",
  "pathParameters": {
    "parameter1": "value1"
  },
  "isBase64Encoded": false,
  "stageVariables": {
    "stageVariable1": "value1",
    "stageVariable2": "value2"
  }
}
END

  echo ""
  echo "CREATE_TEST_PAYLOAD_JSON_FILES var assigning..."

  # TEST_PAYLOAD_10=$(cat "${TMP_BUILD_DIR}/test_payload_1.0.txt")
  # TEST_PAYLOAD_20=$(cat "${TMP_BUILD_DIR}/test_payload_2.0.txt")

  echo ""
  echo "CREATE_TEST_PAYLOAD_JSON_FILES ended."
}

test_api_gateway() {
    echo ""
    echo "Test API Gateway:" curl -XPOST "http://127.0.0.1:${API_GATEWAY_PORT}/users/login"
    echo ""
    curl -XPOST "http://127.0.0.1:${API_GATEWAY_PORT}/users/login"
}

test_lambda_docker() {
    echo ""
    echo "Test Lambda Docker:" curl -XPOST "http://127.0.0.1:${LAMBDA_PORT}/2015-03-31/functions/function/invocations" -d '{\"version\": \"1.0\"...}'
    echo ""
    curl -XPOST "http://127.0.0.1:${LAMBDA_PORT}/2015-03-31/functions/function/invocations" -d \
    {'
  "version": "1.0",
  "resource": "/users/login",
  "path": "/users/login",
  "httpMethod": "GET",
  "headers": {
    "header1": "value1",
    "header2": "value2"
  },
  "multiValueHeaders": {
    "header1": [
      "value1"
    ],
    "header2": [
      "value1",
      "value2"
    ]
  },
  "queryStringParameters": {
    "parameter1": "value1",
    "parameter2": "value"
  },
  "multiValueQueryStringParameters": {
    "parameter1": [
      "value1",
      "value2"
    ],
    "parameter2": [
      "value"
    ]
  },
  "requestContext": {
    "accountId": "${AWS_ACCOUNT_ID}",
    "apiId": "id",
    "authorizer": {
      "claims": null,
      "scopes": null
    },
    "domainName": "id.execute-api.us-east-1.amazonaws.com",
    "domainPrefix": "id",
    "extendedRequestId": "request-id",
    "httpMethod": "GET",
    "identity": {
      "accessKey": null,
      "accountId": null,
      "caller": null,
      "cognitoAuthenticationProvider": null,
      "cognitoAuthenticationType": null,
      "cognitoIdentityId": null,
      "cognitoIdentityPoolId": null,
      "principalOrgId": null,
      "sourceIp": "192.0.2.1",
      "user": null,
      "userAgent": "user-agent",
      "userArn": null,
      "clientCert": {
        "clientCertPem": "CERT_CONTENT",
        "subjectDN": "www.example.com",
        "issuerDN": "Example issuer",
        "serialNumber": "a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1",
        "validity": {
          "notBefore": "May 28 12:30:02 2019 GMT",
          "notAfter": "Aug  5 09:36:04 2021 GMT"
        }
      }
    },
    "path": "/users/login",
    "protocol": "HTTP/1.1",
    "requestId": "id=",
    "requestTime": "04/Mar/2020:19:15:17 +0000",
    "requestTimeEpoch": 1583349317135,
    "resourceId": null,
    "resourcePath": "/users/login",
    "stage": "$default"
  },
  "pathParameters": null,
  "stageVariables": null,
  "body": "Hello from Lambda!",
  "isBase64Encoded": false
'}
    echo ""
    echo "Test Lambda Docker:" curl -XPOST "http://127.0.0.1:${LAMBDA_PORT}/2015-03-31/functions/function/invocations" -d '{\"version\": \"2.0\"...}'
    echo ""
    curl -XPOST "http://127.0.0.1:${LAMBDA_PORT}/2015-03-31/functions/function/invocations" -d \
    {'
  "version": "2.0",
  "routeKey": "$default",
  "rawPath": "/users/login",
  "rawQueryString": "parameter1=value1&parameter1=value2&parameter2=value",
  "cookies": [
    "cookie1",
    "cookie2"
  ],
  "headers": {
    "header1": "value1",
    "header2": "value1,value2"
  },
  "queryStringParameters": {
    "parameter1": "value1,value2",
    "parameter2": "value"
  },
  "requestContext": {
    "accountId": "123456789012",
    "apiId": "api-id",
    "authentication": {
      "clientCert": {
        "clientCertPem": "CERT_CONTENT",
        "subjectDN": "www.example.com",
        "issuerDN": "Example issuer",
        "serialNumber": "a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1:a1",
        "validity": {
          "notBefore": "May 28 12:30:02 2019 GMT",
          "notAfter": "Aug  5 09:36:04 2021 GMT"
        }
      }
    },
    "authorizer": {
      "jwt": {
        "claims": {
          "claim1": "value1",
          "claim2": "value2"
        },
        "scopes": [
          "scope1",
          "scope2"
        ]
      }
    },
    "domainName": "id.execute-api.us-east-1.amazonaws.com",
    "domainPrefix": "id",
    "http": {
      "method": "POST",
      "path": "/users/login",
      "protocol": "HTTP/1.1",
      "sourceIp": "192.0.2.1",
      "userAgent": "agent"
    },
    "requestId": "id",
    "routeKey": "$default",
    "stage": "$default",
    "time": "12/Mar/2020:19:03:58 +0000",
    "timeEpoch": 1583348638390
  },
  "body": "Hello from Lambda ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}",
  "pathParameters": {
    "parameter1": "value1"
  },
  "isBase64Encoded": false,
  "stageVariables": {
    "stageVariable1": "value1",
    "stageVariable2": "value2"
  }
'}
    echo ""
    echo ""
    echo "2.5)" docker logs ${LOCAL_LAMBDA_DOCKER_NAME}
    echo ""
    docker logs ${LOCAL_LAMBDA_DOCKER_NAME}
    echo ""
}

test_nginx() {
    echo "3)" curl -XPOST "https://app.${APP_NAME_LOWERCASE}.local:${NGINX_PORT}/users/login"
    echo ""
    curl -XPOST "https://app.${APP_NAME_LOWERCASE}.local:${NGINX_PORT}/users/login"
    echo ""
    echo "3.5)" docker logs local-lambda-nginx
    echo ""
    docker logs local-lambda-nginx
    echo ""
}

docker_dependencies() {
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
          exit_abort
      else
          sleep 20
      fi
  fi

  if ! docker ps > /dev/null 2>&1;
  then
      echo ""
      echo "Docker is not running"
      exit_abort
  fi

  if ! docker ps | grep dns-server -q
  then
      echo ""
      echo "0)" make local_dns
      echo ""
      make local_dns
  fi
}

# ----------------------------

# Default values before load .env


# Action
ACTION="$1"

# Stage
if [ "$2" = "" ]; then
  STAGE="qa"
else
  STAGE="$2"
fi
STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')

# Frontend directory
FRONTEND_DIRECTORY="$3"

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

LAMBDA_PORT="9000"
API_GATEWAY_PORT="8080"
NGINX_PORT="5001"
LOCAL_LAMBDA_DOCKER_NAME="local-lambda-backend"

FORCE_LAMBDA_CREATION="0"
# FORCE_LAMBDA_CREATION="1"

# DEPLOYMENT_METHOD="deploy_without_sam"
DEPLOYMENT_METHOD="deploy_with_sam"

# TARGET_OS="Alpine"
TARGET_OS="AL2"

# Assumes it's run from the project root directory...
set -o allexport; . .env ; set +o allexport ;

if [ "${CURRENT_FRAMEWORK}" = "" ]; then
    echo "ERROR: CURRENT_FRAMEWORK environment variable not defined"
    exit 1
fi
if [ "${APP_NAME}" = "" ]; then
    echo "ERROR: APP_NAME environment variable not defined"
    exit 1
fi
export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

if [ "${FRONTEND_DIRECTORY}" = "" ]; then
    if [ "${FRONTEND_PATH}" = "" ]; then
        echo "FRONTEND_PATH environment variable is not defined"
        exit 1
    else
        FRONTEND_DIRECTORY="${FRONTEND_PATH}"
    fi
fi

# Default App main code directory
if [ "${APP_DIR}" = "" ]; then
  # https://aws.github.io/chalice/topics/packaging.html
  APP_DIR='.'
  if [ "${CURRENT_FRAMEWORK}" = "fastapi" ]; then
    # https://fastapi.tiangolo.com/tutorial/bigger-applications/?h=directory+structure#an-example-file-structure
    APP_DIR='app'
  fi
  if [ "${CURRENT_FRAMEWORK}" = "flask" ]; then
    # https://flask.palletsprojects.com/en/2.3.x/tutorial/layout/
    APP_DIR='flaskr'
  fi
fi

if [ ! -d "./${APP_DIR}" ]; then
  echo "ERROR: APP_DIR './${APP_DIR}' not found"
  exit 1
fi

# Default App entry point coode file
if [ "${APP_MAIN_FILE}" = "" ]; then
  # https://aws.github.io/chalice/topics/packaging.html
  APP_MAIN_FILE='app'
  if [ "${CURRENT_FRAMEWORK}" = "fastapi" ]; then
    # https://fastapi.tiangolo.com/tutorial/bigger-applications/?h=directory+structure#an-example-file-structure
    APP_MAIN_FILE='main'
  fi
  if [ "${CURRENT_FRAMEWORK}" = "flask" ]; then
    # https://flask.palletsprojects.com/en/2.3.x/tutorial/factory/
    APP_MAIN_FILE='__init__'
  fi
fi

if [ ! -f "${APP_DIR}/${APP_MAIN_FILE}.py" ]; then
  echo "ERROR: APP_DIR/APP_MAIN_FILE '"${APP_DIR}/${APP_MAIN_FILE}".py' not found"
  exit 1
fi

TMP_BUILD_DIR="/tmp/${APP_NAME_LOWERCASE}_backend_aws_tmp"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output json --no-paginate | jq -r '.Account')
AWS_LAMBDA_FUNCTION_NAME_AND_STAGE=$(echo ${AWS_LAMBDA_FUNCTION_NAME}-${STAGE_UPPERCASE} | tr '[:upper:]' '[:lower:]')
# DOCKER_IMAGE_NAME=$(echo ${AWS_LAMBDA_FUNCTION_NAME} | perl -i -pe "s|-||g")
DOCKER_IMAGE_NAME="${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}"
AWS_DOCKER_IMAGE_URI_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
AWS_DOCKER_IMAGE_URI="${AWS_DOCKER_IMAGE_URI_BASE}/${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}:latest"
JSON_CONFIG_FILE="lambda-config-${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}.json"
AWS_API_GATEWAY_NAME="${AWS_LAMBDA_FUNCTION_NAME}-${STAGE}"
AWS_STACK_NAME="${AWS_LAMBDA_FUNCTION_NAME}-${STAGE}"
MEMORY_SIZE="512"
ARCHITECTURES="arm64"

if [ "${AWS_ACCOUNT_ID}" = "" ]; then
  echo "ERROR: missing AWS_ACCOUNT_ID"
  exit_abort
fi

if [ "${AWS_LAMBDA_FUNCTION_NAME}" = "" ]; then
  echo "ERROR: missing AWS_LAMBDA_FUNCTION_NAME"
  exit_abort
fi

if [ "${AWS_LAMBDA_FUNCTION_ROLE}" = "" ]; then
  echo "ERROR: missing AWS_LAMBDA_FUNCTION_ROLE"
  exit_abort
fi

if [ "${AWS_REGION}" = "" ]; then
  echo "ERROR: missing AWS_REGION"
  exit_abort
fi

echo ""
echo "==========================="
echo "=== BIG_LAMBDAS_MANAGER ==="
echo "==========================="
echo ""
echo "1) Action (ACTION): ${ACTION}"
echo "2) Stage (STAGE): ${STAGE}"
echo "3) Frontend Directory (FRONTEND_DIRECTORY): ${FRONTEND_DIRECTORY}"
echo ""
echo "==========================="

echo ""

if [[ "${ACTION}" = "sam_validate" || "${ACTION}" = "package" ]]; then
  COPY_VERSION_TO_FRONTEND="0"
  if [ "${ACTION}" = "package" ]; then
    APP_VERSION="package_test"
    FORCE_ECR_IMAGE_CREATION="0"
  else
    APP_VERSION=$(cat ${REPO_BASEDIR}/version.txt)
    FORCE_ECR_IMAGE_CREATION="1"
  fi
  DOCKER_IMAGE_VERSION="${APP_VERSION}"
  AWS_DOCKER_IMAGE_URI="${AWS_DOCKER_IMAGE_URI_BASE}/${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}:${DOCKER_IMAGE_VERSION}"
  DOCKER_PRUNE="is_not_the_case"
  SAM_GUIDED="n"
  SAM_FORCED="--force-upload"
else
  ask_for_force_ecr_image_creation
  echo ""

  ask_for_app_version
  echo ""

  ask_for_docker_image_version
  echo ""

  verify_docker_image_exist
  if [ "${ERROR_MSG}" != "" ];then
    echo ""
    echo "${ERROR_MSG}"
    exit_abort
  fi

  echo ""
  ask_for_sam_guided_deployment
  echo ""

  if [[ "${ACTION}" = "build_docker" || "${ACTION}" = "sam_deploy" ]]; then
    ask_for_docker_system_prune
    echo ""
  else
    DOCKER_PRUNE="is_not_the_case"
  fi

  echo ""
  ask_for_frontend_version_assignment
fi

echo ""
echo "==================================="
echo "=== BIG LAMBDAS MANAGER SUMMARY ==="
echo "==================================="
echo ""
echo "1) Action (ACTION): ${ACTION}"
echo "2) Stage (STAGE): ${STAGE}"
echo "3) Frontend Directory (FRONTEND_DIRECTORY): ${FRONTEND_DIRECTORY}"
echo ""
echo "App name (APP_NAME): ${APP_NAME}"
echo "App version (APP_VERSION): ${APP_VERSION}"
echo "App framework (CURRENT_FRAMEWORK): ${CURRENT_FRAMEWORK}"
echo "App main directory and code file: (APP_DIR/APP_MAIN_FILE): "${APP_DIR}/${APP_MAIN_FILE}".py"
echo ""
echo "Target operating system (TARGET_OS): ${TARGET_OS}"
echo ""
echo "Local base directorry (REPO_BASEDIR): ${REPO_BASEDIR}"
echo "Script direcrory (SCRIPTS_DIR): ${SCRIPTS_DIR}"
echo "Temporary directory for build ECR image (TMP_BUILD_DIR): ${TMP_BUILD_DIR}"
echo ""
echo "Copy version to the Frontend (COPY_VERSION_TO_FRONTEND): ${COPY_VERSION_TO_FRONTEND}"
echo ""
echo "AWS parameters:"
echo ""
echo "Account ID (AWS_ACCOUNT_ID): ${AWS_ACCOUNT_ID}"
echo "Region (AWS_REGION): ${AWS_REGION}"
echo "Force ECR image creation (FORCE_ECR_IMAGE_CREATION): ${FORCE_ECR_IMAGE_CREATION}"
echo "Image URI (AWS_DOCKER_IMAGE_URI): ${AWS_DOCKER_IMAGE_URI}"
if [ "${DEBUG}" = "1" ];then
  echo "AWS_LAMBDA_FUNCTION_NAME: ${AWS_LAMBDA_FUNCTION_NAME}"
  echo "AWS_LAMBDA_FUNCTION_NAME_AND_STAGE: ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}"
  echo "LAMBDA_PORT: ${LAMBDA_PORT}"
  echo "API_GATEWAY_PORT: ${LAMBDA_PORT}"
  echo "NGINX_PORT: ${NGINX_PORT}"
fi
echo ""
echo "Docker parameters:"
echo ""
echo "Docker image name (DOCKER_IMAGE_NAME): ${DOCKER_IMAGE_NAME}"
echo "Docker system prune (DOCKER_PRUNE): ${DOCKER_PRUNE}"
echo ""
echo "SAM parameters"
echo ""
echo "SAM guided deployment (SAM_GUIDED): ${SAM_GUIDED}"
echo "SAM force upload (SAM_FORCED): ${SAM_FORCED}"

echo ""
echo "==================================="

echo ""
ask_to_continue

echo ""
perform_frontend_version_assignment

docker_dependencies

if [ "${ACTION}" = "down" ]; then
    if [ ! -f "${TMP_BUILD_DIR}/set_env_vars.sh" ];then
        prepare_tmp_build_dir
    fi
    set -o allexport; . "${TMP_BUILD_DIR}/set_env_vars.sh" ; set +o allexport ;
    docker-compose -f ${TMP_BUILD_DIR}/docker-compose-big-lambda-${TARGET_OS}.yml down
    docker ps
fi

if [ "${ACTION}" = "enter" ]; then
    docker exec -ti ${LOCAL_LAMBDA_DOCKER_NAME} sh
fi

if [ "${ACTION}" = "test" ]; then
  test_lambda_docker
  test_nginx
  test_api_gateway
fi

if [ "${ACTION}" = "build_docker" ]; then
  build_docker
fi

if [ "${ACTION}" = "sam_deploy" ]; then
  if [ "${FORCE_ECR_IMAGE_CREATION}" = "1" ]; then
    build_docker
  else
    prepare_tmp_build_dir
  fi
  if [ "${DEPLOYMENT_METHOD}" = "deploy_with_sam" ];then
    deploy_with_sam
  else
    deploy_without_sam
  fi
fi

if [ "${ACTION}" = "tmp_dir" ]; then
    prepare_tmp_build_dir
fi

if [ "${ACTION}" = "rebuild" ]; then
    prepare_tmp_build_dir
    if docker ps | grep ${LOCAL_LAMBDA_DOCKER_NAME} -q
    then
        echo ""
        echo docker-compose -f ${TMP_BUILD_DIR}/docker-compose-big-lambda-${TARGET_OS}.yml down
        docker-compose -f ${TMP_BUILD_DIR}/docker-compose-big-lambda-${TARGET_OS}.yml down
    fi
    echo ""
    echo docker-compose -f ${TMP_BUILD_DIR}/docker-compose-big-lambda-${TARGET_OS}.yml up -d --build
    docker-compose -f ${TMP_BUILD_DIR}/docker-compose-big-lambda-${TARGET_OS}.yml up -d --build
    docker ps
    echo ""
    echo "Rebuild done"
    echo ""
    run_local_api_gateway
fi

if [ "${ACTION}" = "" ]; then
    prepare_tmp_build_dir
    if docker ps | grep ${LOCAL_LAMBDA_DOCKER_NAME} -q
    then
        echo ""
        echo docker restart ${LOCAL_LAMBDA_DOCKER_NAME}
        docker restart ${LOCAL_LAMBDA_DOCKER_NAME}
    else
        echo ""
        echo docker-compose -f ${TMP_BUILD_DIR}/docker-compose-big-lambda-${TARGET_OS}.yml up -d
        docker-compose -f ${TMP_BUILD_DIR}/docker-compose-big-lambda-${TARGET_OS}.yml up -d
    fi
    docker ps
    echo ""
    echo "All is set!"
    echo ""
    run_local_api_gateway
fi

if [ "${ACTION}" = "sam_validate" ]; then
  prepare_tmp_build_dir
  echo sam validate -t ${SCRIPTS_DIR}/template.yml
  sam validate -t ${SCRIPTS_DIR}/template.yml
fi

if [ "${ACTION}" = "package" ]; then
  DOCKER_IMAGE_NAME="${DOCKER_IMAGE_NAME}_${APP_VERSION}"
  echo "Removing docker image docker-image:${DOCKER_IMAGE_NAME}..."
  if docker image inspect docker-image:${DOCKER_IMAGE_NAME} > /dev/null 2>&1; then
    docker rmi docker-image:${DOCKER_IMAGE_NAME}
    echo "Docker image docker-image:${DOCKER_IMAGE_NAME} removed successfully."
  else
    echo "Docker image docker-image:${DOCKER_IMAGE_NAME} does not exist."
  fi

  build_docker
fi
