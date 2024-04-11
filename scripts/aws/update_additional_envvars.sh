#!/bin/sh
#
# scripts/aws/update_additional_envvars.sh
#
# Updates environment variables values in config file
#
# Parameters:
# 1. CONFIG_FILE - path to config file where the environment variables values will be replaced
# 2. REPO_BASEDIR - path to the repository where the .env file is located (default: current directory)
#
# 2024-03-28 | CR

CONFIG_FILE="$1"
if [ "${CONFIG_FILE}" = "" ]; then
    echo "1st parameter (CONFIG_FILE) not set"
    exit 1
fi

REPO_BASEDIR="$2"
if [ "${REPO_BASEDIR}" = "" ]; then
    REPO_BASEDIR="`pwd`"
fi

set -o allexport; . "${REPO_BASEDIR}/.env"; set +o allexport;

perl -i -pe"s|FLASK_APP_placeholder|${FLASK_APP}|g" "${CONFIG_FILE}"

# INSTRUCTIONS:

# 1) Copy and edit this file:
#
# $ cp node_modules/genericsuite-be-scripts/scripts/aws/update_additional_envvars.sh ./scripts/aws/
# $ vi scripts/aws/update_additional_envvars.sh

# 2) Add your additional environment variables replacements here as:
#
# perl -i -pe"s|ENVVAR_NAME_placeholder|${ENVVAR_NAME}|g" "${CONFIG_FILE}"
#
# ... replacing "ENVVAR_NAME" with the name of the environment variable

# 3) Add the additional environment variables to the ".env" file:
#
# ENVVAR_NAME=value
#
# ... replacing "ENVVAR_NAME" with the name of the environment variable and ENVVAR_VALUE with its value.

# 4) Add the additional environment variables to the "scripts/aws_big_lambda/template-sam.yml" file in the section "APIHandler > Properties > Environment > Variables". E.g.
#      .
#      .
#   APIHandler:
#          .
#          .
#      Properties:
#             .
#             .
#        Environment:
#          Variables:
#            ENVVAR_NAME: ENVVAR_VALUE
#                  .
#                  .
# ... replacing "ENVVAR_NAME" with the name of the environment variable

# 5) If you're using the Chalice framework, add the additional environment variables to the ".chalice/config-example.json" file, in the main "environment_variables" section. E.g.
#
#    {
#       "version": "2.0",
#             .
#             .
#       "environment_variables": {
#                .
#                .
#          "ENVVAR_NAME": "ENVVAR_NAME_placeholder"
#       },
#       "stages": {
#             .
#             .
#
# ... replacing "ENVVAR_NAME" with the name of the environment variable (in both places).
