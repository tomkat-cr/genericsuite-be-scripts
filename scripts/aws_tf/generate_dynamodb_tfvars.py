"""
Generates a dynamodb.auto.tfvars.json for the OpenTofu dynamodb stack from
the GenericSuite configuration .JSON files. Reads the same inputs as
scripts/aws_dynamodb/generate_dynamodb_cf/generate_dynamodb_cf.py.
2026-07-16 | CR [GS-334]
"""
import json
import os
import sys


def get_table_definition(config: dict) -> dict:
    """Extract {name, hash_key, range_key} from a GenericSuite config."""
    table_name = config.get('table_name')
    if not table_name:
        return {}
    partition_key = None
    sort_key = None
    for field in config.get('fieldElements', []):
        if field.get('type') == '_id':
            if not partition_key:
                if field.get('name') == 'id':
                    partition_key = '_id'
                else:
                    partition_key = field.get('name')
            else:
                sort_key = field.get('name')
    if not partition_key:
        return {}
    definition = {'name': table_name, 'hash_key': partition_key}
    if sort_key:
        definition['range_key'] = sort_key
    return definition


def generate_tables(basedir: str) -> list:
    tables = []
    dir_path = os.path.join(basedir, 'frontend')
    for root, _, files in os.walk(dir_path):
        for file in sorted(files):
            if not file.endswith('.json'):
                continue
            with open(os.path.join(root, file), 'r', encoding='utf-8') as f:
                config = json.load(f)
            backend_path = os.path.join(basedir, 'backend', file)
            if os.path.exists(backend_path):
                with open(backend_path, 'r', encoding='utf-8') as f:
                    config.update(json.load(f))
            definition = get_table_definition(config)
            if definition:
                tables.append(definition)
    return tables


def main():
    if len(sys.argv) < 3:
        print('Usage: python generate_dynamodb_tfvars.py'
              ' <base_config_path> <output_tfvars_json_path>')
        sys.exit(1)
    base_config_path = sys.argv[1]
    output_path = sys.argv[2]
    tables = generate_tables(base_config_path)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump({'tables': tables}, f, indent=2)
    print(f'{len(tables)} DynamoDB table definitions written to {output_path}')


if __name__ == '__main__':
    main()
