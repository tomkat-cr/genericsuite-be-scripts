#!
# run_convert_json_to_yaml.sh
#
# Convert json to yaml string and files
# Useful to convert ".chalice/deployment/sam.json" to "scripts/aws_big_lambda/template-sam.yml"
#
# 2024-03-04
#
python -m venv venv
. venv/bin/activate
pip install -r requirements.txt
python -m convert_json_to_yaml "../../.chalice/deployment/sam.json" "./template.yml"
deactivate
rm -rf __pycache__