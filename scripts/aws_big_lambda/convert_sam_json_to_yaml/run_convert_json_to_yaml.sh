#!/bin/sh
# run_convert_json_to_yaml.sh
# 2024-03-04 | CR
#
# Convert json to yaml string and files
# Useful to convert ".chalice/deployment/sam.json" to "scripts/aws_big_lambda/template-sam.yml"
#
REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`" ;
SCRIPTS_DIR="`pwd`" ;
python -m venv venv
. venv/bin/activate
if [ ! -f requirements.txt ]; then
    pip install pyyaml
    pip freeze > requirements.txt
else
    pip install -r requirements.txt
fi
python -m convert_json_to_yaml "${REPO_BASEDIR}/.chalice/deployment/sam.json" "${SCRIPTS_DIR}/../template.yml"
echo ""
echo "Converted file in:"
echo "${SCRIPTS_DIR}/../template.yml"
echo ""
deactivate
rm -rf __pycache__
rm -rf venv
