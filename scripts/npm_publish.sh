#!/bin/bash
# File: scripts/npm_publish.sh
#
# Run:
#   sh scripts/npm_publish.sh pre-publish|publish
#
# Options (Defaults to "pre-publish"):
#   pre-publish:  npm run build && npm test
#   publish:      npm publish
#
# 2024-03-16 | CR
#

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`" ;
SCRIPTS_DIR="`pwd`" ;
cd "${REPO_BASEDIR}"

sh ${SCRIPTS_DIR}/show_date_time.sh

ACTION="$1"
if [ -z "${ACTION}" ]; then
  ACTION="pre-publish"
fi

export PACKAGE_NAME=$(perl -ne 'print $1 if /"name":\s*"([^"]*)"/' package.json)
if [ "${PACKAGE_NAME}" = "" ]; then
    PACKAGE_NAME="N/A"
fi
export PACKAGE_VERSION=$(perl -ne 'print $1 if /"version":\s*"([^"]*)"/' package.json)
if [ "${PACKAGE_VERSION}" = "" ]; then
    PACKAGE_VERSION="N/A"
fi

echo "Package Lock (to update App version)..."
if ! npm install --package-lock-only
then
    echo "ERROR running: npm install --package-lock-only"
    exit 1
fi

bash ${SCRIPTS_DIR}/npm_remove_ignored.sh .gitignore
# if ! bash ${SCRIPTS_DIR}/npm_remove_ignored.sh .gitignore
# then
#     echo "ERROR running: sh scripts/npm_remove_ignored.sh .gitignore"
#     exit 1
# fi

if [ "${ACTION}" = "publish" ]; then
    echo ""
    echo "Are you sure you want to publish ${PACKAGE_NAME}:${PACKAGE_VERSION} (y/n)?"
    read answer
    if [ "${answer}" = "y" ]; then
        npm publish --access=public
    fi
fi

echo ""
echo "Done with ${ACTION} !"

sh ${SCRIPTS_DIR}/show_date_time.sh