#!/bin/bash
# scripts/set_app_dir_and_main_file.sh
# Loads .env file and sets APP_DIR, APP_MAIN_FILE and APP_HANDLER environment
# variables with the Python starting app for uvicorn and gunicorn.
# 2024-04-27 | CR

# Assumes it's run from the project root directory...
set -o allexport; . .env ; set +o allexport ;

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
