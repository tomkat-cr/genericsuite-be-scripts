#!/bin/sh
# run_generate_dynamodb_cf.sh
# 2024-05-21 | CR
# Generates the DynamoDB tables section for a SAM template.
# Usage:
# sh scripts/aws_dynamodb/generate_dynamodb_cf/run_generate_dynamodb_cf.sh

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

WORKING_DIR="/tmp/generate_dynamodb_cf"
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
CF_TEMPLATE_NAME="cf-template-dynamodb.yml"
FINAL_TARGET_DIR="${REPO_BASEDIR}/scripts/aws_dynamodb"

ERROR="0"
# if ! python -m generate_dynamodb_cf "${BASE_CONFIG_PATH}" "${WORKING_DIR}/${CF_TEMPLATE_NAME}" "${APP_NAME_LOWERCASE}_"
if ! python -m generate_dynamodb_cf "${BASE_CONFIG_PATH}" "${WORKING_DIR}/${CF_TEMPLATE_NAME}" ""
then
    ERROR="1"
fi

deactivate
rm -rf __pycache__
rm -rf venv

if [ ${ERROR} = "1" ]; then
    echo "Error generating SAM template file."
else
    echo ""
    echo "Generated SAM template file in:"
    echo "${WORKING_DIR}/${CF_TEMPLATE_NAME}"
    echo ""
    echo "Do you want to edit it (y/n)?"
    yes_or_no

    if [[ $choice =~ ^[Yy]$ ]]; then
        echo "Opening editor..."
        if ! code "${WORKING_DIR}/${CF_TEMPLATE_NAME}"
        then
            if ! nano "${WORKING_DIR}/${CF_TEMPLATE_NAME}"
            then
                if ! vi "${WORKING_DIR}/${CF_TEMPLATE_NAME}"
                then
                    echo "Failed to open editor."
                    exit 1
                fi
            fi
        fi
    fi

    echo ""
    echo "Copy to final destination:"
    echo "From: ${WORKING_DIR}/${CF_TEMPLATE_NAME}"
    echo "To: ${FINAL_TARGET_DIR}/${CF_TEMPLATE_NAME}"
    echo ""
    echo "Do you want to perform the copy (y/n)?"
    yes_or_no

    if [[ $choice =~ ^[Yy]$ ]]; then
        echo "Copying..."
        if ! mkdir -p "${FINAL_TARGET_DIR}"
        then
            echo "Failed to create directory: ${FINAL_TARGET_DIR}"
        else
            if [ -f "${FINAL_TARGET_DIR}/${CF_TEMPLATE_NAME}" ]
            then
                echo "File already exists. Overwrite (y/n)"
                yes_or_no
                if [[ $choice =~ ^[Yy]$ ]]; then
                    if ! cp "${WORKING_DIR}/${CF_TEMPLATE_NAME}" "${FINAL_TARGET_DIR}/"
                    then
                        echo "Failed to copy file."
                    fi
                else
                    echo "Skipping copy."
                fi
            else
                if ! cp "${WORKING_DIR}/${CF_TEMPLATE_NAME}" "${FINAL_TARGET_DIR}/"
                then
                    echo "Failed to copy file."
                fi
            fi
        fi
    fi

    echo "Done."
fi
