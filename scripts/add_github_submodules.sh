#!/bin/sh
# FILE: scripts/add_github_submodules.sh
ERROR_MSG=""

REPO_BASEDIR="`pwd`"

ENV_FILESPEC=""
if [ -f "${REPO_BASEDIR}/.env" ]; then
    ENV_FILESPEC="${REPO_BASEDIR}/.env"
fi
if [ "$ENV_FILESPEC" != "" ]; then
    set -o allexport; source ${ENV_FILESPEC}; set +o allexport ;
fi

if [ "${ERROR_MSG}" = "" ]; then
    if [ "${GIT_SUBMODULE_URL}" = "" ];then
        ERROR_MSG="GIT_SUBMODULE_URL is not set"
    fi
fi

if [ "${ERROR_MSG}" = "" ]; then
    if [ "${GIT_SUBMODULE_LOCAL_PATH}" = "" ];then
        ERROR_MSG="GIT_SUBMODULE_LOCAL_PATH is not set"
    fi
fi

if [ "${ERROR_MSG}" = "" ]; then
    if ! git config --global url.https://github.com/.insteadOf git://github.com/
    then
        ERROR_MSG="Failed to set git config"
    fi
fi

if [ "${ERROR_MSG}" = "" ]; then
    echo ""
    echo "Repo base dir: ${REPO_BASEDIR}"
    if ! cd "${REPO_BASEDIR}"
    then
        ERROR_MSG="Failed to cd into: ${REPO_BASEDIR}"
    fi
fi

if [ "${ERROR_MSG}" = "" ]; then
    if [ ! -d "${GIT_SUBMODULE_LOCAL_PATH}" ]; then
        echo ""
        echo "Adding submodule: ${GIT_SUBMODULE_URL}"
        echo "To: ${GIT_SUBMODULE_LOCAL_PATH}"
        if ! git submodule add "${GIT_SUBMODULE_URL}" "${GIT_SUBMODULE_LOCAL_PATH}"
        then
            ERROR_MSG="Failed to add submodule: ${GIT_SUBMODULE_LOCAL_PATH}"
        else
            if ! git submodule init
            then
                ERROR_MSG="Failed to init submodules"
            else
                if ! git submodule update
                then
                    ERROR_MSG="Failed to update submodules"
                fi
            fi
        fi
    else
        if ! cd "${GIT_SUBMODULE_LOCAL_PATH}"
        then
            ERROR_MSG="Failed to cd into: ${GIT_SUBMODULE_LOCAL_PATH}"
        else
            echo "Updating submodule: ${GIT_SUBMODULE_URL}"
            echo "In: ${GIT_SUBMODULE_LOCAL_PATH}"
            if ! git pull
            then
                ERROR_MSG="Failed to pull: ${GIT_SUBMODULE_LOCAL_PATH}"
            fi
        fi
    fi
fi

if [ "${ERROR_MSG}" = "" ]; then
    echo "SUCCESS"
else
    echo "ERROR: ${ERROR_MSG}"
fi
