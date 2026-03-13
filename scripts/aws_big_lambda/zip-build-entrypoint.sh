#!/bin/bash
# zip-build-entrypoint.sh
# 2025-12-14 | CR

echo ""
echo "Host TMP_BUILD_DIR: ${TMP_BUILD_DIR}"
echo "Host SCRIPTS_DIR: ${SCRIPTS_DIR}"
echo ""
echo "App directory content:"
echo ""
cd /app
pwd
ls -la
echo ""
echo "Installing dependencies..."
echo ""
if ! pip install -r requirements.txt -t ./
then
    echo ""
    echo "Error installing dependencies!"
    echo ""
    exit 1
else
    echo ""
    echo "Dependencies installed successfully!"
    echo ""
fi
