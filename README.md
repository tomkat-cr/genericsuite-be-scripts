# The GenericSuite Scripts (backend version).

![GenericSuite Logo](https://genericsuite.carlosjramirez.com/images/gs_logo_circle.svg)

[GenericSuite](https://www.carlosjramirez.com/genericsuite/) is a versatile backend solution, designed to provide a comprehensive suite of features for Python APIs. It supports various frameworks including Chalice, FastAPI, and Flask, making it adaptable to a range of projects.<be/>
This repository contains the backend scripts necessary to build and deploy APIs made by the backend version of [The GenericSuite](https://www.carlosjramirez.com/genericsuite/).

## Features

- **AWS Deployment**: Deployment to AWS as Lambda Function with API Gateway usig SAM (AWS Serverless Application Model).
- **Local Development Environment**: running with http or https, with or without Docker.
- **Local DNS Server**: to allow https API access with a domain name like `app.exampleapp.local` and allow access from another devices locally (e.g. smartphones) to test your App.
- **Self-signed SSL certificates creation**: to allow local development frontend and backend environments run over secure https connections.
- **Common JSON config management**: to add the Git Submodule with the common JSON config directories.
- **Local MongoDB Docker conntainer**: used by the test site and allows to have an offline local development environment.


## Getting Started

To get started with GenericSuite, follow these steps:

### Initiate your project

Check [The GenericSuite Getting Started guide](https://github.com/tomkat-cr/genericsuite-be?tab=readme-ov-file#getting-started) for more details.

### Install the GenericSuite Backend Scripts

```bash
npm init
```

```bash
npm install -D genericsuite-be-scripts
```

To generate sef-signed SSL certificates, `office-addin-dev-certs` is required:

```bash
npm install -D office-addin-dev-certs
```

### Prepare the Makefile

Copy the `Makefile` template from `node_modules/genericsuite-be-scripts`:

```bash
cp node_modules/genericsuite-be-scripts/Makefile ./Makefile
```

### AWS SAM

#### Prepare the AWS/SAM templates

Create the project's `scripts/aws_big_lambda` and `scripts/aws` directories and copy the templates:

```bash
make init_sam
```

Or...

```bash
sh node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/init_sam.sh
```

<br/>

If you're going to develop with the Chalice framework:

Create the `.chalice` directory and copy the `.chalice/config-example.json` template:<br/>

```bash
make init_chalice
```

Or...

```bash
sh node_modules/genericsuite-be-scripts/scripts/aws/init_chalice.sh
```

<br/>

#### Customize SAM Templates

If you need to do any customization to the `samconfig.toml`:

Edit the `template-samconfig.toml` file:<br/>

```bash
vi scripts/aws_big_lambda/template-samconfig.toml
# or
# code scripts/aws_big_lambda/template-samconfig.toml
```

Check for some customization needed.

NOTE: The deployment script [big_lambdas_manager.sh](https://github.com/tomkat-cr/genericsuite-be-scripts/blob/main/scripts/aws_big_lambda/big_lambdas_manager.sh) will replace `APP_NAME_LOWERCASE_placeholder` with the Application name defined in the `APP_NAME` variable in `.env` file.

<br/>

#### Add new Endpoints to SAM Template

When you need to add new endpoints to your App:

Edit the `template-sam.yml`:<br/>

```bash
vi scripts/aws_big_lambda/template-sam.yml
# or
# code scripts/aws_big_lambda/template-sam.yml
```

In this file is where the endpoints are defined, as well as other SAM deployment elements like the environment variables used by the AWS Lambda function. You can add new endpoints or customize it as you needed.

There's an endpoint definition template in the file [node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/template-sam-endpoint-entry.yml](https://github.com/tomkat-cr/genericsuite-be-scripts/blob/main/scripts/aws_big_lambda/template-sam-endpoint-entry.yml).

Be careful about elements ending with `_placeholder` because they are replaced by the deployment script `big_lambdas_manager.sh` with the corresponding values.

<br/>

#### Add new Environment Variables

If you need to add additional environment variables to your App:

Edit the `update_additional_envvars.sh` file:<br/>

```bash
vi scripts/aws/update_additional_envvars.sh
# or
# code scripts/aws/update_additional_envvars.sh
```

Add your additional environment variables replacements in `scripts/aws/update_additional_envvars.sh` as:<br/>

```bash
perl -i -pe"s|ENVVAR_NAME_placeholder|${ENVVAR_NAME}|g" "${CONFIG_FILE}"
```
... replacing "ENVVAR_NAME" with the name of the environment variable

Add the additional environment variables to the `.env` file:
```.env
ENVVAR_NAME=ENVVAR_VALUE
```
... replacing "ENVVAR_NAME" with the name of the environment variable and ENVVAR_VALUE with its value.

Add the additional environment variables to the `scripts/aws_big_lambda/template-sam.yml` file, in the `APIHandler > Properties > Environment > Variables` section. E.g.<br/>

```yaml
      .
      .
   APIHandler:
         .
         .
      Properties:
            .
            .
         Environment:
         Variables:
            ENVVAR_NAME: ENVVAR_VALUE
                  .
                  .
```
... replacing "ENVVAR_NAME" with the name of the environment variable and ENVVAR_VALUE with its value.

If you're using the Chalice framework, add the additional environment variables to the `.chalice/config-example.json` file, in the main `environment_variables` section. E.g.<br/>

   ```
   {
      "version": "2.0",
            .
            .
      "environment_variables": {
               .
               .
         "ENVVAR_NAME": "ENVVAR_NAME_placeholder"
      },
      "stages": {
            .
            .
   ```
... replacing "ENVVAR_NAME" with the name of the environment variable (in both places).

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

## Install dependencies

* Install default package categories from Pipfile.<br/>
Runs `pipenv install`.<br/>
Reference: https://pipenv.pypa.io/en/latest/commands.html#install

```bash
make install
```

* Install both develop and default package categories from Pipfile.<br/>
Runs `pipenv install --dev`.

```bash
make install_dev
```

* Install from the Pipfile.lock and completely ignore Pipfile information.<br/>
Runs `pipenv install --ignore-pipfile`.

```bash
make locked_install
```

* Install both develop and default package categories from the Pipfile.lock and completely ignore Pipfile information.<br/>
Runs `pipenv install --dev --ignore-pipfile`.

```bash
make locked_dev
```

* Generates the `requirements.txt` file.<br/>
Runs `sh scripts/aws/run_aws.sh pipfile`.

```bash
make requirements
```
or...
```bash
make lock_pip_file
```

* Clean install.<br/>
Alias that runs `make clean_rm` and `make install`.

```bash
make fresh
```

## Cleaning

* Alias to run `make clean_rm`, `make clean_temp_dir`, and `make clean_logs`.

```bash
make clean
```

* Remove a virtual environment created by "pipenv run".<br/>
Runs `pipenv --rm`.

```bash
make clean_rm
```

* Clean logs (in /logs directory).<br/>
Runs sh `scripts/clean_logs.sh`.

```bash
make clean_logs
```

* Clean logs, cache and temporary files.<br/>
Runs `sh scripts/aws/run_aws.sh clean`.

```bash
make clean_temp_dir
```

## CLI Utilities

* Install development tools (pyenv, pipenv, make, and optionally: poetry, saml2aws).<br/>
Check [node_modules/genericsuite-be-scripts/scripts/install_dev_tools.sh](https://github.com/tomkat-cr/genericsuite-be-scripts/blob/main/scripts/install_dev_tools.sh) for more details about how to configure via `.env` file.

```bash
make install_tools
```

* Show ports in use.<br/>
Runs `sh scripts/run_lsof.sh`.

```bash
make lsof
```

## Automated Testing

* Start the local MongoDB docker container and run the tests.<br/>
Runs `sh scripts/run_app_tests.sh`.

```bash
make test
```

* Execute the test without starting the local MongoDB docker container.<br/>
Runs `sh scripts/aws/run_tests.sh`.

```bash
make test_only
```

## Linting

* Execute Prospector.<br/>
Runs `pipenv run prospector`.

```bash
make lint
```

* Execute MyPy.<br/>
Runs `pipenv run mypy .`.

```bash
make types
```

* Execute Coverage.<br/>
Runs `pipenv run coverage run -m unittest discover tests` and `pipenv run coverage report`.

```bash
make coverage
```

* Execute Yapf Formatter and PyCodeStyle.<br/>
Runs `pipenv run yapf -i *.py **/*.py **/**/*.py` and `pycodestyle`.<br/>
References:<br/>
   * [https://github.com/google/yapf](https://github.com/google/yapf)<br/>
   * [https://pycodestyle.pycqa.org/en/latest/](https://pycodestyle.pycqa.org/en/latest/)<br/>

```bash
make format
```

* Execute Yapf (in "print the diff for the fixed source" mode) and PyCodeStyle.<br/>
Runs `pipenv run yapf --diff *.py **/*.py **/**/*.py` and `pycodestyle`.

```bash
make format_check
```

## Development Commands

* Perform a complete Lint, Type check, unit and integration test, format check, and styling before deployments.<br/>
Alias to run `make lint`, `make types`, `make tests`, `make format_check`, and `make pycodestyle`.

```bash
make qa
```

* Start the local MongoDB docker container (used for testing and `dev` stage run).<br/>
Runs `sh scripts/mongo/run_mongo_docker.sh run`.

```bash
make mongo_docker
```

* Stop the local MongoDB docker container.<br/>
Runs `sh scripts/mongo/run_mongo_docker.sh down`

```bash
make mongo_docker_down
```

## Chalice Specific Commands

* Set parameters on `.chalice/config.json` as the production stage.<br/>
Runs `sh scripts/aws/set_chalice_cnf.sh prod`.

```bash
make config
```

* Set parameters on `.chalice/config.json` with no specific stage.<br/>
Runs `sh scripts/aws/set_chalice_cnf.sh`.

```bash
make config_dev
```

* Set parameters on `.chalice/config.json` as the Development stage.<br/>
Runs `sh scripts/aws/set_chalice_cnf.sh mongo_docker`.

```bash
make config_local
```

* Set parameters on `.chalice/config.json` as the QA stage with CORS specific variables replacement, to allow use the QA live database from the local development environment.<br/>
Runs `sh scripts/aws/set_chalice_cnf.sh qa`.<br/>
References: 
   * `APP_CORS_ORIGIN_QA_CLOUD` and `APP_CORS_ORIGIN_QA_LOCAL` in the [.env.example file](https://github.com/tomkat-cr/genericsuite-be/blob/main/.env.example).<br/>

```bash
make config_qa
```

* Set parameters on `.chalice/config.json` to prepare the QA deployment.<br/>
Runs `sh scripts/aws/set_chalice_cnf.sh qa deploy`,

```bash
make config_qa_for_deployment
```

* Set parameters on `.chalice/config.json` as the Staging stage.<br/>
Runs `sh scripts/aws/set_chalice_cnf.sh staging`.

```bash
make config_staging
```

* Create the AWS Stack via Chalice command.<br/>
Runs `sh scripts/aws/run_aws.sh create_stack`.

```bash
make build
```

* Generates the `requirements.txt`.<br/>
Runs `sh scripts/aws/run_aws.sh pipfile`.

```bash
make build_local
```

* Describe the AWS stack with the Chalice command.<br/>
Runs `sh scripts/aws/run_aws.sh describe_stack`.

```bash
make build_check
```

* Alias to run `make unbuild_qa`.

```bash
make unbuild
```

* Delete the Chalice QA App.<br/>
Runs `sh scripts/aws/run_aws.sh delete_app qa`.

```bash
make unbuild_qa
```

* Delete the Chalice Staging App.<br/>
Runs `sh scripts/aws/run_aws.sh delete_app staging`

```bash
make unbuild_staging
```

* Delete the AWS stack created by Chalice.<br/>
Runs `sh scripts/aws/run_aws.sh delete_stack`

```bash
make delete_stack
```

## AWS S3 and other

* Create a default `${HOME}/.aws/config` AWS configuration.<br/>
Runs `sh scripts/aws/create_aws_config.sh`.

```bash
make create_aws_config
```

* Create the Development S3 buckets.<br/>
Runs `sh scripts/aws/create_chatbot_s3_bucket.sh dev`.

```bash
make create_s3_bucket_dev
```

* Create the QA S3 buckets.<br/>
Runs `sh scripts/aws/create_chatbot_s3_bucket.sh qa`.

```bash
make create_s3_bucket_qa
```

* Create the Staging S3 buckets.<br/>
Runs `sh scripts/aws/create_chatbot_s3_bucket.sh staging`.

```bash
make create_s3_bucket_staging
```

* Create the Production S3 buckets.<br/>
Runs `sh scripts/aws/create_chatbot_s3_bucket.sh prod`.

```bash
make create_s3_bucket_prod
```

## Deployment

* Deploy the App on QA.<br/>
Runs `make create_s3_bucket_qa`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy qa`

```bash
make deploy_qa
```

* Validate the SAM deployment templates on QA.<br/>
Runs `make create_s3_bucket_qa`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_validate qa`

```bash
make deploy_validate_qa
```

* Create the deployment QA package only.<br/>
Useful to check the package size and test the image by a local Docker run.<br/>
Runs `make create_s3_bucket_qa`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh package qa`.

```bash
make deploy_package_qa
```

* Deploy the App on Staging.<br/>
Runs `make create_s3_bucket_staging`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy staging` 

```bash
make deploy_staging
```

* Deploy the App on Production.<br/>
Runs `make create_s3_bucket_prod`, `sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy prod`

```bash
make deploy_prod
```

* Alias to run `make deploy_qa`.

```bash
make deploy
```

## Application Specific Commands

* Execute the App locally using the development database, asking to run it over `http` or `https`.<br/>
Runs `make config_qa`, `make clean_logs`, and `sh scripts/aws/run_aws.sh run_local`.
[???]

```bash
make run
```

* Execute the App locally using the QA database, asking to run it over `http` or `https`.<br/>
Runs `make config_qa`, `make clean_logs`, and `sh scripts/aws/run_aws.sh run_local qa`.

```bash
make run_qa
```

* Runs `make config_qa`, `make clean_logs`, and `sh scripts/secure_local_server/run.sh "down" ""`
Stop and destroy the App local Docker container (for any running stage).<br/>

```bash
make down_qa
```

* Restart the App local Docker container running over QA.<br/>
Runs `make config_qa`, `make clean_logs`, `sh scripts/secure_local_server/run.sh "down" ""` and `sh scripts/aws/run_aws.sh run_local qa`.

```bash
make restart_qa
```

* Execute the App locally using the development database (in a local Docker container), asking to execute it over `http` or `https`.<br/>
Runs `make config_local`, `make clean_logs`, `sh scripts/aws/run_aws.sh run_local dev`.
[???]

```bash
make run_local_docker
```

* Execute `chalice local --port \$PORT --stage PROD`<br/>
Runs `make config`, `make clean_logs`, `sh scripts/aws/run_aws.sh run`.

```bash
make run_prod
```

## Common JSON config

* Add the Git Submodule with the common JSON config directories.<br/>
Runs `sh scripts/add_github_submodules.sh`.

```bash
make add_submodules
```

# Local DNS Server

* Start the local DNS Server.<br/>
Runs `sh scripts/dns/run_local_dns.sh`

```bash
make local_dns
```

* Runs `sh scripts/dns/run_local_dns.sh restart` to restart the local DNS Server.<br/>

```bash
make local_dns_restart
```

* Restart and rebuild the local DNS Server configuration when the local IP or any DNS parameters has been changed.<br/>
Runs `sh scripts/dns/run_local_dns.sh rebuild`

```bash
make local_dns_rebuild
```

* Stop and destroy the local DNS Server.<br/>
Runs `sh scripts/dns/run_local_dns.sh down`.

```bash
make local_dns_down
```

* Test the local DNS Server.<br/>
Runs `sh scripts/dns/run_local_dns.sh test`.

```bash
make local_dns_test
```

## Self-signed local SSL certificates

* Create the self-signed local SSL certificates (required to run the local development frontend and backend over https).<br/>
Runs `sh scripts/local_ssl_certs_creation.sh`.

```bash
make create_ssl_certs_only
```

* Copy the self-signed local SSL certificates to the frontend directory/local repository.<br/>
Runs `sh scripts/local_ssl_certs_copy.sh`.

```bash
make copy_ssl_certs
```

* Alias to run `make create_ssl_certs_only` and `make copy_ssl_certs`.<br/>

```bash
make create_ssl_certs
```

# NPM library scripts

* Update the package.json file with the version and all other parameters except dependencies.<br/>
Runs `npm install --package-lock-only`.

```bash
make lock
```

* Test the publish to NPMJS without actually publishing.<br/>
Runs `sh scripts/npm_publish.sh pre-publish`.

```bash
make pre-publish
```

* Publish the scripts library to NPMJS.<br/>
Runs `sh scripts/npm_publish.sh publish`.<br/>
Requirements:<br/>
   * [NpmJS Account](https://www.npmjs.com/signup).

```bash
make publish
```

# Pypi library scripts

* Build 'dist' directory needed for the Pypi publish.<br/>
Runs `poetry lock --no-update`, `rm -rf dist` and `python3 -m build`.<br/>
Requirements:<br/>
   * [poetry](https://python-poetry.org/).

```bash
make pypi-build
```

* Pypi Test publish.<br/>
Runs `make pypi-build`, and `python3 -m twine upload --repository testpypi dist/*`.<br/>
Requirements:<br/>
   * [twine](https://pypi.org/project/twine/).<br/>
   * [TestPypi Account](https://test.pypi.org/account/register/).

```bash
make pypi-publish-test
```

* Pypi Production publish<br/>
Runs `make pypi-build`, and `python3 -m twine upload dist/*`.<br/>
Requirements:<br/>
   * [twine](https://pypi.org/project/twine/).<br/>
   * [Pypi Account](https://www.pypi.org/account/register/).

```bash
make pypi-publish
```

## Troubleshooting

- If you get the error `Warning: Python >=3.9,<4.0 was not found on your system...` doing `make install`:

```bash
$ make install

pipenv install
Warning: Python >=3.9,<4.0 was not found on your system...

You can specify specific versions of Python with:
$ pipenv --python path/to/python
make: *** [install] Error 1
```
Fix it with these commands:
```bash   
# Set the project Python version with pyenv
pyenv local 3.11
```
```bash
# Set the Python path with pipenv
pipenv --python ${HOME}/.pyenv/shims/python
```

And repeat `make install`

* If you get the warning `This version of npm is compatible with lockfileVersion@1...` doing `make install`:

```bash
npm install

npm WARN read-shrinkwrap This version of npm is compatible with lockfileVersion@1, but package-lock.json was generated for lockfileVersion@3. I'll try to do my best with it!
```

It's because you're using an old Node version. To solve it:

```bash
nvm node 18
```

And repeat `make install`

- If you get `APP_NAME not set` message doing any `make run`, it's because the `.env` file must be created or reviewed. Check the [GenericsSuite (backend version) Configuration](https://github.com/tomkat-cr/genericsuite-be?tab=readme-ov-file#configuration) or [GenericsSuite AI (backend version) Configuration](https://github.com/tomkat-cr/genericsuite-be-ai?tab=readme-ov-file#configuration)

- If you get CORS errors in the frontend and backend communication:

   1. To make both use `localhost` and `http`, change these variables in the `.env` file:

```bash
# Frontend .env file:
APP_LOCAL_DOMAIN_NAME=localhost
```
```bash
# Backend .env file:
APP_CORS_ORIGIN_QA_LOCAL=http://localhost:3000
```
   And `make run` both frontend and backend with the `http` option.

   2. To make both use the local DNS server and `https`, change these variables in the `.env` file:

```bash
# Frontend .env file:
APP_LOCAL_DOMAIN_NAME=app.exampleapp.local
```
```bash
# Backend .env file:
APP_CORS_ORIGIN_QA_LOCAL=https://app.exampleapp.local:3000
```
**NOTE**: replace `exampleapp` with your App name, all lowercased.

And `make run` both frontend and backend with the `https` option.<br/>

- If the local DNS Server seems to be unreachable or not working:

Restart the local backend server:

```bash
make local_dns_restart
```

If the local IP changes, make sure to:
  1) Run `make local_dns_rebuild`.<br/><br/>
  2) Copy the `IP address` reported by the previous command.<br/>E.g.<br/>
     `Local DNS domain 'app.exampleapp.local' is pointing to IP address '192.168.1.158'`.<br/><br/>
  3) Run `make restart_qa`<br/><br/>
  4) Add the `IP address` to the DNS Servers in your computer's `Network > DNS servers` settings. The new DNS Server `IP address` must be the first one in the list of DNS servers.<br/><br/>
  5) Restart the computer's WiFi or LAN network connection.

## License

GenericSuite is open-sourced software licensed under the ISC license.

## Credits

This project is developed and maintained by Carlos J. Ramirez. For more information or to contribute to the project, visit [The GenericSuite Scripts (backend version) on GitHub](https://github.com/tomkat-cr/genericsuite-be-scripts).

Happy Coding!