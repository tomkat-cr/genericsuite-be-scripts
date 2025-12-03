"""
Generates a Postgres tables CloudFormation template from the GenericSuite
configuration .JSON files.

2025-11-30 | CR
"""

import os
import sys
import json
import yaml
import psycopg2

DEBUG = True

START_STRING = """
AWSTemplateFormatVersion: "2010-09-09"

Description: AWS CloudFormation Template to create the """ + \
               """Postgres tables from the GenericSuite configuration.

Metadata:
  License: Apache-2.0

Parameters:
  AppName:
    Description: application name
    Type: String
  AppStage:
    Description: application stage (qa, prod, staging, demo, dev)
    Type: String

"""

END_STRING = """
;
"""


class SubRep(tuple):
    def __new__(cls, a):
        return tuple.__new__(cls, ["", a])

    def __repr__(self):
        return "Sub(%s,%s)" % self


def sub_representer(dumper, data):
    return dumper.represent_scalar("!Sub", "%s%s" % data)


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
    return "".join([word.capitalize() for word in name.split("_")])


class PostgresTableDefinition:
    def __init__(
        self,
        basedir: str,
        table_prefix: str,
        endpoint_url: str,
        db_name: str,
        target_template_path: str
    ):
        self.basedir = basedir
        self.table_prefix = table_prefix
        self.endpoint_url = endpoint_url
        self.db_name = db_name
        self.target_template_path = target_template_path
        self.table_defs = {}
        self.table_extra_cols = {}

    def get_postgres_definition(self, config: dict, json_filename: str
                                ) -> dict:
        """
        Returns Postgres table definition from config.

        E.g.
            AWSTemplateFormatVersion: "2010-09-09"

            Description: 'AWS CloudFormation Sample Template
                Postgres_Secondary_Indexes: Create a Postgres table with local
                and global secondary indexes. **WARNING** This template creates
                an Postgres table. You will be billed for the AWS resources
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
                Description: Name of the newly created Postgres table
                Value: !Ref TableOfBooks
                Export:
                Name: !Sub "${AWS::StackName}-TableName"
        """
        table_name = config.get("table_name")

        if not table_name:
            return {}

        postgres_definition = {}
        definition_name = f"{convert_snake_to_pascal(table_name)}Table"
        postgres_table_name = (
            f"{self.table_prefix}" + "${AppName}_${AppStage}_" +
            f"{table_name}"
        )

        postgres_output = {
            definition_name: {
                "Description": table_name,
                # This gives the error "Template format error:
                #   Outputs name 'xxx_xxxx_xxx' is non alphanumeric."
                "Value": SubRep(postgres_table_name),
                "Export": {
                    # This gives the error "Template format error:
                    #   Output XxxxxTable is malformed. The Name field of every
                    #   Export member must be specified and consist only of
                    #   alphanumeric characters, colons, or hyphens."
                    # "Name": SubRep(f"{postgres_table_name}-TableName")
                    "Name": SubRep(f"{definition_name}Name")
                },
            }
        }

        _ = DEBUG and print(f"Table: {table_name}")
        # _ = DEBUG and print(config)

        field_elements = config.get("fieldElements", [])

        partition_key = None
        partition_key_type = None

        sort_key = None
        sort_key_type = None

        """
        GenericSuite field data types:

        * text: generates a text input field (single line).
        * textarea: generates a textarea input field (multi line).
        * number: generates a number input field (float).
        * integer: generates a integer input field (no decimals).
        * date: generates a date input field (date only).
        * datetime-local: generates a datetime-local input field (date and time).
        * email: generates an email input field (and validates it during the input).
        * label: generates a label with no input field.
        * hr: generates a horizontal rule.
        * _id: generates a hidden input field with the current object's primary key value.
        * select: generates a select input field from a list of options.
        * select_table: generates a select input field from a list of items in a related table.
        * select_component: generates a select input field with a ReactJS component that populates the options from the database.
        * suggestion_dropdown: generates a input field with a suggestion dropdown from the database or a API call. Check the Suggestion Dropdowns section for more details.
        * component: shows a value generated from a ReactJS component.
        """
        mandatory_fields = {
            'creation_date': {
                'type': 'datetime',
            },
            'update_date': {
                'type': 'datetime',
            },
        }

        skip_types = ["label", "hr", "component"]

        """
        Postgres data types:
        https://www.postgresql.org/docs/current/datatype.html
        """

        type_mapping = {
            "array": "json",
            "text": "character varying",
            "textarea": "text",
            "number": "numeric",
            "integer": "bigint",
            "date": "integer",
            "datetime": "integer",
            "datetime-local": "integer",
            "email": "character varying",
            "_id": "character varying",
            "select": "character varying",
            "select_table": "character varying",
            "select_component": "character varying",
            "suggestion_dropdown": "character varying",
        }

        is_main_table = (
            json_filename.replace(".json", "") ==
            config.get("baseUrl", "")
        )
        is_child_listing = config.get("type", "") == "child_listing"
        is_array_sub_type = config.get("subType", "") == "array"
        array_name = config.get("array_name", "")
        parent_table_name = config.get("parentKeyNames", [])[
            0].get("parentUrl", "") if config.get("parentKeyNames") else ""

        if not is_main_table and not is_child_listing:
            _ = DEBUG and print(f"Skipping {json_filename}")
            return {}

        if is_child_listing:
            _ = DEBUG and print(f"Child listing: {json_filename}")
            definition_name = \
                f"{convert_snake_to_pascal(parent_table_name)}Table"
            if not self.table_extra_cols.get(definition_name):
                self.table_extra_cols[definition_name] = []
            if is_array_sub_type:
                self.table_extra_cols[definition_name].append(
                    {
                        "AttributeName": array_name,
                        "AttributeType": type_mapping.get(
                            "array",
                            "character varying"),
                    }
                )
            return {}

        postgres_definition = {
            "Type": "AWS::Postgres::Table",
            "Properties": {
                "TableName": table_name,
                "AttributeDefinitions": [],
                "KeySchema": [],
            },
        }

        for field in field_elements:
            field_name = field.get("name", "")
            field_type = field.get("type", "")

            if field_type in skip_types:
                continue

            if field_name in mandatory_fields:
                del mandatory_fields[field_name]

            _ = DEBUG and field_name.endswith("_repeat") and print(
                f'Field name: {field_name}\n' +
                f'field_name.endswith("_repeat") = {field_name.endswith("_repeat")}\n' +
                f'field_name.replace("_repeat", "") = {field_name.replace("_repeat", "")}\n' +
                f'config.get("passwords", []) = {config.get("passwords", [])}\n'
            )

            if field_name.endswith("_repeat") \
               and field_name.replace("_repeat", "") in \
               config.get("passwords", []):
                continue

            pg_field_type = type_mapping.get(
                field_type, "character varying")

            if field_type == "_id":
                if not partition_key:
                    if field_name == "id":
                        partition_key = "_id"
                    else:
                        partition_key = field_name
                    partition_key_type = pg_field_type
                else:
                    sort_key = field_name
                    sort_key_type = pg_field_type
            else:
                postgres_definition["Properties"]["AttributeDefinitions"] \
                    .append(
                        {
                            "AttributeName": field_name,
                            "AttributeType": pg_field_type,
                        }
                )

        if mandatory_fields:
            for field_name, field_attrs in mandatory_fields.items():
                postgres_definition["Properties"]["AttributeDefinitions"] \
                    .append(
                        {
                            "AttributeName": field_name,
                            "AttributeType": type_mapping.get(
                                field_attrs['type'], "character varying"),
                        }
                )
        if partition_key:
            postgres_definition["Properties"]["AttributeDefinitions"].append(
                {
                    "AttributeName": partition_key,
                    "AttributeType": partition_key_type,
                }
            )
            postgres_definition["Properties"]["KeySchema"].append(
                {
                    "AttributeName": partition_key,
                    "KeyType": "HASH",
                }
            )

        if sort_key:
            postgres_definition["Properties"]["AttributeDefinitions"].append(
                {
                    "AttributeName": sort_key,
                    "AttributeType": sort_key_type,
                }
            )
            postgres_definition["Properties"]["KeySchema"].append(
                {
                    "AttributeName": sort_key,
                    "KeyType": "RANGE",
                }
            )

        if not postgres_definition:
            return {}

        return {
            "ts": {definition_name: postgres_definition},
            "output": postgres_output,
        }

    def generate_postgres_definitions(self):
        """
        Generates Postgres table definitions from frontend and backend
        config files.
        """
        postgres_definitions = {}
        postgres_outputs = {}

        dir_path = os.path.join(self.basedir, "frontend")
        _ = DEBUG and print(f"Start directory: {dir_path}")

        # Read frontend and backend config files
        for root, _, files in os.walk(dir_path):
            for filename in files:
                _ = DEBUG and print(f"File: {filename}")
                if filename.endswith(".json"):
                    # Read frontend config file
                    with open(os.path.join(root, filename), "r",
                              encoding="utf-8") as f:
                        config = json.load(f)
                        # if file exists in backend config, merge them
                        file_path = os.path.join(
                            self.basedir, "backend", filename)
                        if os.path.exists(file_path):
                            with open(file_path, "r", encoding="utf-8") as f:
                                config.update(json.load(f))
                        # Generate Postgres table definition
                        table_definition = self.get_postgres_definition(
                            config, filename)
                        # Add table definition to the list
                        if table_definition:
                            postgres_definitions.update(table_definition["ts"])
                            postgres_outputs.update(table_definition["output"])

        # _ = DEBUG and print("postgres_definitions:", postgres_definitions)
        # _ = DEBUG and print("self.table_extra_cols:", self.table_extra_cols)

        for table_name, extra_cols in self.table_extra_cols.items():
            for col_dict in extra_cols:
                postgres_definitions[table_name]["Properties"]["AttributeDefinitions"] \
                    .append(col_dict)

        self.table_defs = {
            "ts": postgres_definitions,
            "output": postgres_outputs,
        }

    def write_postgres_cf_template_file(self):
        # Open the target template file to write the Postgres table definition
        with open(self.target_template_path, "w", encoding="utf-8") as f:
            # Save the template file
            f.write(START_STRING)
            f.write(convert_json_to_yaml(
                {"Resources": self.table_defs["ts"]}))
            f.write(END_STRING)
            f.write(convert_json_to_yaml(
                {"Outputs": self.table_defs["output"]}))

        print("")
        print(
            f"Postgres table definitions saved to {self.target_template_path}")

    def create_postgres_local_tables(self):
        """
        Create the tables in the Postgres database.
        """
        _ = DEBUG and print("Creating Postgres local tables...")
        _ = DEBUG and print("self.endpoint_url:", self.endpoint_url)
        client = psycopg2.connect(f"{self.endpoint_url}/{self.db_name}")
        _ = DEBUG and print("client:", client)
        item_list = self.table_defs["ts"].keys()
        _ = DEBUG and print("item_list:", item_list)
        for item_name in item_list:
            table_props = self.table_defs["ts"][item_name]["Properties"]
            output_props = self.table_defs["output"][item_name]
            original_table_name = output_props["Description"]
            table_name = original_table_name
            try:
                client.cursor() \
                    .execute(
                        "SELECT table_name FROM information_schema.tables"
                        " WHERE table_schema='public'"
                        " AND table_name='{table_name}';"
                ) \
                    .fetchall()
                if DEBUG:
                    print("Postgres Table alredy exists: " + table_name)
                continue
            except Exception:
                pass
            if DEBUG:
                print("Creating Postgres Table: " + table_name)

            sql = f"CREATE TABLE IF NOT EXISTS {table_name} ("
            for attribute in table_props["AttributeDefinitions"]:
                sql += f"{attribute['AttributeName']} " + \
                    f"{attribute['AttributeType']}, "
            sql = sql[:-2] + ")"
            if DEBUG:
                print("Postgres Table SQL: " + sql)
            try:
                client.cursor().execute(sql)
            except Exception as e:
                print("Postgres Table SQL Error: " + str(e))
                continue

            if table_props.get("KeySchema"):
                sql = f"ALTER TABLE {table_name} ADD PRIMARY KEY ("
                for key in table_props["KeySchema"]:
                    sql += f"{key['AttributeName']}, "
                sql = sql[:-2] + ")"
                if DEBUG:
                    print("Postgres Primary Key SQL: " + sql)
                try:
                    client.cursor().execute(sql)
                except Exception as e:
                    print("Postgres Primary Key SQL Error: " + str(e))
                    continue

            if table_props.get("GlobalSecondaryIndexes"):
                for index in table_props["GlobalSecondaryIndexes"]:
                    sql = "CREATE INDEX IF NOT EXISTS " + \
                        f"{table_name}_{index['IndexName']}" + \
                        f" ON {table_name} ("
                    for key in index["KeySchema"]:
                        sql += f"{key['AttributeName']}, "
                    sql = sql[:-2] + ")"
                    if DEBUG:
                        print("Postgres Secondary Index SQL: " + sql)
                    try:
                        client.cursor().execute(sql)
                    except Exception as e:
                        print("Postgres Secondary Index SQL Error: " + str(e))
                        continue

            client.commit()

            if DEBUG:
                print(
                    ">>--> Postgres Table: "
                    + table_name
                    + " CREATED!"
                )


def generate_postgres_cf():
    """
    Generates Postgres tables.
    """
    print("")
    print("*****************************")
    print("* Postgres Tables Generator *")
    print("*****************************")
    print("")

    if len(sys.argv) < 5:
        print(
            "Usage: python generate_postgres_cf.py "
            + "<base_config_path> <target_template_path> <table_prefix>"
            + " <create_local_tables>"
        )
        sys.exit(1)

    base_config_path = sys.argv[1]
    target_template_path = sys.argv[2]
    table_prefix = sys.argv[3]
    create_local_tables = sys.argv[4]

    print(f"base_config_path: {base_config_path}")
    print(f"target_template_path: {target_template_path}")
    print(f"table_prefix: {table_prefix}")
    print(f"create_local_tables: {create_local_tables}")
    print("")

    ptd = PostgresTableDefinition(
        basedir=base_config_path,
        table_prefix=table_prefix,
        endpoint_url=os.environ.get(
            "POSTGRES_URI", "postgresql://user:pass@localhost:5432"
        ),
        db_name=os.environ.get("POSTGRES_DB", "db"),
        target_template_path=target_template_path,
    )

    ptd.generate_postgres_definitions()

    if create_local_tables == "1":
        ptd.create_postgres_local_tables()
    else:
        ptd.write_postgres_cf_template_file()


if __name__ == "__main__":
    generate_postgres_cf()
