#!/bin/sh
# scripts/link_gs_libs_for_dev.sh
# Link GenericSuite libraries and trigger the uvicorn/gunicorn reload after pipenv update [FA-84].
# Since the new pipenv, version 2024.1.0, the changes made to files in a local installed repo won't trigger the uvicorn/gunicorn reload.
# So this script will link the libraries in "~/.local/share/virtualenvs" to the source code.
# References:
#   "GS-15 - Generic Endpoint Builder for Flask" (check 2025-01-07 & 2025-01-08)
#   "FA-84 - Separate BE Generic Suite and publish to PyPi" (check 2025-01-05)
# 2025-01-08 | CR

echo "Read .env file"
set -o allexport ; . .env ; set +o allexport ;

if [ "${BASE_DEVELOPMENT_PATH}" = "" ]; then
    echo "ERROR: BASE_DEVELOPMENT_PATH environment variable not set. It must be set with your local repos base path."
    echo "E.g. $HOME/local_repos"
    exit 1
fi

link_gs_libs_for_dev() {
    gs_lib_source_name="$1"
    gs_lib_target_name="$2"

    echo ""
    echo "Source directory: ${BASE_DEVELOPMENT_PATH}/$gs_lib_source_name/$gs_lib_target_name"

    if [ ! -d "${BASE_DEVELOPMENT_PATH}/$gs_lib_source_name/$gs_lib_target_name" ]; then
        echo "ERROR: No ${gs_lib_target_name} directory found in '${BASE_DEVELOPMENT_PATH}/$gs_lib_source_name'."
        exit 1
    fi

    BASE_VIR_ENVS_PATH=`pipenv --venv | head -1`
    if [ "$BASE_VIR_ENVS_PATH" = "" ]; then
        echo "ERROR: No virtual environment found. Please run 'pipenv shell' first."
        exit 1
    fi

    echo ""
    echo "BASE_VIR_ENVS_PATH: ${BASE_VIR_ENVS_PATH}"

    if [ ! -d "${BASE_VIR_ENVS_PATH}/lib" ]; then
        echo "ERROR: No virtual environment found in '${BASE_VIR_ENVS_PATH}'."
        exit 1
    fi

    PYTHON_INTERPRETER_BASE_PATH="${BASE_VIR_ENVS_PATH}/lib"

    if [ ! -d "${PYTHON_INTERPRETER_BASE_PATH}" ]; then
        echo "ERROR: No lib directory found in '${PYTHON_INTERPRETER_BASE_PATH}'."
        exit 1
    fi

    echo ""
    echo "ls -la ${PYTHON_INTERPRETER_BASE_PATH}"
    ls -la "${PYTHON_INTERPRETER_BASE_PATH}"

    PYTHON_INTERPRETER_NAME=`ls -la "${PYTHON_INTERPRETER_BASE_PATH}" | grep "^d" | awk '{print $9}'`
    # Get the 3rd value
    PYTHON_INTERPRETER_NAME=`echo ${PYTHON_INTERPRETER_NAME} | awk '{print $3}'`

    echo ""
    echo "PYTHON_INTERPRETER_NAME: ${PYTHON_INTERPRETER_NAME}"

    if [ "${PYTHON_INTERPRETER_NAME}" = "" ]; then
        echo "ERROR: No python interpreter found in '${PYTHON_INTERPRETER_BASE_PATH}'."
        exit 1
    fi

    VIRT_ENV_BASE_PATH="${PYTHON_INTERPRETER_BASE_PATH}/${PYTHON_INTERPRETER_NAME}/site-packages"

    echo ""
    echo "VIRT_ENV_BASE_PATH: ${VIRT_ENV_BASE_PATH}"

    if [ ! -d "${VIRT_ENV_BASE_PATH}/$gs_lib_target_name" ]; then
        echo "ERROR: No ${gs_lib_target_name} directory found in '${VIRT_ENV_BASE_PATH}/$gs_lib_target_name'."
        exit 1
    else
        echo ""
        echo "Linking '${VIRT_ENV_BASE_PATH}/$gs_lib_target_name' to '${BASE_DEVELOPMENT_PATH}/$gs_lib_source_name/$gs_lib_target_name'"

        if [ -d "${VIRT_ENV_BASE_PATH}/$gs_lib_target_name" ]; then
            if [ -d "${VIRT_ENV_BASE_PATH}/$gs_lib_target_name.old" ]; then
                rm -rf "${VIRT_ENV_BASE_PATH}/$gs_lib_target_name.old"
            fi
            mv "${VIRT_ENV_BASE_PATH}/$gs_lib_target_name" "${VIRT_ENV_BASE_PATH}/$gs_lib_target_name.old"
        fi

        if ! ln -s "${BASE_DEVELOPMENT_PATH}/$gs_lib_source_name/$gs_lib_target_name" "${VIRT_ENV_BASE_PATH}/$gs_lib_target_name"
        then
            echo "ERROR: Could not link '${BASE_DEVELOPMENT_PATH}/$gs_lib_source_name/$gs_lib_target_name' to '${VIRT_ENV_BASE_PATH}/$gs_lib_target_name'"
            exit 1
        else
            echo ""
            echo "Local repo linked..."
            echo ""
            echo "Target: ${BASE_DEVELOPMENT_PATH}/$gs_lib_source_name/$gs_lib_target_name"
            echo "Source: ${VIRT_ENV_BASE_PATH}/$gs_lib_target_name"
            echo ""
            echo "ls -lah ${BASE_DEVELOPMENT_PATH}/$gs_lib_source_name/$gs_lib_target_name/"
            ls -lah ${BASE_DEVELOPMENT_PATH}/$gs_lib_source_name/$gs_lib_target_name/
            echo ""
            echo "ls -lah ${VIRT_ENV_BASE_PATH}/$gs_lib_target_name/"
            ls -lah ${VIRT_ENV_BASE_PATH}/$gs_lib_target_name/
        fi
    fi
}

echo ""
echo "Linking GenericSuite libraries for development..."

link_gs_libs_for_dev "genericsuite-be" "genericsuite"
link_gs_libs_for_dev "genericsuite-be-ai" "genericsuite_ai"

