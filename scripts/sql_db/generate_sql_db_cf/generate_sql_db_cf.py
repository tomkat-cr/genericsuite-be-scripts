"""
Generates a Postgres/MySQL tables, SQL and CloudFormation template
from GenericSuite configuration JSON files.

2025-11-30 | CR
"""

from typing import Any
import os
import sys
import json
import yaml
from urllib.parse import urlparse

DEBUG = True

# AWS CloudFormation > Template Reference > AWS::RDS::DBInstance
#   Creating a DB instance with Enhanced Monitoring enabled
# https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-rds-dbinstance.html

START_STRING = """
AWSTemplateFormatVersion: 2010-09-09
Description: >-
  Description": "AWS CloudFormation Sample Template for creating an Amazon RDS DB instance:
  Sample template showing how to create a DB instance with Enhanced Monitoring enabled.
  **WARNING** This template creates an RDS DB instance. You will be billed for the AWS
  resources used if you create a stack from this template.
Parameters:
  DBInstanceID:
    Default: mydbinstance
    Description: My database instance
    Type: String
    MinLength: '1'
    MaxLength: '63'
    AllowedPattern: '[a-zA-Z][a-zA-Z0-9]*'
    ConstraintDescription: >-
      Must begin with a letter and must not end with a hyphen or contain two
      consecutive hyphens.
  DBName:
    Default: mydb
    Description: My database
    Type: String
    MinLength: '1'
    MaxLength: '64'
    AllowedPattern: '[a-zA-Z][a-zA-Z0-9]*'
    ConstraintDescription: Must begin with a letter and contain only alphanumeric characters.
  DBInstanceClass:
    Default: db.m5.large
    Description: DB instance class
    Type: String
    ConstraintDescription: Must select a valid DB instance type.
  DBAllocatedStorage:
    Default: '50'
    Description: The size of the database (GiB)
    Type: Number
    MinValue: '20'
    MaxValue: '65536'
    ConstraintDescription: must be between 20 and 65536 GiB.
  DBUsername:
    NoEcho: 'true'
    Description: Username for MySQL database access
    Type: String
    MinLength: '1'
    MaxLength: '16'
    AllowedPattern: '[a-zA-Z][a-zA-Z0-9]*'
    ConstraintDescription: must begin with a letter and contain only alphanumeric characters.
  DBPassword:
    NoEcho: 'true'
    Description: Password MySQL database access
    Type: String
    MinLength: '8'
    MaxLength: '41'
    AllowedPattern: '[a-zA-Z0-9]*'
    ConstraintDescription: must contain only alphanumeric characters.
Resources:
  MyDB:
    Type: 'AWS::RDS::DBInstance'
    Properties:
      DBInstanceIdentifier: !Ref DBInstanceID
      DBName: !Ref DBName
      DBInstanceClass: !Ref DBInstanceClass
      AllocatedStorage: !Ref DBAllocatedStorage
      Engine: MySQL
      EngineVersion: "8.0.33"
      MasterUsername: !Ref DBUsername
      MasterUserPassword: !Ref DBPassword
      MonitoringInterval: 60
      MonitoringRoleArn: 'arn:aws:iam::123456789012:role/rds-monitoring-role'

"""  # noqa: E501

END_STRING = """
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
        db_type: str,
        db_endpoint_url: str,
        db_name: str,
        target_template_path: str,
    ):
        self.basedir = basedir
        self.table_prefix = table_prefix
        self.db_type = db_type
        self.db_endpoint_url = db_endpoint_url
        self.db_name = db_name
        self.target_template_path = target_template_path
        self.table_defs = {}
        self.table_extra_cols = {}

    def get_postgres_client(self) -> Any:
        import psycopg2
        client = psycopg2.connect(f"{self.db_endpoint_url}/{self.db_name}")
        return client

    def get_posrgres_cursor(self) -> Any:
        return self.get_postgres_client().cursor()

    def get_mysql_client(self) -> Any:
        import mysql.connector
        # Parse the URI
        # Format: mysql://user:password@host:port
        parsed_uri = urlparse(self.db_endpoint_url)
        config = {
            'user': parsed_uri.username,
            'password': parsed_uri.password,
            'host': parsed_uri.hostname,
            'port': parsed_uri.port or 3306,
            'database': self.db_name
        }
        return mysql.connector.connect(**config)

    def get_postgres_cursor(self, client: Any = None) -> Any:
        if client is None:
            client = self.get_postgres_client()
        return client.cursor()

    def get_mysql_cursor(self, client: Any = None) -> Any:
        if client is None:
            client = self.get_mysql_client()
        return client.cursor(dictionary=True)

    def get_type_mapping(self) -> dict:
        if self.db_type == "postgres":
            """
            Postgres data types:
            https://www.postgresql.org/docs/current/datatype.html
            """
            return {
                "array": "json",
                "text": "character varying",
                "textarea": "text",
                "number": "numeric",
                "integer": "bigint",
                "date": "numeric",
                "datetime": "numeric",
                "datetime-local": "numeric",
                "email": "character varying",
                "_id": "character(30)",
                "select": "character varying",
                "select_table": "character varying",
                "select_component": "character varying",
                "suggestion_dropdown": "character varying",
                "default_type": "character varying",
            }
        if self.db_type == "mysql":
            """
            MySQL data types:
            https://dev.mysql.com/doc/en/data-types.html
            https://www.w3schools.com/mysql/mysql_datatypes.asp
            """
            return {
                "array": "JSON",
                "text": "LONGTEXT",
                "textarea": "LONGTEXT",
                "number": "DOUBLE(53, 10)",
                "integer": "BIGINT(100)",
                "date": "FLOAT(20, 10)",      # e.g. 1557990717.6383634
                "datetime": "FLOAT(20, 10)",
                "datetime-local": "FLOAT(20, 10)",
                "email": "VARCHAR(255)",
                "_id": "CHAR(30)",
                "select": "VARCHAR(100)",
                "select_table": "VARCHAR(100)",
                "select_component": "VARCHAR(100)",
                "suggestion_dropdown": "VARCHAR(100)",
                "default_type": "VARCHAR(255)",
            }
        return None

    def get_table_definition(self, config: dict, json_filename: str
                             ) -> dict:
        """
        Returns Postgres table definition from config.

        E.g.
            TableOfBooks:
                Type: AWS::Postgres::Table
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

        type_mapping = self.get_type_mapping()
        default_col_type = type_mapping["default_type"]

        table_definition = {}
        definition_name = f"{convert_snake_to_pascal(table_name)}Table"
        db_table_name = (
            f"{self.table_prefix}" + "${AppName}_${AppStage}_" +
            f"{table_name}"
        )

        postgres_output = {
            definition_name: {
                "Description": table_name,
                # This gives the error "Template format error:
                #   Outputs name 'xxx_xxxx_xxx' is non alphanumeric."
                "Value": SubRep(db_table_name),
                "Export": {
                    # This gives the error "Template format error:
                    #   Output XxxxxTable is malformed. The Name field of every
                    #   Export member must be specified and consist only of
                    #   alphanumeric characters, colons, or hyphens."
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
        * datetime-local: generates a datetime-local input field (date and
            time).
        * email: generates an email input field (and validates it during the
            input).
        * label: generates a label with no input field.
        * hr: generates a horizontal rule.
        * _id: generates a hidden input field with the current object's
            primary key value.
        * select: generates a select input field from a list of options.
        * select_table: generates a select input field from a list of items in
            a related table.
        * select_component: generates a select input field with a ReactJS
            component that populates the options from the database.
        * suggestion_dropdown: generates a input field with a suggestion
            dropdown from the database or a API call.
        * component: shows a value generated from a ReactJS component.
        """
        mandatory_fields = {
            'creation_date': {
                'type': type_mapping['datetime-local'],
            },
            'update_date': {
                'type': type_mapping['datetime-local'],
            },
        }

        skip_types = ["label", "h1", "h2", "h3",
                      "h4", "h5", "h6", "hr", "component"]

        is_main_table = (
            json_filename.replace(".json", "") ==
            config.get("baseUrl", "")
        )
        is_child_listing = config.get("type", "") == "child_listing"
        is_array_sub_type = config.get("subType", "") == "array"
        array_name = config.get("array_name", "")
        parent_table_name = config.get("parentUrl", "")
        # parent_table_name = config.get("endpointKeyNames", [])[
        #     0].get("parentUrl", "") if config.get("endpointKeyNames") else ""

        if not is_main_table and not is_child_listing:
            _ = DEBUG and print(f"Skipping {json_filename}")
            return {}

        if is_child_listing:
            _ = DEBUG and print(
                "Child listing:" +
                f"\n  subType: {config.get('subType', '')}" +
                f"\n  array_name: {array_name}" +
                f"\n  parent_table_name: {parent_table_name}")

            if is_array_sub_type:
                definition_name = \
                    f"{convert_snake_to_pascal(parent_table_name)}Table"

                if not self.table_extra_cols.get(definition_name):
                    self.table_extra_cols[definition_name] = []

                self.table_extra_cols[definition_name].append(
                    {
                        "AttributeName": array_name,
                        "AttributeType": type_mapping["array"],
                    }
                )

                return {}

        table_definition = {
            "Type": f"AWS::{self.db_type.capitalize()}::Table",
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

            if field_name.endswith("_repeat") \
               and field_name.replace("_repeat", "") in \
               config.get("passwords", []):
                continue

            pg_field_type = type_mapping.get(
                field_type, default_col_type)

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
                table_definition["Properties"]["AttributeDefinitions"] \
                    .append(
                        {
                            "AttributeName": field_name,
                            "AttributeType": pg_field_type,
                        }
                )

        if mandatory_fields:
            for field_name, field_attrs in mandatory_fields.items():
                table_definition["Properties"]["AttributeDefinitions"] \
                    .append(
                        {
                            "AttributeName": field_name,
                            "AttributeType": type_mapping.get(
                                field_attrs['type'], default_col_type),
                        }
                )
        if partition_key:
            table_definition["Properties"]["AttributeDefinitions"].append(
                {
                    "AttributeName": partition_key,
                    "AttributeType": partition_key_type,
                }
            )
            table_definition["Properties"]["KeySchema"].append(
                {
                    "AttributeName": partition_key,
                    "KeyType": "HASH",
                }
            )

        if sort_key:
            table_definition["Properties"]["AttributeDefinitions"].append(
                {
                    "AttributeName": sort_key,
                    "AttributeType": sort_key_type,
                }
            )
            table_definition["Properties"]["KeySchema"].append(
                {
                    "AttributeName": sort_key,
                    "KeyType": "RANGE",
                }
            )

        if not table_definition:
            return {}

        return {
            "ts": {definition_name: table_definition},
            "output": postgres_output,
        }

    def get_sql_statements(self) -> list:
        sql_statements = []

        item_list = self.table_defs["ts"].keys()
        for item_name in item_list:

            _ = DEBUG and print(f"\nItem name: {item_name}")

            table_props = self.table_defs["ts"][item_name]["Properties"]
            output_props = self.table_defs["output"][item_name]
            table_name = output_props["Description"]

            sql_statements.append(
                "# -- Table: " + table_name
            )

            sql = f"CREATE TABLE IF NOT EXISTS {table_name} ("
            for attribute in table_props["AttributeDefinitions"]:
                sql += f"{attribute['AttributeName']} " + \
                    f"{attribute['AttributeType']}, "
            sql = sql[:-2] + ")"
            sql_statements.append(sql)

            if table_props.get("KeySchema"):
                sql = f"ALTER TABLE {table_name} ADD PRIMARY KEY ("
                for key in table_props["KeySchema"]:
                    sql += f"{key['AttributeName']}, "
                sql = sql[:-2] + ")"
                sql_statements.append(sql)

            if table_props.get("GlobalSecondaryIndexes"):
                for index in table_props["GlobalSecondaryIndexes"]:
                    sql = "CREATE INDEX IF NOT EXISTS " + \
                        f"{table_name}_{index['IndexName']}" + \
                        f" ON {table_name} ("
                    for key in index["KeySchema"]:
                        sql += f"{key['AttributeName']}, "
                    sql = sql[:-2] + ")"
                    sql_statements.append(sql)

        return sql_statements

    def generate_db_definitions(self):
        """
        Generates Postgres table definitions from frontend and backend
        config files.
        """
        table_definitions = {}
        postgres_outputs = {}

        dir_path = os.path.join(self.basedir, "frontend")
        _ = DEBUG and print(f"Start directory: {dir_path}")

        # Read frontend and backend config files
        for root, _, files in os.walk(dir_path):
            for filename in files:
                _ = DEBUG and print(f"\nFile: {filename}")
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
                        table_definition = self.get_table_definition(
                            config, filename)
                        # Add table definition to the list
                        if table_definition:
                            table_definitions.update(table_definition["ts"])
                            postgres_outputs.update(table_definition["output"])

        # _ = DEBUG and print("\ntable_definitions:", table_definitions)
        _ = DEBUG and print("\nself.table_extra_cols:", self.table_extra_cols)

        for table_name, extra_cols in self.table_extra_cols.items():
            for col_dict in extra_cols:
                try:
                    table_definitions.get(
                        table_name
                    )["Properties"]["AttributeDefinitions"] \
                        .append(col_dict)
                except Exception as e:
                    _ = DEBUG and print(
                        f"Error adding column {col_dict} to table"
                        f" {table_name}: {e}")

        self.table_defs = {
            "ts": table_definitions,
            "output": postgres_outputs,
        }

    def write_cf_template_file(self):
        sql_statements = self.get_sql_statements()

        # Open the target template file to write the Postgres table definition
        with open(self.target_template_path, "w", encoding="utf-8") as f:
            f.write(START_STRING)
            f.write("\n")
            for sql_statement in sql_statements:
                if sql_statement.startswith("#"):
                    f.write("\n")
                    f.write(sql_statement + "\n")
                else:
                    f.write("\n# " + sql_statement + ";\n")
            f.write("\n")
            f.write(END_STRING)

        print("")
        print(
            f"Postgres table definitions saved to {self.target_template_path}")

    def get_postgres_table_list(self):
        """
        Get the list of tables in the Postgres database.
        """
        _ = DEBUG and print("Getting Postgres table list...")
        _ = DEBUG and print("self.db_endpoint_url:", self.db_endpoint_url)
        cursor = self.get_postgres_cursor()
        return cursor.execute(
            "SELECT table_name FROM information_schema.tables"
            " WHERE table_schema='public';"
        ).fetchall()

    def get_mysql_table_list(self):
        """
        Get the list of tables in the MySQL database.
        """
        _ = DEBUG and print("Getting MySQL table list...")
        _ = DEBUG and print("self.db_endpoint_url:", self.db_endpoint_url)
        cursor = self.get_mysql_cursor()
        return cursor.execute(
            "SELECT table_name FROM information_schema.tables"
            " WHERE table_schema='public';"
        ).fetchall()

    def get_db_table_list(self):
        """
        Get the list of tables in the Postgres database.
        """
        if self.db_type == "postgres":
            return self.get_postgres_table_list()
        if self.db_type == "mysql":
            return self.get_mysql_table_list()
        raise ValueError(f"Unknown database type: {self.db_type} [GDTL-010]")

    def create_db_tables(self):
        """
        Create the tables in the Postgres database.
        """
        if self.db_type == "postgres":
            client = self.get_postgres_client()
            cursor = self.get_postgres_cursor(client)
        elif self.db_type == "mysql":
            client = self.get_mysql_client()
            cursor = self.get_mysql_cursor(client)
        else:
            raise ValueError(
                f"Unknown database type: {self.db_type} [CDT-010]")

        item_list = self.table_defs["ts"].keys()
        _ = DEBUG and print("item_list:", item_list)

        sql_statements = self.get_sql_statements()
        for sql_statement in sql_statements:
            if sql_statement.startswith("#"):
                print(sql_statement)
                continue
            try:
                if DEBUG:
                    print("\nPostgres SQL:\n" + sql_statement)
                cursor.execute(sql_statement)
            except Exception as e:
                print("\nPostgres SQL Error:\n" + str(e))
                continue
            client.commit()


def get_db_config(db_type: str) -> dict:
    """
    Get the database configuration.
    """
    if db_type == "postgres":
        return {
            "APP_DB_URI": os.environ.get(
                "APP_DB_URI", "postgresql://user:pass@localhost:5432"
            ),
            "APP_DB_NAME": os.environ.get("APP_DB_NAME", "db"),
        }
    elif db_type == "mysql":
        return {
            "APP_DB_URI": os.environ.get(
                "APP_DB_URI", "mysql://user:pass@localhost:3306"
            ),
            "APP_DB_NAME": os.environ.get("APP_DB_NAME", "db"),
        }
    else:
        raise ValueError("Invalid database type")


def generate_sql_db_cf():
    """
    Generates Postgres/MySQL tables.
    """
    print("")
    print("***********************************")
    print("* Postgres/MySQL Tables Generator *")
    print("***********************************")
    print("")

    if len(sys.argv) < 6:
        print(
            "Usage: python generate_sql_db_cf.py "
            + "<base_config_path> <target_template_path> <table_prefix>"
            + " <create_local_tables> <db_type>"
        )
        sys.exit(1)

    base_config_path = sys.argv[1]
    target_template_path = sys.argv[2]
    table_prefix = sys.argv[3]
    create_local_tables = sys.argv[4]
    db_type = sys.argv[5].lower()

    print(f"base_config_path: {base_config_path}")
    print(f"target_template_path: {target_template_path}")
    print(f"table_prefix: {table_prefix}")
    print(f"create_local_tables: {create_local_tables}")
    print(f"db_type: {db_type}")
    print("")

    db_config = get_db_config(db_type)
    print(f"db_config: {db_config}")

    ptd = PostgresTableDefinition(
        basedir=base_config_path,
        table_prefix=table_prefix,
        db_type=db_type,
        db_endpoint_url=db_config["APP_DB_URI"],
        db_name=db_config["APP_DB_NAME"],
        target_template_path=target_template_path,
    )

    ptd.generate_db_definitions()

    if create_local_tables == "1":
        ptd.create_db_tables()
    elif create_local_tables == "2":
        ptd.get_db_table_list()
    else:
        ptd.write_cf_template_file()


if __name__ == "__main__":
    generate_sql_db_cf()
