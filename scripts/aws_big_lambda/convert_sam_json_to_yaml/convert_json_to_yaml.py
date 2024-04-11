"""
convert_sam_json_to_yaml.py
2023-12-10 | CR

Convert json to yaml string and files
Useful to convert ".chalice/deployment/sam.json" to "scripts/aws_big_lambda/template-sam.yml"

Requirements:
- pip install pyyaml

"""
import sys
import json
import yaml


def json_to_yaml_file(json_file_path: str, yaml_file_path: str) -> None:
    """
    Convert a json file to a yaml file
    """
    with open(json_file_path, encoding="utf-8", mode="r") as json_file:
        json_content = json_file.read()
        yaml_content = convert_json_to_yaml(json_content)
        with open(yaml_file_path, encoding="utf-8", mode="w") as yaml_file:
            yaml_file.write(yaml_content)


def convert_json_to_yaml(json_content: str) -> str:
    """
    Convert from json to yaml string
    """
    # Convert the JSON string to a Python dictionary
    json_dict = json.loads(json_content)

    # Convert the dictionary to a YAML formatted string
    return yaml.dump(json_dict, sort_keys=False, default_flow_style=False)


if __name__ == "__main__":
    json_file_path_par = sys.argv[1]
    yaml_file_path_par = sys.argv[2]
    json_to_yaml_file(json_file_path=json_file_path_par,
                      yaml_file_path=yaml_file_path_par)
