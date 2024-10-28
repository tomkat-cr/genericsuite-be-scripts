#!/bin/bash
# run_schema_generator.sh
# 2024-10-27 | CR
#
set -o allexport ; . .env ; set +o allexport ;
REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
SCRIPTS_DIR="`pwd`"
#
if [ ! -d "venv" ]; then
    python -m venv venv
fi
source venv/bin/activate
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
else
    pip install ollama requests openai
    pip freeze > requirements.txt
fi
PARAMETERS=""
if [ "${OLLAMA_BASE_URL}" != "" ]; then
    PARAMETERS="${PARAMETERS} --ollama_base_url ${OLLAMA_BASE_URL}"
fi
if [ "${LANGCHAIN_DEFAULT_MODEL}" = "ollama" ]; then
    if [ "${OLLAMA_MODEL}" != "" ]; then
        PARAMETERS="${PARAMETERS} --model ${OLLAMA_MODEL}"
    fi
fi
if [ "${LANGCHAIN_DEFAULT_MODEL}" = "nvidia" ]; then
    if [ "${NVIDIA_MODEL}" != "" ]; then
        PARAMETERS="${PARAMETERS} --model ${NVIDIA_MODEL}"
    fi
fi
if [ "${LANGCHAIN_DEFAULT_MODEL}" = "chat_openai" ]; then
    if [ "${OPENAI_MODEL}" != "" ]; then
        PARAMETERS="${PARAMETERS} --model ${OPENAI_MODEL}"
    fi
fi
if [ "${OLLAMA_TEMPERATURE}" != "" ]; then
    PARAMETERS="${PARAMETERS} --temperature ${OLLAMA_TEMPERATURE}"
fi
if [ "${OLLAMA_STREAM}" != "" ]; then
    PARAMETERS="${PARAMETERS} --stream ${OLLAMA_STREAM}"
fi
if [ "${AGENTS_COUNT}" != "" ]; then
    PARAMETERS="${PARAMETERS} --agents_count ${AGENTS_COUNT}"
fi
if [ "${USER_INPUT}" = "" ]; then
    USER_INPUT="./user_input_example.md"
fi
PARAMETERS="${PARAMETERS} --provider ${LANGCHAIN_DEFAULT_MODEL}"
PARAMETERS="${PARAMETERS} --user_input ${USER_INPUT}"
echo "LANGCHAIN_DEFAULT_MODEL: ${LANGCHAIN_DEFAULT_MODEL}"
echo "NVIDIA_MODEL: ${NVIDIA_MODEL}"
echo ""
echo "Executing: python schema_generator.py ${PARAMETERS}"
pwd
echo ""
python schema_generator.py ${PARAMETERS}

deactivate
rm -rf venv
