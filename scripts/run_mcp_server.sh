#!/bin/bash
# scripts/run_mcp_server.sh
# MCP Server Startup Script
# 2025-11-20 | CR

# Get the MCP Server directory
BASE_DIR="$( pwd )"

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

cd "$BASE_DIR"

PEM_TOOL=uv

# mcp-server ".env" file read
if [ -f "$BASE_DIR/.env" ]; then
    echo "🔍 Reading .env file in $BASE_DIR..."
    set -o allexport; . "${BASE_DIR}/.env"; set +o allexport ;
else
    echo "❌ .env file not found in $MCP_APP_DIR. Please create one in `pwd`."
    exit 1
fi

# Set the application directory and main file
if [ -z "$MCP_APP_DIR" ]; then
    export MCP_APP_DIR="."
fi
if [ -z "$MCP_APP_MAIN_FILE" ]; then
    export MCP_APP_MAIN_FILE="mcp_server"
fi

echo "📂 Changing to MCP Server directory: $MCP_APP_DIR"
cd "$MCP_APP_DIR"

echo "🥗 Starting MCP Server..."
echo "📂 Current directory: `pwd`"
echo "📂 Script directory: $SCRIPT_DIR"
echo "📂 MCP Server directory: $MCP_APP_DIR"
echo "📂 MCP Server main file: $MCP_APP_MAIN_FILE"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    if ! command -v python &> /dev/null; then
        echo "❌ Python not found. Please install Python 3.10 or later."
        exit 1
    else
        PYTHON_CMD="python"
    fi
else
    PYTHON_CMD="python3"
fi

echo "🐍 Using Python: $PYTHON_CMD"

# Check if requirements are installed
echo "📦 Checking dependencies..."
echo "Running: ${PEM_TOOL} run $PYTHON_CMD -c \"import fastmcp, mcp\""
if ! ${PEM_TOOL} run $PYTHON_CMD -c "import fastmcp, mcp" &> /dev/null; then
    echo "📥 Installing dependencies..."
    bash ../node_modules/genericsuite-be-scripts/scripts/run_pem.sh install
    if [ $? -ne 0 ]; then
        echo "❌ Failed to install dependencies. Please check requirements.txt"
        exit 1
    fi
fi

echo "✅ Dependencies verified"

# # Read the .env file from the application directory if it is not the current directory
# if [ "$MCP_APP_DIR" != "." ]; then
#     if [ -f ".env" ]; then
#         echo "🔍 Reading .env file in: `pwd`"
#         set -o allexport; . ".env"; set +o allexport ;
#     else
#         echo "❌ .env file not found in $MCP_APP_DIR. Please create one in `pwd`."
#         exit 1
#     fi
# fi

echo "🚀 Preparing environment..."

# Enforce framework and method to enable running the MCP server from the API server directory
export CURRENT_FRAMEWORK="mcp"
export RUN_METHOD="mcp"

# Default values for environment variables

# Application stage (qa, stage, prod, demo) to run MCP server
if [ -z "$APP_STAGE" ]; then
    export APP_STAGE=qa
fi

# Debug mode
if [ -z "$MCP_DEBUG_MODE" ]; then
    export MCP_DEBUG_MODE="0"
fi

# MCP server port
if [ -z "$MCP_SERVER_PORT" ]; then
    export MCP_SERVER_PORT=8070
fi

# MCP server host
if [ -z "$MCP_SERVER_HOST" ]; then
    export MCP_SERVER_HOST="0.0.0.0"
fi

# Set working variables

if [ "$MCP_DEBUG_MODE" = "1" ]; then
    export MCP_TRANSPORT="stdio"
else
    export MCP_TRANSPORT="http"
fi

STAGE_UPPERCASE=$(echo $APP_STAGE | tr '[:lower:]' '[:upper:]')
export APP_HOST_NAME="${DOMAIN_NAME:-localhost}"
export APP_DB_ENGINE=$(eval echo \$APP_DB_ENGINE_${STAGE_UPPERCASE})
export APP_DB_NAME=$(eval echo \$APP_DB_NAME_${STAGE_UPPERCASE})
if [[ "${GET_SECRETS_ENABLED}" = "0" || "${GET_SECRETS_CRITICAL}" = "0" ]]; then
    export APP_DB_URI=$(eval echo \$APP_DB_URI_${STAGE_UPPERCASE})
else
    export APP_DB_URI=""
fi
export APP_CORS_ORIGIN="$(eval echo \"\$APP_CORS_ORIGIN_${STAGE_UPPERCASE}\")"
export AWS_S3_CHATBOT_ATTACHMENTS_BUCKET=$(eval echo \$AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_${STAGE_UPPERCASE})

MCP_RUN_ARGS="APP_NAME=$APP_NAME APP_STAGE=$APP_STAGE APP_SECRET_KEY=$APP_SECRET_KEY STORAGE_URL_SEED=$STORAGE_URL_SEED APP_SUPERADMIN_EMAIL=$APP_SUPERADMIN_EMAIL GIT_SUBMODULE_LOCAL_PATH=$GIT_SUBMODULE_LOCAL_PATH APP_DB_ENGINE=$APP_DB_ENGINE APP_DB_NAME=$APP_DB_NAME APP_DB_URI=\"$APP_DB_URI\" APP_CORS_ORIGIN=\"$APP_CORS_ORIGIN\" APP_HOST_NAME=$APP_HOST_NAME CURRENT_FRAMEWORK=$CURRENT_FRAMEWORK  CLOUD_PROVIDER=$CLOUD_PROVIDER AWS_S3_CHATBOT_ATTACHMENTS_BUCKET=\"$AWS_S3_CHATBOT_ATTACHMENTS_BUCKET\" AWS_REGION=$AWS_REGION GET_SECRETS_ENABLED=$GET_SECRETS_ENABLED GET_SECRETS_CRITICAL=$GET_SECRETS_CRITICAL GET_SECRETS_ENVVARS=$GET_SECRETS_ENVVARS MCP_SERVER_PORT=$MCP_SERVER_PORT MCP_SERVER_HOST=$MCP_SERVER_HOST MCP_TRANSPORT=$MCP_TRANSPORT "

if [ "${GS_USER_NAME}" != '' ]; then
    MCP_RUN_ARGS="${MCP_RUN_ARGS} GS_USER_NAME=$GS_USER_NAME"
fi

if [ "${GS_USER_ID}" != '' ]; then
    MCP_RUN_ARGS="${MCP_RUN_ARGS} GS_USER_ID=$GS_USER_ID"
fi

if [ "${GS_API_KEY}" != '' ]; then
    MCP_RUN_ARGS="${MCP_RUN_ARGS} GS_API_KEY=\"$GS_API_KEY\""
fi

if [ "${ADDITIONAL_MCP_RUN_ARGS}" != '' ]; then
    MCP_RUN_ARGS="${MCP_RUN_ARGS} ${ADDITIONAL_MCP_RUN_ARGS}"
fi

# Start the server

if [ "$MCP_SERVER_RUN_AS_MODULE" = "true" ]; then
    RUN_CMD="${PEM_TOOL} run env $MCP_RUN_ARGS $PYTHON_CMD -m $MCP_APP_MAIN_FILE"
else
    RUN_CMD="${PEM_TOOL} run env $MCP_RUN_ARGS $PYTHON_CMD $MCP_APP_MAIN_FILE.py"
fi

echo "🚀 Starting MCP server..."
echo ""

if [ "$MCP_DEBUG_MODE" = "1" ]; then
    CLIENT_PORT=6274 SERVER_PORT=6277 \
        npx @modelcontextprotocol/inspector \
        ${RUN_CMD}
else
    ${RUN_CMD}
fi
