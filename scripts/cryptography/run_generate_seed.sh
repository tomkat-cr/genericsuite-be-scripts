#!/bin/sh
# run_generate_seed.sh
# 2024-05-09 | CR
#
# Generate a Fernet key
#
REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`" ;
SCRIPTS_DIR="`pwd`" ;
python -m venv venv
. venv/bin/activate
if [ ! -f requirements.txt ]; then
    pip install cryptography
    pip freeze > requirements.txt
else
    pip install -r requirements.txt
fi
python -m generate_seed
deactivate
rm -rf __pycache__
rm -rf venv
