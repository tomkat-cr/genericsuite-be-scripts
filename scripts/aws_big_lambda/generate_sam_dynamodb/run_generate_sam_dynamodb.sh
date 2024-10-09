#!/bin/sh
# run_generate_sam_dynamodb.sh
# 2024-05-21 | CR
# Generates the DynamoDB tables section for a SAM template.
# Usage:
# sh scripts/aws_big_lambda/generate_sam_dynamodb/run_generate_sam_dynamodb.sh

yes_or_no() {
  read choice
  while [[ ! $choice =~ ^[YyNn]$ ]]; do
    echo "Please enter Y or N"
    read choice
  done
}

set -o allexport; . .env ; set +o allexport ;

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`" ;
SCRIPTS_DIR="`pwd`" ;

WORKING_DIR="/tmp/generate_sam_dynamodb"
mkdir -p "${WORKING_DIR}"

python -m venv venv
. venv/bin/activate

if [ ! -f requirements.txt ]; then
    pip install pyyaml
    pip freeze > requirements.txt
else
    pip install -r requirements.txt
fi

BASE_CONFIG_PATH="${GIT_SUBMODULE_LOCAL_PATH}"
if [ "${BASE_CONFIG_PATH}" = "" ]; then
    echo 'GIT_SUBMODULE_LOCAL_PATH environment variable not set'
    exit 1
fi
BASE_CONFIG_PATH="${REPO_BASEDIR}/${BASE_CONFIG_PATH}"

if [ "${APP_NAME}" = "" ]; then
    echo 'APP_NAME environment variable not set'
    exit 1
fi
APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')

ERROR="0"
if ! python -m generate_sam_dynamodb "${BASE_CONFIG_PATH}" "${WORKING_DIR}/template.yml" "${APP_NAME_LOWERCASE}_"
then
    ERROR="1"
fi

deactivate
rm -rf __pycache__
rm -rf venv

if [ "${ERROR}" = "1" ]; then
    echo "Error generating SAM template file."
else
    echo ""
    echo "Generated SAM template file in:"
    echo "${WORKING_DIR}/template.yml"
    echo ""
    echo "Do you want to edit it (y/n)?"
    yes_or_no

    if [[ $choice =~ ^[Yy]$ ]]; then
        echo "Opening editor..."
        if ! code "${WORKING_DIR}/template.yml"
        then
            if ! nano "${WORKING_DIR}/template.yml"
            then
                if ! vi "${WORKING_DIR}/template.yml"
                then
                    echo "Failed to open editor."
                fi
            fi
        fi
    fi
    echo "Done."
fi
