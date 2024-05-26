"""
This script generates the DynamoDB tables section for a SAM template.
2024-05-21 | CR
"""
import os
import sys
import json
import yaml

DEBUG = True


def convert_json_to_yaml(json_dict: str) -> str:
    """
    Convert the dictionary to a YAML formatted string
    """
    return yaml.dump(json_dict, sort_keys=False, default_flow_style=False)


def convert_snake_to_pascal(name: str) -> str:
    """
    Converts a snake_case name to PascalCase.
    """
    return ''.join([word.capitalize() for word in name.split('_')])


def get_dynamodb_definition(config: dict, table_prefix: str) -> dict:
    """
    Returns DynamoDB table definition from config.

    E.g.
        UsersTable:
            Type: AWS::Serverless::SimpleTable
            Properties:
                PrimaryKey:
                    Name: id
                    Type: String
                ProvisionedThroughput:
                    ReadCapacityUnits: 1
                    WriteCapacityUnits: 1

    """
    table_name = config.get('table_name')

    dynamodb_definition = None
    if not table_name:
        return dynamodb_definition

    definition_name = f"{convert_snake_to_pascal(table_name)}Table"

    _ = DEBUG and print(f'Table: {table_name}')
    # _ = DEBUG and print(config)

    field_elements = config.get('fieldElements', [])
    partition_key = None
    sort_key = None

    for field in field_elements:
        if field.get('type') == '_id':
            if not partition_key:
                partition_key = field.get('name')
            else:
                sort_key = field.get('name')
        # elif field.get('type') == '_sort':
        #   sort_key = field.get('name')

    if partition_key:
        dynamodb_definition = {
            'Type': 'AWS::DynamoDB::Table',
            'Properties': {
                'TableName': f"{table_prefix}{table_name}",
                'AttributeDefinitions': [
                    {
                        'AttributeName': partition_key,
                        'AttributeType': 'S'
                    }
                ],
                'KeySchema': [
                    {
                        'AttributeName': partition_key,
                        'KeyType': 'HASH'
                    }
                ],
                'ProvisionedThroughput': {
                    'ReadCapacityUnits': 1,
                    'WriteCapacityUnits': 1
                }
            }
        }

    if sort_key:
        dynamodb_definition['Properties']['AttributeDefinitions'].append({
            'AttributeName': sort_key,
            'AttributeType': 'S'
        })
        dynamodb_definition['Properties']['KeySchema'].append({
            'AttributeName': sort_key,
            'KeyType': 'RANGE'
        })

    if not dynamodb_definition:
        return dynamodb_definition

    return {
        definition_name: dynamodb_definition
    }


def generate_dynamodb_definitions(basedir: str, table_prefix: str):
    """
    Generates DynamoDB table definitions from frontend and backend config files.
    """
    dynamodb_definitions = {}

    dir_path = os.path.join(basedir, 'frontend')
    _ = DEBUG and print(f'Start directory: {dir_path}')

    # Read frontend and backend config files
    for root, _, files in os.walk(dir_path):
        for file in files:
            _ = DEBUG and print(f'File: {file}')
            if file.endswith('.json'):
                with open(os.path.join(root, file), 'r', encoding="utf-8") as f:
                    config = json.load(f)
                    # if file exists in backend config, merge them
                    file_path = os.path.join(basedir, 'backend', file)
                    if os.path.exists(file_path):
                        with open(file_path, 'r', encoding="utf-8") as f:
                            config.update(json.load(f))
                    table_definition = get_dynamodb_definition(config, table_prefix)
                    if table_definition:
                        # table_name = table_definition['Properties']['TableName']
                        # dynamodb_definitions[table_name] = table_definition
                        dynamodb_definitions.update(table_definition)

    return dynamodb_definitions


def generate_sam_dynamodb():
    """
    Generates DynamoDB table definitions for a SAM template.
    """
    print('')
    print('Generating DynamoDB table definitions for SAM template')
    print('')

    if len(sys.argv) < 4:
        print('Usage: python generate_sam_dynamodb.py <base_config_path> <target_template_path> <table_prefix>')
        sys.exit(1)

    base_config_path = sys.argv[1]
    target_template_path = sys.argv[2]
    table_prefix = sys.argv[3]

    print(f'base_config_path: {base_config_path}')
    print(f'target_template_path: {target_template_path}')
    print('')

    dynamodb_def = generate_dynamodb_definitions(basedir=base_config_path,
        table_prefix=table_prefix)
    # Open the target template file to write the DynamoDB table definition
    with open(target_template_path, 'w', encoding="utf-8") as f:
        # Save the template file
        # json.dump(dynamodb_def, f, indent=2)
        f.write(convert_json_to_yaml(dynamodb_def))

    print('')
    print(f'DynamoDB table definitions saved to {target_template_path}')


if __name__ == '__main__':
    generate_sam_dynamodb()
