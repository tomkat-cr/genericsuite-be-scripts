# !/bin/bash
# run-fastapi-ecr-creation.sh
# Origin: init-ecr-creation-from-real-app.sh [GS-96]
# 2024-06-22 | CR
# Usage:
# ECR_IMAGE_TAG="0.0.16" STAGE=qa sh node_modules/genericsuite-be-scripts/scripts/aws_ec2_elb/run-fastapi-ecr-creation.sh
# ECR_IMAGE_TAG="0.0.16" STAGE=qa make deploy_ecr_creation

# ------------------

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

verify_and_remove_file() {
  if [ -f "${remove_file}" ];then
    echo "Removing ${remove_file}..."
    if rm -rf ${remove_file}
    then
      echo "Ok"
    else
      echo "RM Error"
    fi
  fi
}

remove_temp_files() {
  echo ""
  remove_file="${TMP_WORKING_DIR}/template.yml"
  verify_and_remove_file
  remove_file="${TMP_WORKING_DIR}/samconfig.toml"
  verify_and_remove_file
  remove_file="${TMP_BUILD_DIR}/template.yml"
  verify_and_remove_file
  remove_file="${TMP_BUILD_DIR}/samconfig.toml"
  verify_and_remove_file
}

yes_or_no() {
  read choice
  while [[ ! $choice =~ ^[YyNn]$ ]]; do
    echo "Please enter Y or N"
    read choice
  done
}

exit_abort() {
    echo ""
    echo "Aborting..."
    echo ""
    remove_temp_files
    echo ""
    sh ${SCRIPTS_DIR}/../show_date_time.sh
    exit 1
}

ask_to_continue() {
    echo "Continue (Y/n)?"
    yes_or_no
    if [ $choice = "n" ]; then
        exit_abort
    fi
}  

# ------------------

set_app_dir_and_main_file() {
    cd "${REPO_BASEDIR}"

    # Default App main code directory
    if [ "${APP_DIR}" = "" ]; then
        # https://aws.github.io/chalice/topics/packaging.html
        export APP_DIR='.'
        if [ "${CURRENT_FRAMEWORK}" = "fastapi" ]; then
            # https://fastapi.tiangolo.com/tutorial/bigger-applications/?h=directory+structure#an-example-file-structure
            export APP_DIR='app'
        fi
        if [ "${CURRENT_FRAMEWORK}" = "flask" ]; then
            # https://flask.palletsprojects.com/en/2.3.x/tutorial/layout/
            export APP_DIR='flaskr'
        fi
    fi

    if [ ! -d "./${APP_DIR}" ]; then
        echo "ERROR: APP_DIR './${APP_DIR}' not found"
        tput bel
    fi

    # Default App entry point code file
    if [ "${APP_MAIN_FILE}" = "" ]; then
        # https://aws.github.io/chalice/topics/packaging.html
        export APP_MAIN_FILE='app'
        export APP_HANDLER='app'
        if [ "${CURRENT_FRAMEWORK}" = "fastapi" ]; then
            # https://fastapi.tiangolo.com/tutorial/bigger-applications/?h=directory+structure#an-example-file-structure
            # Deploying FastAPI as Lambda Function
            # https://github.com/jordaneremieff/mangum/discussions/221
            export APP_MAIN_FILE='main'
            export APP_HANDLER='handler'
        fi
        if [ "${CURRENT_FRAMEWORK}" = "flask" ]; then
            # https://flask.palletsprojects.com/en/2.3.x/tutorial/factory/
            # How to run Python Flask application in AWS Lambda
            # https://www.cloudtechsimplified.com/run-python-flask-in-aws-lambda/
            export APP_MAIN_FILE=$(echo ${FLASK_APP} | perl -i -pe "s|.py||g")
            export APP_HANDLER='handler'
        fi
    fi

    if [ ! -f "${APP_DIR}/${APP_MAIN_FILE}.py" ]; then
        echo "ERROR: APP_DIR/APP_MAIN_FILE '"${APP_DIR}/${APP_MAIN_FILE}".py' not found"
        tput bel
    fi

    echo "" 
    echo "set_app_dir_and_main_file:"
    echo ""
    echo "   APP_DIR: ${APP_DIR}"
    echo "   APP_MAIN_FILE: ${APP_MAIN_FILE}"
    echo ""
}

recover_at_sign() {
    # Replace @ with \@

    # APP_SUPERADMIN_EMAIL=${APP_SUPERADMIN_EMAIL//@/\\@}
    # APP_SECRET_KEY=${APP_SECRET_KEY//@/\\@}
    # APP_DB_URI_DEV=${APP_DB_URI_DEV//@/\\@}
    # APP_DB_URI_QA=${APP_DB_URI_QA//@/\\@}
    # APP_DB_URI_STAGING=${APP_DB_URI_STAGING//@/\\@}
    # APP_DB_URI_PROD=${APP_DB_URI_PROD//@/\\@}
    # APP_DB_URI_DEMO=${APP_DB_URI_DEMO//@/\\@}
    # APP_DB_URI=${APP_DB_URI//@/\\@}
    SMTP_DEFAULT_SENDER=${SMTP_DEFAULT_SENDER//@/\\@}
    # SMTP_USER=${SMTP_USER//@/\\@}
    # SMTP_PASSWORD=${SMTP_PASSWORD//@/\\@}
    # OPENAI_API_KEY=${OPENAI_API_KEY//@/\\@}
    # LANGCHAIN_API_KEY=${LANGCHAIN_API_KEY//@/\\@}
    # GOOGLE_API_KEY=${GOOGLE_API_KEY//@/\\@}
    # HUGGINGFACE_API_KEY=${HUGGINGFACE_API_KEY//@/\\@}
}

set_env_vars_file() {
    # Prepare env vars and .env file for deployment
    cd "${REPO_BASEDIR}"

    # pwd
    # echo "sh ${SCRIPTS_DIR}/../aws/set_chalice_cnf.sh ${STAGE} deploy"
    # sh ${SCRIPTS_DIR}/../aws/set_chalice_cnf.sh ${STAGE} deploy

    # Reload env vars from .env file
    set -o allexport; . .env ; set +o allexport;

    # Replace @ with \@
    recover_at_sign

    # Set CORS origin
    if [ "${ACTION}" = "sam_run_local" ]; then
        APP_CORS_ORIGIN="http://app.${APP_NAME_LOWERCASE}.local:${FRONTEND_LOCAL_PORT}"
    else
        if [ "${STAGE_UPPERCASE}" = "QA" ]; then
            APP_CORS_ORIGIN="${APP_CORS_ORIGIN_QA_CLOUD}"
        else
            APP_CORS_ORIGIN="$(eval echo \"\$APP_CORS_ORIGIN_${STAGE_UPPERCASE}\")"
        fi
    fi

    if [ "${SKIP_DOTENV_GENERATION}" = "1" ]; then
      echo  "SKIP_DOTENV_GENERATION is set to 1, skipping .env generation"
      return
    fi

    cat > "${TMP_BUILD_DIR}/.env" <<END \

APP_NAME="${APP_NAME}"
APP_STAGE="${STAGE}"
AI_ASSISTANT_NAME="${AI_ASSISTANT_NAME}"
APP_DB_ENGINE=$(eval echo \$APP_DB_ENGINE_${STAGE_UPPERCASE})
APP_DB_NAME=$(eval echo \$APP_DB_NAME_${STAGE_UPPERCASE})
APP_CORS_ORIGIN="${STAGE_UPPERCASE}"
CURRENT_FRAMEWORK="${CURRENT_FRAMEWORK}"
DEFAULT_LANG="${DEFAULT_LANG}"
GIT_SUBMODULE_URL="${GIT_SUBMODULE_URL}"
GIT_SUBMODULE_LOCAL_PATH="${GIT_SUBMODULE_LOCAL_PATH}"
OPENAI_MODEL="${OPENAI_MODEL}"
OPENAI_TEMPERATURE="${OPENAI_TEMPERATURE}"
LANGCHAIN_PROJECT="${LANGCHAIN_PROJECT}"
USER_AGENT="${APP_NAME_LOWERCASE}-${STAGE}"
DYNAMDB_PREFIX="${APP_NAME_LOWERCASE}_${STAGE}_"
HUGGINGFACE_ENDPOINT_URL="${HUGGINGFACE_ENDPOINT_URL}"
SMTP_SERVER="${SMTP_SERVER}"
SMTP_PORT="${SMTP_PORT}"
SMTP_DEFAULT_SENDER="${SMTP_DEFAULT_SENDER}"
FLASK_APP="${FLASK_APP}"
CLOUD_PROVIDER="${CLOUD_PROVIDER}"
AWS_S3_CHATBOT_ATTACHMENTS_BUCKET=$(eval echo \$AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_${STAGE_UPPERCASE})
AWS_REGION="${AWS_REGION}"

END
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

    echo "Creating: ${TMP_BUILD_DIR}"
    mkdir -p ${TMP_BUILD_DIR}

    echo ""
    echo "Prepare environment variables..."
    set_env_vars_file

    echo ""
    echo "Prepare APP_DIR and APP_MAIN_FILE..."
    set_app_dir_and_main_file

    cd "${REPO_BASEDIR}"

    if [[ "${APP_DIR}" != "." && -d ${APP_DIR} ]]; then
      echo "Creating directory: ${TMP_BUILD_DIR}/${APP_DIR}"
      mkdir -p ${TMP_BUILD_DIR}/${APP_DIR}
    fi

    if [ -d lib ]; then
      echo "Creating directory: ${TMP_BUILD_DIR}/lib"
      mkdir -p "${TMP_BUILD_DIR}"/lib
    fi
    if [ -d genericsuite ]; then
      echo "Creating directory: ${TMP_BUILD_DIR}/genericsuite"
      mkdir -p "${TMP_BUILD_DIR}"/genericsuite
    fi
    if [ -d genericsuite_ai ]; then
      echo "Creating directory: ${TMP_BUILD_DIR}/genericsuite_ai"
      mkdir -p "${TMP_BUILD_DIR}"/genericsuite_ai
    fi
    if [ -d chalicelib ]; then
      echo "Creating directory: ${TMP_BUILD_DIR}/chalicelib"
      mkdir -p "${TMP_BUILD_DIR}"/chalicelib
    fi
    if [ -d fastapilib ]; then
      echo "Creating directory: ${TMP_BUILD_DIR}/fastapilib"
      mkdir -p "${TMP_BUILD_DIR}"/fastapilib
    fi
    if [ -d flasklib ]; then
      echo "Creating directory: ${TMP_BUILD_DIR}/flasklib"
      mkdir -p "${TMP_BUILD_DIR}"/flasklib
    fi

    echo ""
    echo "Copy code files started..."

    echo "Copy repo root dir code files"
    if [[ "${CURRENT_FRAMEWORK}" = "chalice" || "${CURRENT_FRAMEWORK}" = "chalice_docker" ]]; then
      # For Chalice framework, copy the initial run application (app.py) to the root build directory
      cp app.py ${TMP_BUILD_DIR}/
    fi

    cp requirements.txt ${TMP_BUILD_DIR}/

    if [[ "${APP_DIR}" != "." && -d ${APP_DIR} ]]; then
      echo "Copy APP_DIR '${APP_DIR}' code files"
      cp -r ${APP_DIR}/* ${TMP_BUILD_DIR}/${APP_DIR}/
      mv ${TMP_BUILD_DIR}/${APP_DIR}/${APP_MAIN_FILE}.py ${TMP_BUILD_DIR}/
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
    # Clean all __pycache__ directories in ${TMP_BUILD_DIR} and all its sub-directories
    find ${TMP_BUILD_DIR} -name "__pycache__" -type d -exec rm -rf {} \;
    echo ""
    echo "__pycache__ cleanup finished."

    if [ "${DEBUG}" = "1" ];then
        echo ""
        echo "Source build directory:"
        echo ""
        ls -lah ${TMP_BUILD_DIR}/*
        echo ""
        ls -lahR ${TMP_BUILD_DIR}/*
        echo ""
    fi

    echo ""
    echo "Prepare temporary build directory finished."
}

copy_docker_file() {
    echo ""
    echo "Copy dockerfile to: ${TMP_BUILD_DIR}"
    echo ""
    if ! cd "${SCRIPTS_DIR}"
    then
        echo "ERROR: could not process cd '${SCRIPTS_DIR}/Dockerfile.template'"
        echo ""
        exit_abort
    fi
    if ! cp "./Dockerfile.template" "${TMP_BUILD_DIR}/Dockerfile"
    then
        echo "ERROR: could not process cp './Dockerfile.template' '${TMP_BUILD_DIR}/Dockerfile'"
        echo ""
        exit_abort
    fi

    # For non-Chalice frameworks, change the initial run command:
    # CMD [ "main:app" ] >> CMD [ "main.handler" ] or [ "index.handler" ]
    if [ "${APP_DIR}" != "." ]; then
      echo "Running: 'perl -i -pe \"s|CMD [ \"main:app\" ]|CMD \[ \"${APP_DIR}.${APP_MAIN_FILE}:app\" \]|g\" ${TMP_BUILD_DIR}/Dockerfile'..."
      echo "" > ${TMP_BUILD_DIR}/__init__.py
      if ! perl -i -pe "s|CMD \[ \"main:app\" \]|CMD \[ \"${APP_MAIN_FILE}.${APP_HANDLER}\" \]|g" ${TMP_BUILD_DIR}/Dockerfile
      then
        echo "ERROR: cannot replace main app entry point on Dockerfile"
        exit_abort
      fi
    fi
}

# ---

verify_requirements_with_local_dependencies() {
    echo ""
    LOCAL_DEPENDENCIES_ERROR=""
    # Verify "Local" dependencies
    if grep -q "-e ..\/genericsuite-be-ai" "${REPO_BASEDIR}/requirements.txt"; then
        echo "Local Genericsuite-BE-AI found in requirements.txt..."
        echo "It was installed with e.g. pipenv install ../genericsuite-be-ai"
        LOCAL_DEPENDENCIES_ERROR="1"
    fi
    if grep -q "-e ..\/genericsuite-be" "${REPO_BASEDIR}/requirements.txt"; then
        echo "Local Genericsuite-BE found in requirements.txt..."
        echo "It was installed with e.g. pipenv install ../genericsuite-be"
        LOCAL_DEPENDENCIES_ERROR="1"
    fi
    # Local dependecies are not allowed because it makes the docker image for deployment creation to fail
    if [ "${LOCAL_DEPENDENCIES_ERROR}" = "1" ]; then
        echo ""
        echo "Please install these dependencies from Pypi or a Git repository."
        echo "If you are using Pipenv, you can install these dependencies with:"
        echo "   pipenv install genericsuite-ai"
        echo "   pipenv install genericsuite"
        echo "   or"
        echo "   pipenv install git+https://github.com/tomkat-cr/genericsuite-be-ai"
        echo "   pipenv install git+https://github.com/tomkat-cr/genericsuite-be@branch_name"
        exit_abort
    fi
    # Verify "Git" dependencies
    if grep -q "genericsuite-ai@ git" "${REPO_BASEDIR}/requirements.txt"; then
        echo "Git Genericsuite-BE-AI found in requirements.txt..."
        LOCAL_DEPENDENCIES_ERROR="1"
    fi
    if grep -q "genericsuite@ git" "${REPO_BASEDIR}/requirements.txt"; then
        echo "Git Genericsuite-BE found in requirements.txt..."
        LOCAL_DEPENDENCIES_ERROR="1"
    fi
    # Local dependecies are allowed but warn about it just in case a commit+push is needed...
    if [ "${LOCAL_DEPENDENCIES_ERROR}" = "1" ]; then
        echo ""
        echo "**************************************************************************"
        echo "* WARNING: Did you remember to do the commit+push on those repositories? *"
        echo "**************************************************************************"
        echo ""
        echo "If you decide to continue, I assume it was done..."
        ask_to_continue
    fi
}

requirements_rebuild() {
    cd "${REPO_BASEDIR}"
    REQUIREMENTS_REBUILD="0"
    if [[ Pipfile -nt requirements.txt ]]; then
      REQUIREMENTS_REBUILD="1"
      make requirements
    fi
}


docker_system_prune() {
    if [[ ${DOCKER_PRUNE} = "y" ]]; then
      # To handle the error "yum install ... Disk Requirements: ... At least ...MB more space needed on the / filesystem." during the "docker buildx build ..."
      echo ""
      echo ${DOCKER_CMD} system prune -a
      ${DOCKER_CMD} system prune -a
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
            echo ""
            echo ">> ECR repository URI exists..."
            if [ "${FORCE_ECR_IMAGE_CREATION}" = "1" ];then
                echo "   and it'll be overwritten..."
            else
                echo "   and it'll remain the same"
            fi
        else
            echo ""
            if [ "${FORCE_ECR_IMAGE_CREATION}" = "0" ];then
                ERROR_MSG="ERROR: Docker image version '${DOCKER_IMAGE_VERSION}' does not exist in the ECR repository: ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}, and the image creation wasn't ordered..."
                echo ">> ${ERROR_MSG}"
            else
                echo ">> ECR repository URI does not exists and it'll be created..."
            fi
        fi
    fi
}

build_docker() {
    echo "Building Docker image..."

    set -e

    echo ""
    echo cd ${TMP_BUILD_DIR}
    cd ${TMP_BUILD_DIR}
    pwd

    echo ""
    echo ${DOCKER_CMD} buildx build --platform linux/amd64 -t docker-image:${DOCKER_IMAGE_NAME} . 
    ${DOCKER_CMD} buildx build --platform linux/amd64 -t docker-image:${DOCKER_IMAGE_NAME} . 

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
      echo "${DOCKER_CMD} tag docker-image:${DOCKER_IMAGE_NAME} ${AWS_DOCKER_IMAGE_URI}"
      ${DOCKER_CMD} tag docker-image:${DOCKER_IMAGE_NAME} ${AWS_DOCKER_IMAGE_URI}
      
      echo ""
      echo "Docker push"
      echo ""
      echo ${DOCKER_CMD} push ${AWS_DOCKER_IMAGE_URI}
      ${DOCKER_CMD} push ${AWS_DOCKER_IMAGE_URI}
    fi
    echo ""
    echo "Deploy ECR image - END"
    echo ""
}

# -----

push_docker_image_to_ecr() {
    # Stop on any error
    set -e

    # 4. Create an ECR Repository
    # Create an Amazon ECR repository to store your Docker image.

    if ! ERROR_MSG=$(aws ecr create-repository --repository-name ${DOCKER_IMAGE_NAME} --region ${AWS_REGION} --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE)
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

    # 5. Tag the Docker Image
    # Tag your Docker image to match your ECR repository URI.
    REPOSITORY_URI=$(aws ecr describe-repositories --repository-names ${DOCKER_IMAGE_NAME} --region ${AWS_REGION} --query "repositories[0].repositoryUri" --output text)
    ${DOCKER_CMD} tag docker-image:${DOCKER_IMAGE_NAME} ${REPOSITORY_URI}:${ECR_IMAGE_TAG}

    # 6. Authenticate Docker to Your ECR Repository
    # Retrieve an authentication token and authenticate your Docker client to your ECR registry.
    aws ecr get-login-password --region ${AWS_REGION} | ${DOCKER_CMD} login --username AWS --password-stdin ${REPOSITORY_URI}

    # 7. Push the Docker Image to ECR
    # Push your Docker image to the Amazon ECR repository.
    ${DOCKER_CMD} push ${REPOSITORY_URI}:${ECR_IMAGE_TAG}
}

#############
# Main Flow #
#############

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

echo ""
echo "REPO_BASEDIR=${REPO_BASEDIR}"
echo "SCRIPTS_DIR=${SCRIPTS_DIR}"
echo ""

SKIP_DOTENV_GENERATION="1"

set -o allexport; . .env ; set +o allexport ;

docker_dependencies

# Validations
if [ "${ECR_IMAGE_TAG}" = "" ]; then
    echo ""
    echo "ERROR: ECR_IMAGE_TAG is not defined"
    exit_abort
fi
if [ "${STAGE}" = "" ]; then
    echo ""
    echo "ERROR: STAGE is not defined"
    exit_abort
fi
if [ "${APP_NAME}" = "" ]; then
    echo ""
    echo "ERROR: APP_NAME is not defined"
    exit_abort
fi
if [ "${AWS_LAMBDA_FUNCTION_NAME}" = "" ]; then
    echo ""
    echo "ERROR: AWS_LAMBDA_FUNCTION_NAME is not defined"
    exit_abort
fi
if [ "${AWS_REGION}" = "" ]; then
    echo ""
    echo "ERROR: AWS_REGION is not defined"
    exit_abort
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output json --no-paginate | jq -r '.Account')
if [ "${AWS_ACCOUNT_ID}" = "" ]; then
    echo ""
    echo "ERROR: AWS_ACCOUNT_ID could not be retrieved. Please configure your AWS credentials."
    exit_abort
fi

# Working variables
APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')
AWS_LAMBDA_FUNCTION_NAME_AND_STAGE=$(echo ${AWS_LAMBDA_FUNCTION_NAME}-${STAGE_UPPERCASE} | tr '[:upper:]' '[:lower:]')
DOCKER_IMAGE_NAME="${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}-ec2"

# Working directories
TMP_BUILD_DIR="/tmp/${APP_NAME_LOWERCASE}_aws_erc_build_tmp"
TMP_WORKING_DIR="/tmp"
DEBUG="1"

echo ""
echo "AWS EC2 Deployment - ECR Creation"
echo ""
echo "Parameters from the '.env' file:"
echo "Repository base directory (REPO_BASEDIR): ${REPO_BASEDIR}"
echo "Application name (APP_NAME): ${APP_NAME}"
echo "ECR Repository base name (AWS_LAMBDA_FUNCTION_NAME): ${AWS_LAMBDA_FUNCTION_NAME}"
echo "ECR image tag (ECR_IMAGE_TAG): ${ECR_IMAGE_TAG}"
echo "AWS Region (AWS_REGION): ${AWS_REGION}"
echo "Stage (STAGE): ${STAGE}"
echo ""
echo "Parameters to be used in the process:"
echo "Stage uppercased (STAGE_UPPERCASE): ${STAGE_UPPERCASE}"
echo "ECR Repository name with stage (AWS_LAMBDA_FUNCTION_NAME_AND_STAGE): ${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}"
echo "Docker image name (DOCKER_IMAGE_NAME): ${DOCKER_IMAGE_NAME}"
echo "AWS Account ID (AWS_ACCOUNT_ID): ${AWS_ACCOUNT_ID}"
echo ""

echo "Press enter to proceed with the ECR image creation..."
read -r

# 1. Create a Simple FastAPI App
# First, create a directory for your FastAPI app and a simple FastAPI application file.
# Then create a file named main.py

# mkdir my-fastapi-app
# cd my-fastapi-app
# vi main.py

requirements_rebuild
verify_requirements_with_local_dependencies
docker_system_prune

prepare_tmp_build_dir

# 2. Create a Dockerfile
# In the same directory, create a Dockerfile

copy_docker_file

# 3. Build the Docker Image

FORCE_ECR_IMAGE_CREATION="1"
DOCKER_PRUNE="0"
DOCKER_IMAGE_VERSION="${ECR_IMAGE_TAG}"
AWS_DOCKER_IMAGE_URI_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
AWS_DOCKER_IMAGE_URI="${AWS_DOCKER_IMAGE_URI_BASE}/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}"
verify_docker_image_exist
build_docker

# 4. Create an ECR Repository
# 5. Tag the Docker Image
# 6. Authenticate Docker to Your ECR Repository

# push_docker_image_to_ecr

