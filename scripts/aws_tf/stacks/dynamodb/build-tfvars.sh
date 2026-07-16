#!/bin/bash
# stacks/dynamodb/build-tfvars.sh
# Sourced by run-tf-deployment.sh. Generates dynamodb.auto.tfvars.json from
# the GenericSuite JSON config dir (GIT_SUBMODULE_LOCAL_PATH).
# 2026-07-16 | CR [GS-334]

if [ "${GIT_SUBMODULE_LOCAL_PATH:-}" = "" ]; then
    echo "ERROR: GIT_SUBMODULE_LOCAL_PATH is not set (needed to locate the JSON config dir)"
    exit 1
fi

DYNDB_CONFIG_DIR="${REPO_BASEDIR}/${GIT_SUBMODULE_LOCAL_PATH}"
if [ ! -d "${DYNDB_CONFIG_DIR}/frontend" ]; then
    echo "ERROR: '${DYNDB_CONFIG_DIR}/frontend' not found"
    exit 1
fi

python3 "${SCRIPTS_DIR}/generate_dynamodb_tfvars.py" \
    "${DYNDB_CONFIG_DIR}" \
    "${SCRIPTS_DIR}/stacks/dynamodb/dynamodb.auto.tfvars.json"
