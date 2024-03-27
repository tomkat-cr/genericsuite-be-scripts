# The GenericSuite Scripts (backend version).

![GenericSuite Logo](https://github.com/tomkat-cr/genericsuite-fe/blob/main/src/lib/images/gs_logo_circle.png)

GenericSuite is a versatile backend solution, designed to provide a comprehensive suite of features for Python APIs. It supports various frameworks including Chalice, FastAPI, and Flask, making it adaptable to a range of projects.<be/>
This repository contains the backend scripts necessary to build and deploy APIs made by the backend version of The GenericSuite.

## Features

- **AWS Deployment**: Deployment to AWS as Lambda Function with API Gateway.
- **Local Development Environment**: running with http or https, with or without Docker.
- **Local DNS Server**: to allow https API access with a domain name like `app.exampleapp.local` and allow access from another devices locally (e.g. smartphones) to test your App.

## Pre-requisites

- Refer to [The GenericSuite pre-requisites](https://github.com/tomkat-cr/genericsuite-be?tab=readme-ov-file#pre-requisites).
- For AI APIs refer to [The GenericSuite AI installation guide](https://github.com/tomkat-cr/genericsuite-be-ai?tab=readme-ov-file#installation).

## Getting Started

To get started with GenericSuite, follow these steps:

1. **Initiate your project**

    Refer to [The GenericSuite Getting Started guide](https://github.com/tomkat-cr/genericsuite-be?tab=readme-ov-file#getting-started).

2. **Install the GenericSuite Backend Scripts**

   ```bash
   npm install -D genericsuite-be-scripts
   ```

3. **Prepare the Makefile**

   Copy the `Makefile` template from `node_modules/genericsuite-be-scripts`:

   ```bash
   cp node_modules/genericsuite-be-scripts/Makefile ./Makefile
   ```
   
   Open the `Makefile` and replace all `scripts/` with  `node_modules/genericsuite-be-scripts/scripts/`

   ```bash
   vi ./Makefile
   # or
   code ./Makefile
   ```

4. **Prepare the AWS/SAM templates**

   Create the project's `scripts/aws_big_lambda` directory.

   ```bash
   mkdir -p scripts/aws_big_lambda
   ```

   Copy the Templates.

   ```bash
   cp node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/template-samconfig.toml ./scripts/aws_big_lambda/
   ```
   ```bash
   cp node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/template-sam.yml ./scripts/aws_big_lambda/
   ```

   Edit the `template-samconfig.toml`.

   ```bash
   vi scripts/aws_big_lambda/template-samconfig.toml
   # or
   code scripts/aws_big_lambda/template-samconfig.toml
   ```

   Check for some customization needed.

   The deployment script [big_lambdas_manager.sh](https://github.com/tomkat-cr/genericsuite-be-scripts/blob/main/scripts/aws_big_lambda/big_lambdas_manager.sh) will replace `APP_NAME_LOWERCASE_placeholder` with the Applicacion name defined in the `APP_NAME` variable in `.env` file.

   Edit the `template-sam.yml`.

   ```bash
   vi scripts/aws_big_lambda/template-sam.yml
   # or
   code scripts/aws_big_lambda/template-sam.yml
   ```

   In this file is where the endpoints are defined, as well as other SAM deployment elements. Customize it as you needed.

   You can find a endpoint definition template in the file [node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/template-sam-endpoint-entry.yml](https://github.com/tomkat-cr/genericsuite-be-scripts/blob/main/scripts/aws_big_lambda/template-sam-endpoint-entry.yml).

   Be carefull about elements ending with `_placeholder` because they are replaced by the deployment script `big_lambdas_manager.sh` with the corresponding values.

   If you're going to develop with the Chalice framework:

   Create the `.chalice` directory.

   ```bash
   mkdir -p .chalice
   ```

   Copy the `.chalice/config-example.json` template file.

   ```bash
   cp node_modules/genericsuite-be-scripts/.chalice/config-example.json ./.chalice/
   ```

## Start Development Server

To start the development server for the `dev` stage and a local docker MongoDB container:

   ```bash
   make run
   ```

To start the development server for the `qa` stage and MongoDB Atlas:

   ```bash
   make run_qa
   ```

When there are changes to the dependencies or `.env` file, restart the local development server:

   ```bash
   make restart_qa
   ```

## Deploy QA

To perform a QA deployment as an AWS Lambda Function and AWS API Gateway:

   ```bash
   make deploy_qa
   ```

## Install dependecies

Install default package categories from Pipfile.<br/>
Runs `pipenv install`.<br/>
Reference: https://pipenv.pypa.io/en/latest/commands.html#install

```bash
make install
```

Install both develop and default package categories from Pipfile.<br/>
Runs `pipenv install --dev`.

```bash
make install_dev
```

Install from the Pipfile.lock and completely ignore Pipfile information.<br/>
Runs `pipenv install --ignore-pipfile`.

```bash
make locked_install
```

Install both develop and default package categories from the Pipfile.lock and completely ignore Pipfile information.<br/>
Runs `pipenv install --dev --ignore-pipfile`.

```bash
make locked_dev
```

Generates the `requirements.txt` file.<br/>
Runs `sh scripts/aws/run_aws.sh pipfile`.

```bash
make requirements
```
or...
```bash
make lock_pip_file
```

Clean install.<br/>
Alias that runs `make clean_rm` and `make install`.

```bash
make fresh
```

## Cleaning

Alias to run `make clean_rm`, `make clean_temp_dir`, and `make clean_logs`.

```bash
make clean
```

Remove a virtualenv created by "pipenv run".<br/>
Runs `pipenv --rm`.

```bash
make clean_rm
```

Clean logs (in /logs directory).<br/>
Runs sh `scripts/clean_logs.sh`.

```bash
make clean_logs
```

Clean logs, cache and temporary files.<br/>
Runs `sh scripts/aws/run_aws.sh clean`.

```bash
make clean_temp_dir
```

## CLI Utilities

Install development tools (pyenv, pipenv, make, and optionally: poetry, saml2aws).<br/>
Check [node_modules/genericsuite-be-scripts/scripts/install_dev_tools.sh](https://github.com/tomkat-cr/genericsuite-be-scripts/blob/main/scripts/install_dev_tools.sh) for more details about how to configure via `.env` file.

```bash
make install_tools
```

Show ports in use.<br/>
Runs `sh scripts/run_lsof.sh`.

```bash
make lsof
```

## Automated Testing

Start the local MongoDB docker container and run the tests.<br/>
Runs `sh scripts/run_app_tests.sh`.

```bash
make test
```

Execute the test without starting the local MongoDB docker container.<br/>
Runs `sh scripts/aws/run_tests.sh`.

```bash
make test_only
```

## Linting

Execute Prospector.<br/>
Runs `pipenv run prospector`.

```bash
make lint
```

Execute MyPy.<br/>
Runs `pipenv run mypy .`.

```bash
make types
```

Execute Coverage.<br/>
Runs `pipenv run coverage run -m unittest discover tests` and `pipenv run coverage report`.

```bash
make coverage
```

Execute Yapf Formatter and PyCodeStyle.<br/>
Runs `pipenv run yapf -i *.py **/*.py **/**/*.py` and `pycodestyle`.<br/>
References:<br/>
[https://github.com/google/yapf](https://github.com/google/yapf)<br/>
[https://pycodestyle.pycqa.org/en/latest/](https://pycodestyle.pycqa.org/en/latest/)<br/>

```bash
make format
```

Execute Yapf (print the diff for the fixed source) and PyCodeStyle.<br/>
Runs `pipenv run yapf --diff *.py **/*.py **/**/*.py` and `pycodestyle`.

```bash
make format_check
```

## Development Commands

Perform a complete Lint, Type check, unit and integration test, format check and styling before deployments.<br/>
Alias to run `make lint`, `make types`, `make tests`, `make format_check`, and `make pycodestyle`.

```bash
make qa
```

Start the local MongoDB docker container (used for testing and `dev` stage run).<br/>
Runs `sh scripts/mongo/run_mongo_docker.sh run`.

```bash
make mongo_docker
```

Stop the local MongoDB docker container.<br/>
Runs `sh scripts/mongo/run_mongo_docker.sh down`

```bash
make mongo_docker_down
```

## Chalice Specific Commands

Set parameters on `.chalice/config.json` as the production stage.<br/>
Runs `sh scripts/aws/update_config.sh prod`.

```bash
make config
```

Set parameters on `.chalice/config.json` with no specific stage.<br/>
Runs `sh scripts/aws/update_config.sh`.

```bash
make config_dev
```

Set parameters on `.chalice/config.json` as the Development stage.<br/>
Runs `sh scripts/aws/update_config.sh mongo_docker`.

```bash
make config_local
```

Set parameters on `.chalice/config.json` as the QA stage with CORS specific variables replacement to allow use the QA live database from the local development environment.<br/>
References: `APP_CORS_ORIGIN_QA_CLOUD`, `APP_CORS_ORIGIN_QA_LOCAL` in the [.env.example file](https://github.com/tomkat-cr/genericsuite-be/blob/main/.env.example).<br/>
Runs `sh scripts/aws/update_config.sh qa`.

```bash
make config_qa
```

Set parameters on `.chalice/config.json` to prepare the QA deployment.<br/>
Runs `sh scripts/aws/update_config.sh qa deploy`,

```bash
make config_qa_for_deployment
```

Set parameters on `.chalice/config.json` as the Staging stage.<br/>
Runs `sh scripts/aws/update_config.sh staging`.

```bash
make config_staging
```

Create the AWS Stack via Chalice command.<br/>
Runs `sh scripts/aws/run_aws.sh create_stack`.

```bash
make build
```

Generates the `requirements.txt`.<br/>
Runs `sh scripts/aws/run_aws.sh pipfile`.

```bash
make build_local
```

Describe the AWS stack with the Chalice command.<br/>
Runs `sh scripts/aws/run_aws.sh describe_stack`.

```bash
make build_check
```

Alias to run `make unbuild_qa`.

```bash
make unbuild
```

Delete the Chalice QA App.<br/>
Runs `sh scripts/aws/run_aws.sh delete_app qa`.

```bash
make unbuild_qa
```

Delete the Chalice Staging App.<br/>
Runs `sh scripts/aws/run_aws.sh delete_app staging`

```bash
make unbuild_staging
```

Delete the AWS stack created by Chalice.<br/>
Runs `sh scripts/aws/run_aws.sh delete_stack`

```bash
make delete_stack
```

## AWS S3 and other

Create a default `${HOME}/.aws/config` AWS configuration.<br/>
Runs `sh scripts/aws/create_aws_config.sh`.

```bash
make create_aws_config
```

Create the S3 Development buckets.<br/>
Runs `sh scripts/aws/create_chatbot_s3_bucket.sh dev`.

```bash
make create_s3_bucket_dev
```

Create the S3 QA buckets.<br/>
Runs `sh scripts/aws/create_chatbot_s3_bucket.sh qa`.

```bash
make create_s3_bucket_qa
```

Create the S3 Staging buckets.<br/>
Runs `sh scripts/aws/create_chatbot_s3_bucket.sh staging`.

```bash
make create_s3_bucket_staging
```

Create the S3 Production buckets.<br/>
Runs `sh scripts/aws/create_chatbot_s3_bucket.sh prod`.

```bash
make create_s3_bucket_prod
```

## Deployment

Deploy the App on QA.<br/>
Runs `make create_s3_bucket_qa`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy qa`

```bash
make deploy_qa
```

Validate the SAM deployment templates on QA.<br/>
Runs `make create_s3_bucket_qa`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_validate qa`

```bash
make deploy_validate_qa
```

Create the deployment QA package only.<br/>
Usefull to check the package size and test the image by a local Docker run.<br/>
Runs `make create_s3_bucket_qa`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh package qa`.

```bash
make deploy_package_qa
```

Deploy the App on Staging.<br/>
Runs `make create_s3_bucket_staging`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy staging` 

```bash
make deploy_staging
```

Deploy the App on Production.<br/>
Runs `make create_s3_bucket_prod`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy prod`

```bash
make deploy_prod
```

Alias to run `make deploy_qa`.

```bash
make deploy
```

## Application Specific Commands

Execute the App locally using the development database, asking to run it over `http` or `https`.<br/>
Runs `make config_qa`, `make clean_logs`, and `sh scripts/aws/run_aws.sh run_local`.
[???]

```bash
make run
```

Execute the App locally using the QA database, asking to run it over `http` or `https`.<br/>
Runs `make config_qa`, `make clean_logs`, and `sh scripts/aws/run_aws.sh run_local qa`.

```bash
make run_qa
```

Runs `make config_qa`, `make clean_logs`, and `sh scripts/secure_local_server/run.sh "down" ""`
Stop and destroy the App local Docker container (for any running stage).<br/>

```bash
make down_qa
```

Restart the App local Docker container running over QA.<br/>
Runs `make config_qa`, `make clean_logs`, `sh scripts/secure_local_server/run.sh "down" ""` and `sh scripts/aws/run_aws.sh run_local qa`.

```bash
make restart_qa
```

Execute the app locally using the development database (in a local Docker container), asking to execute it over `http` or `https`.<br/>
Runs `make config_local`, `make clean_logs`, `sh scripts/aws/run_aws.sh run_local dev`.
[???]

```bash
make run_local_docker
```

Execute `chalice local --port \$PORT --stage PROD`<br/>
Runs `make config`, `make clean_logs`, `sh scripts/aws/run_aws.sh run`.

```bash
make run_prod
```

## Common JSON config

Add the Git Submodule with the common JSON config directories.<br/>
Runs `sh scripts/add_github_submodules.sh`.

```bash
make add_submodules
```

# Local DNS server

Start the local DNS server.<br/>
Runs `sh scripts/dns/run_local_dns.sh`

```bash
make local_dns
```

Runs `sh scripts/dns/run_local_dns.sh restart` to restart the local DNS server.<br/>

```bash
make local_dns_restart
```

Restart and rebuild the local DNS server configuration when the local IP or any DNS parameters has been changed.<br/>
Runs `sh scripts/dns/run_local_dns.sh rebuild`

```bash
make local_dns_rebuild
```

Stop and destroy the local DNS server.<br/>
Runs `sh scripts/dns/run_local_dns.sh down`.

```bash
make local_dns_down
```

Test the local DNS server.<br/>
Runs `sh scripts/dns/run_local_dns.sh test`.

```bash
make local_dns_test
```

## Self-signed local SSL certificates

Create the self-signed local SSL certificates (required to run the local develpment frotend and backend over https).<br/>
Runs `sh scripts/local_ssl_certs_creation.sh`.

```bash
make create_ssl_certs_only
```

Copy the self-signed local SSL certificates to the frontend directory/local repository.<br/>
Runs `sh scripts/local_ssl_certs_copy.sh`.

```bash
make copy_ssl_certs
```

Alias to run `make create_ssl_certs_only` and `make copy_ssl_certs`.<br/>

```bash
make create_ssl_certs
```

# NPM library scripts

Update the package.json file with the version and all other parameters except dependecies.<br/>
Runs `npm install --package-lock-only`.

```bash
make lock
```

Test the publish to NPMJS without actually publishing.<br/>
Runs `sh scripts/npm_publish.sh pre-publish`.

```bash
make pre-publish
```

Publish the scripts library to NPMJS.<br/>
Runs `sh scripts/npm_publish.sh publish`.
Requirements:<br/>
[NpmJS Account](https://www.npmjs.com/signup)

```bash
make publish
```

# Pypi library scripts

Build 'dist' directory needed for the Pypi publish.<br/>
Runs `poetry lock --no-update`, `rm -rf dist` and `python3 -m build`.
Requirements:<br/>
[poetry](https://python-poetry.org/)

```bash
make pypi-build
```

Pypi Test publish.<br/>
Runs `make pypi-build`, and `python3 -m twine upload --repository testpypi dist/*`.
Requirements:<br/>
[twine](https://pypi.org/project/twine/)
[TestPypi Account](https://test.pypi.org/account/register/)

```bash
make pypi-publish-test
```

Pypi Production publish<br/>
Runs `make pypi-build`, and `python3 -m twine upload dist/*`.
Requirements:<br/>
[twine](https://pypi.org/project/twine/)
[Pypi Account](https://www.pypi.org/account/register/)

```bash
make pypi-publish
```

# ..............

## License

GenericSuite is open-sourced software licensed under the ISC license.

## Credits

This project is developed and maintained by Carlos J. Ramirez. For more information or to contribute to the project, visit [The GenericSuite Scripts (backend version) on GitHub](https://github.com/tomkat-cr/genericsuite-be-scripts).

Happy Coding!