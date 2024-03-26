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

   The deployment script `big_lambdas_manager.sh` will replace `APP_NAME_LOWERCASE_placeholder` with the Applicacion name defined in the `APP_NAME` variable in `.env` file.

   Edit the `template-sam.yml`.

   ```bash
   vi scripts/aws_big_lambda/template-sam.yml
   # or
   code scripts/aws_big_lambda/template-sam.yml
   ```

   In that file is where the endpoints are defined, as well as other SAM deployment elements. Customize it as you needed.

   You can find a endpoint definition template in the file `node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/template-sam-endpoint-entry.yml`.

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

Runs `pipenv install`.

```bash
make install
```

Runs `pipenv install --dev`.

```bash
make install_dev
```

Runs `pipenv install --dev --ignore-pipfile`.

```bash
make locked_dev
```

Runs `pipenv install --ignore-pipfile`.

```bash
make locked_install
```

Generates the `requirements.txt` file by running `sh scripts/aws/run_aws.sh pipfile`.

```bash
make requirements
```
or...
```bash
make lock_pip_file
```

## Cleaning

Alias to run `make clean_rm`, `make clean_temp_dir`, and `make clean_logs`.

```bash
make clean
```

Runs `pipenv --rm` to remove a virtualenv created by "pipenv run".

```bash
make clean_rm
```

Runs `sh scripts/aws/run_aws.sh clean` to clean logs, cache and temporary files.

```bash
make clean_temp_dir
```

Runs sh `scripts/clean_logs.sh` to clean logs.

```bash
make clean_logs
```

Runs `make clean_rm` and `make install` to have a clean install.

```bash
make fresh
```

## CLI Utilities

Install development tools (pyenv, pipenv, make, and optionally: poetry, saml2aws).<br/>
Check `node_modules/genericsuite-be-scripts/scripts/install_dev_tools.sh` for more details about how to configure via `.env` file.

```bash
make install_tools
```

Runs `sh scripts/run_lsof.sh` to check ports in use.

```bash
make lsof
```

## Automated Testing

Runs `sh scripts/run_app_tests.sh` to start the local MongoDB docker container and run the tests.

```bash
make test
```

Runs `sh scripts/aws/run_tests.sh` to execute the test without starting the local MongoDB docker container.

```bash
make test_only
```

## Linting

Runs `pipenv run prospector`.

```bash
make lint
```

Runs `pipenv run mypy .`.

```bash
make types
```

Runs `pipenv run coverage run -m unittest discover tests` and `pipenv run coverage report`.

```bash
make coverage
```

Runs `pipenv run yapf -i *.py **/*.py **/**/*.py` and `pycodestyle`.

```bash
make format
```

Runs `pipenv run yapf --diff *.py **/*.py **/**/*.py` and `pycodestyle`.

```bash
make format_check
```

Alias to run `make lint`, `make types`, `make tests`, `make format_check`, and `make pycodestyle`.

## Development Commands

```bash
make qa
```

Runs `sh scripts/mongo/run_mongo_docker.sh run` to start the local MongoDB docker container (used for testing and `dev` stage run).

```bash
make mongo_docker
```

Runs `sh scripts/mongo/run_mongo_docker.sh down` to stop the local MongoDB docker container.

```bash
make mongo_docker_down
```

## Application Specific Commands

Runs `sh scripts/aws/create_aws_config.sh` to create a default `${HOME}/.aws/config` AWS configuration.

```bash
make create_aws_config
```

Runs `sh scripts/aws/update_config.sh prod` to set parameters on `.chalice/config.json` as the production stage.

```bash
make config
```

Runs `sh scripts/aws/update_config.sh` to set parameters on `.chalice/config.json` with no specific stage.

```bash
make config_dev
```

Runs `sh scripts/aws/update_config.sh mongo_docker` to set parameters on `.chalice/config.json` as the Development stage.

```bash
make config_local
```

Runs `sh scripts/aws/update_config.sh qa` to set parameters on `.chalice/config.json` as the QA stage (with some specific variables substitution).

```bash
make config_qa
```

Runs `sh scripts/aws/update_config.sh qa deploy` to set parameters on `.chalice/config.json` to prepare the QA deployment.

```bash
make config_qa_for_deployment
```

Runs `sh scripts/aws/update_config.sh staging` to set parameters on `.chalice/config.json` as the Staging stage.

```bash
make config_staging
```

Runs `sh scripts/aws/run_aws.sh create_stack` to create the AWS Stack via Chalice command.

```bash
make build
```

Generates the `requirements.txt` by running `sh scripts/aws/run_aws.sh pipfile`.

```bash
make build_local
```

Runs `sh scripts/aws/run_aws.sh describe_stack` to describe the AWS stack by the Chalice command.

```bash
make build_check
```

Alias to run `make unbuild_qa`.

```bash
make unbuild
```

Runs `sh scripts/aws/run_aws.sh delete_app qa` and `sh scripts/aws/run_aws.sh delete_stack` to delete the Chalice QA App and the AWS stack.

```bash
make unbuild_qa
```

Runs `sh scripts/aws/run_aws.sh delete_app prod` and `sh scripts/aws/run_aws.sh delete_stack` to delete the Chalice Production App and the AWS stack.

```bash
make unbuild_prod
```

Runs `sh scripts/aws/create_chatbot_s3_bucket.sh dev` to create the S3 Development buckets.

```bash
make create_s3_bucket_dev
```

Runs `sh scripts/aws/create_chatbot_s3_bucket.sh qa` to create the S3 QA buckets.

```bash
make create_s3_bucket_qa
```

Runs `sh scripts/aws/create_chatbot_s3_bucket.sh staging` to create the S3 Staging buckets.

```bash
make create_s3_bucket_staging
```

Runs `sh scripts/aws/create_chatbot_s3_bucket.sh prod` to create the S3 Production buckets.

```bash
make create_s3_bucket_prod
```

Runs `make create_s3_bucket_qa`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy qa` to deploy the App on QA.

```bash
make deploy_qa
```

Runs `make create_s3_bucket_qa`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_validate qa` to validate the SAM deployment templates on QA.

```bash
make deploy_validate_qa
```

Runs `make create_s3_bucket_qa`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh package qa` to only create the deployment QA package. Usefull to check the package size and test the image by a local Docker run.

```bash
make deploy_package_qa
```

Runs `make create_s3_bucket_staging`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy staging` to deploy the App on Staging.

```bash
make deploy_staging
```

Runs `make create_s3_bucket_prod`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy prod` to deploy the App on Production.

```bash
make deploy_prod
```

Alias to run `make deploy_qa`.

```bash
make deploy
```

Runs `make config_qa`, `make clean_logs`, and `sh scripts/aws/run_aws.sh run_local` to execute the app locally using the development database, asking to run it over `http` or `https`.
[???]

```bash
make run
```

Runs `make config_qa`, `make clean_logs`, and `sh scripts/aws/run_aws.sh run_local qa` to execute the app locally using the QA database, asking to run it over `http` or `https`.

```bash
make run_qa
```

Runs `make config_qa`, `make clean_logs`, and `sh scripts/secure_local_server/run.sh "down" ""` to stop and destroy the App local Docker container.

```bash
make down_qa
```

Runs `make config_qa`, `make clean_logs`, `sh scripts/secure_local_server/run.sh "down" ""` and `sh scripts/aws/run_aws.sh run_local qa` to restart the App local Docker container running over QA.

```bash
make restart_qa
```

Runs `make config_local`, `make clean_logs`, `sh scripts/aws/run_aws.sh run_local dev` to execute the app locally using the development database (in a local Docker container), asking to execute it over `http` or `https`.
[???]

```bash
make run_local_docker
```

Runs `make config`, `make clean_logs`, `sh scripts/aws/run_aws.sh run` to execute `chalice local --port \$PORT --stage PROD`

```bash
make run_prod
```

Runs `sh scripts/add_github_submodules.sh` to add the Git Submodule with the common JSON config directories.

```bash
make add_submodules
```

Runs `sh scripts/dns/run_local_dns.sh` to start the local DNS server.

```bash
make local_dns
```

Runs `sh scripts/dns/run_local_dns.sh restart` to restart the local DNS server.

```bash
make local_dns_restart
```

Runs `sh scripts/dns/run_local_dns.sh rebuild` to restart and rebuild the local DNS server configuration when the local IP or any DNS parameters has been changed.

```bash
make local_dns_rebuild
```

Runs `sh scripts/dns/run_local_dns.sh down` to stop and destroy the local DNS server.

```bash
make local_dns_down
```

Runs `sh scripts/dns/run_local_dns.sh test` to test the local DNS server.

```bash
make local_dns_test
```

Runs `sh scripts/local_ssl_certs_creation.sh` to create the self-signed local SSL certificates (required to run the local develpment frotend and backend over https).

```bash
make create_ssl_certs_only
```

Runs `sh scripts/local_ssl_certs_copy.sh` to copy the self-signed local SSL certificates to the frontend directory/local repository.

```bash
make copy_ssl_certs
```

Alias to run `make create_ssl_certs_only` and `make copy_ssl_certs`.

```bash
make create_ssl_certs
```

# NPM library scripts

Runs `npm install --package-lock-only` to update the package.json file with the version and all other parameters except dependecies.

```bash
make lock
```

Runs `sh scripts/npm_publish.sh pre-publish` to test the publish to NPMJS without actually publishing.

```bash
make pre-publish
```

Runs `sh scripts/npm_publish.sh publish` to publish the scripts library to NPMJS.

```bash
make publish
```

# ..............

## License

GenericSuite is open-sourced software licensed under the ISC license.

## Credits

This project is developed and maintained by Carlos J. Ramirez. For more information or to contribute to the project, visit [The GenericSuite Scripts (backend version) on GitHub](https://github.com/tomkat-cr/genericsuite-be-scripts).

Happy Coding!