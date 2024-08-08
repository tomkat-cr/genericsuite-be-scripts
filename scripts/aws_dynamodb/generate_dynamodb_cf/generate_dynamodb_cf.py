"""
Generates a DynamoDB tables CloudFormation template from the GenericSuite
configuration .JSON files.
References:
https://github.com/aws-cloudformation/aws-cloudformation-templates/blob/main/DynamoDB/DynamoDB_Secondary_Indexes.yaml
https://github.com/aws-cloudformation/aws-cloudformation-templates/blob/main/DynamoDB/DynamoDB_Table.yaml
2024-05-21 | CR
"""
import os
import sys
import json
import yaml
import boto3

DEBUG = True

START_STRING = """
AWSTemplateFormatVersion: "2010-09-09"

Description: AWS CloudFormation Template to create the DynamoDB""" + \
               """tables from the GenericSuite configuration.

Metadata:
  License: Apache-2.0

Parameters:
  ReadCapacityUnits:
    Description: Provisioned read throughput
    Type: Number
    Default: "1"
    MinValue: "1"
    MaxValue: "10000"
    ConstraintDescription: must be between 5 and 10000
  WriteCapacityUnits:
    Description: Provisioned write throughput
    Type: Number
    Default: "1"
    MinValue: "1"
    MaxValue: "10000"
    ConstraintDescription: must be between 5 and 10000
  AppName:
    Description: application name
    Type: String
  AppStage:
    Description: application stage (qa, prod, staging, demo, dev)
    Type: String

"""

END_STRING = """
"""

DEFAULT_WRITE_CAPACITY_UNITS = 1
DEFAULT_READ_CAPACITY_UNITS = 1


class SubRep(tuple):
    def __new__(cls, a):
        return tuple.__new__(cls, ["", a])

    def __repr__(self):
        return "Sub(%s,%s)" % self


def sub_representer(dumper, data):
    return dumper.represent_scalar(u'!Sub', u'%s%s' % data)


def convert_json_to_yaml(json_dict: str) -> str:
    """
    Convert the dictionary to a YAML formatted string
    """
    # For the trick about Add !Sub without enclosing it between quotes
    # along with the followed string, check the
    # "Constructors, representers, resolvers" section in:
    # https://pyyaml.org/wiki/PyYAMLDocumentation
    yaml.add_representer(SubRep, sub_representer)
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
        AWSTemplateFormatVersion: "2010-09-09"

        Description: 'AWS CloudFormation Sample Template
            DynamoDB_Secondary_Indexes: Create a DynamoDB table with local and
            global secondary indexes. **WARNING** This template creates an
            Amazon DynamoDB table. You will be billed for the AWS resources
            used if you create a stack from this template.'

        Metadata:
          License: Apache-2.0

        Parameters:
          ReadCapacityUnits:
            Description: Provisioned read throughput
            Type: Number
            Default: "5"
            MinValue: "5"
            MaxValue: "10000"
            ConstraintDescription: must be between 5 and 10000

          WriteCapacityUnits:
            Description: Provisioned write throughput
            Type: Number
            Default: "10"
            MinValue: "5"
            MaxValue: "10000"
            ConstraintDescription: must be between 5 and 10000

        Resources:
          TableOfBooks:
            Type: AWS::DynamoDB::Table
            Properties:
               AttributeDefinitions:
                 - AttributeName: Title
                   AttributeType: S
                 - AttributeName: Category
                   AttributeType: S
                 - AttributeName: Language
                   AttributeType: S
               KeySchema:
                 - AttributeName: Category
                   KeyType: HASH
                 - AttributeName: Title
                   KeyType: RANGE
               ProvisionedThroughput:
                 ReadCapacityUnits: !Ref ReadCapacityUnits
                 WriteCapacityUnits: !Ref WriteCapacityUnits
               LocalSecondaryIndexes:
                 - IndexName: LanguageIndex
                   KeySchema:
                     - AttributeName: Category
                       KeyType: HASH
                     - AttributeName: Language
                       KeyType: RANGE
                   Projection:
                     ProjectionType: KEYS_ONLY
               GlobalSecondaryIndexes:
                 - IndexName: TitleIndex
                   KeySchema:
                     - AttributeName: Title
                       KeyType: HASH
                   Projection:
                     ProjectionType: KEYS_ONLY
                 ProvisionedThroughput:
                   ReadCapacityUnits: !Ref ReadCapacityUnits
                   WriteCapacityUnits: !Ref WriteCapacityUnits
               PointInTimeRecoverySpecification:
                 PointInTimeRecoveryEnabled: true

        Outputs:
          TableName:
            Description: Name of the newly created DynamoDB table
            Value: !Ref TableOfBooks
            Export:
              Name: !Sub "${AWS::StackName}-TableName"
    """
    table_name = config.get('table_name')

    if not table_name:
        return {}

    dynamodb_definition = {}
    definition_name = f"{convert_snake_to_pascal(table_name)}Table"
    dynamodb_table_name = f"{table_prefix}" + \
                          "${AppName}_${AppStage}_" + \
                          f"{table_name}"

    read_capacity_units = config.get('ReadCapacityUnits', "1")
    write_capacity_units = config.get('WriteCapacityUnits', "1")

    dynamodb_output = {
        # This gives the error "Template format error:
        #   Outputs name 'xxx_xxxx_xxx' is non alphanumeric."
        # table_name: {
        definition_name: {
            # "Description": f"Name for the {table_name} DynamoDB table",
            "Description": table_name,
            "Value": SubRep(dynamodb_table_name),
            "Export": {
                # This gives the error "Template format error:
                #   Output XxxxxTable is malformed. The Name field of every
                #   Export member must be specified and consist only of
                #   alphanumeric characters, colons, or hyphens."
                # "Name": SubRep(f"{dynamodb_table_name}-TableName")
                "Name": SubRep(f"{definition_name}Name")
            }
        }
    }

    _ = DEBUG and print(f'Table: {table_name}')
    # _ = DEBUG and print(config)

    field_elements = config.get('fieldElements', [])
    partition_key = None
    sort_key = None

    for field in field_elements:
        if field.get('type') == '_id':
            if not partition_key:
                if field.get('name') == 'id':
                    partition_key = '_id'
                else:
                    partition_key = field.get('name')
            else:
                sort_key = field.get('name')
        # elif field.get('type') == '_sort':
        #   sort_key = field.get('name')

    if partition_key:
        dynamodb_definition = {
            'Type': 'AWS::DynamoDB::Table',
            'Properties': {
                'TableName': SubRep(dynamodb_table_name),
                'AttributeDefinitions': [
                    {
                        'AttributeName': partition_key,
                        'AttributeType': 'S',
                    }
                ],
                'KeySchema': [
                    {
                        'AttributeName': partition_key,
                        'KeyType': 'HASH',
                    }
                ],
                'ProvisionedThroughput': {
                    'ReadCapacityUnits': read_capacity_units,
                    'WriteCapacityUnits': write_capacity_units,
                }
            }
        }

    if sort_key:
        dynamodb_definition['Properties']['AttributeDefinitions'].append({
            'AttributeName': sort_key,
            'AttributeType': 'S',
        })
        dynamodb_definition['Properties']['KeySchema'].append({
            'AttributeName': sort_key,
            'KeyType': 'RANGE',
        })

    if not dynamodb_definition:
        return {}

    return {
        "ts": {
          definition_name: dynamodb_definition
        },
        "output": dynamodb_output,
    }


def generate_dynamodb_definitions(basedir: str, table_prefix: str):
    """
    Generates DynamoDB table definitions from frontend and backend
    config files.
    """
    dynamodb_definitions = {}
    dynamodb_outputs = {}

    dir_path = os.path.join(basedir, 'frontend')
    _ = DEBUG and print(f'Start directory: {dir_path}')

    # Read frontend and backend config files
    for root, _, files in os.walk(dir_path):
        for file in files:
            _ = DEBUG and print(f'File: {file}')
            if file.endswith('.json'):
                with open(os.path.join(root, file),
                          'r', encoding="utf-8") as f:
                    config = json.load(f)
                    # if file exists in backend config, merge them
                    file_path = os.path.join(basedir, 'backend', file)
                    if os.path.exists(file_path):
                        with open(file_path, 'r', encoding="utf-8") as f:
                            config.update(json.load(f))
                    table_definition = get_dynamodb_definition(config,
                                                               table_prefix)
                    if table_definition:
                        dynamodb_definitions.update(table_definition['ts'])
                        dynamodb_outputs.update(table_definition['output'])

    return {
      'ts': dynamodb_definitions,
      'output': dynamodb_outputs,
    }


def write_dynamodb_cf_template_file(target_template_path: str,
                                    dynamodb_def: str):
    # Open the target template file to write the DynamoDB table definition
    with open(target_template_path, 'w', encoding="utf-8") as f:
        # Save the template file
        f.write(START_STRING)
        f.write(convert_json_to_yaml({
          "Resources": dynamodb_def['ts']
        }))
        f.write(END_STRING)
        f.write(convert_json_to_yaml({
          "Outputs": dynamodb_def['output']
        }))

    print('')
    print(f'DynamoDB table definitions saved to {target_template_path}')


def create_dynamodb_local_tables(
    dynamodb_def: dict,
    table_prefix: str,
    endpoint_url: str
):
    """
    Create the tables in the DynamoDB database.
    """
    default_provisioned_throughput = {
        'ReadCapacityUnits': DEFAULT_READ_CAPACITY_UNITS,
        'WriteCapacityUnits': DEFAULT_WRITE_CAPACITY_UNITS
    }
    client = boto3.resource('dynamodb', endpoint_url=endpoint_url)
    item_list = dynamodb_def['ts'].keys()
    for item_name in item_list:
        table_props = dynamodb_def['ts'][item_name]['Properties']
        output_props = dynamodb_def['output'][item_name]
        original_table_name = output_props['Description']
        table_name = f'{table_prefix}{original_table_name}'
        try:
            client.Table(table_name).table_status
            table_exists = True
            if DEBUG:
                print('Dynamodb Table alredy exists: ' + table_name)
        except client.meta.client.exceptions.ResourceNotFoundException:
            table_exists = False
        if table_exists:
            continue
        if DEBUG:
            print('Creating Dynamodb Table: ' + table_name)
        # Create table in Dynamodb
        create_table_params = {
            'TableName': table_name,
            'KeySchema': table_props['KeySchema'],
            'AttributeDefinitions': table_props['AttributeDefinitions'],
            'ProvisionedThroughput': table_props.get(
                'provisioned_throughput', default_provisioned_throughput
            ),
        }
        if table_props.get('GlobalSecondaryIndexes'):
            create_table_params['GlobalSecondaryIndexes'] = \
                table_props.get('GlobalSecondaryIndexes')
        table = client.create_table(**create_table_params)
        # Wait until the table exists.
        table.wait_until_exists()
        # Print out some data about the table.
        if DEBUG:
            print(
                '>>--> Dynamodb Table: ' + table_name +
                ' CREATED! - table.item_count: ' + str(table.item_count)
            )


def generate_dynamodb_cf():
    """
    Generates DynamoDB table definitions for a SAM template.
    """
    print('')
    print('Generating DynamoDB table definitions for SAM template')
    print('')

    if len(sys.argv) < 5:
        print('Usage: python generate_dynamodb_cf.py ' +
              '<base_config_path> <target_template_path> <table_prefix>' +
              ' <create_local_tables>')
        sys.exit(1)

    base_config_path = sys.argv[1]
    target_template_path = sys.argv[2]
    table_prefix = sys.argv[3]
    create_local_tables = sys.argv[4]

    print(f'base_config_path: {base_config_path}')
    print(f'target_template_path: {target_template_path}')
    print(f'table_prefix: {table_prefix}')
    print(f'create_local_tables: {create_local_tables}')
    print('')

    dynamodb_def = generate_dynamodb_definitions(
        basedir=base_config_path,
        table_prefix=table_prefix)
    if create_local_tables == '1':
        create_dynamodb_local_tables(
            dynamodb_def=dynamodb_def,
            table_prefix=table_prefix,
            endpoint_url=os.environ.get('DYNAMODB_LOCAL_ENDPOINT_URL',
                                        'http://127.0.0.1:8000')
        )
    else:
        write_dynamodb_cf_template_file(
            target_template_path=target_template_path,
            dynamodb_def=dynamodb_def,
        )


if __name__ == '__main__':
    generate_dynamodb_cf()
