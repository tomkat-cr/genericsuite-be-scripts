# CHANGELOG

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a Changelog](http://keepachangelog.com/).



## Unreleased
---

### New

### Changes

### Fixes

### Breaks


## Unreleased
## 1.0.14 (2025-02-19)
---

### New
Add the "link_gs_libs_for_dev.sh" script to link LOCAL GenericSuite libraries and trigger the uvicorn/gunicorn reload without need to run "pipenv update". Add to the Makefile and run with `make link_gs_libs` [FA-84].
Add the BASE_DEVELOPMENT_PATH envvar to specify the GS base development path (parent directory of genericsuite-be* repos) to enable "make link_gs_libs_for_dev" [FA-84].
Add the SAM_BUILD_CONTAINER envvar to force "sam build --use-container --debug" when "make deploy_run_local_qa" is executed [GS-87].

### Changes
Remove "make lock_pip_file" and replace it with "make requirements". Add "make lock" and "make npm_lock" [FA-84] [GS-15].

### Fixes
Fix poetry 2.x "The option --no-update does not exist" error message [FA-84].
Fix TMP_BUILD_DIR assignment in dynamodb deploy script.


## 1.0.13 (2025-02-18)
---

### Changes
The "--loglevel debug" option were added to the gunicorn server for Generic Endpoint Builder for Flask [GS-15].

### Fixes
Fix flask run with gunicorn when local machine is running a VPN, getting the local IP address, which is the first one reported by the "ifconfig" command  [GS-15]


## 1.0.12 (2024-10-07)
---

### New
Add ".nvmrc" file to set the repo default node version.
Add DynamoDB database running along with MongoDB in a docker container when running the App in the "dev" stage [GS-102].
Add local DynamoDB tables generation in "generate_dynamodb_cf.py" [GS-102].
Add DynamoDB docker container to "mongodb_stack_for_test.yml" [GS-102].
Add DynamoDB local workbench manager (taydy/dynamodb-manager) to the "mongodb_stack_for_test.yml" [GS-102].
Add DYNAMDB_PREFIX envvar to the "run_aws.sh" script with the value "${APP_NAME_LOWERCASE}_${STAGE}_" [GS-102].
Add GS_LOCAL_ENVIR envvar to detect a local database running in a docker container [GS-102].
Add "run_mongo_docker.sh" runs "generate_dynamodb_cf.sh create_tables dev" to create the DynamoDB tables in the local Docker container [GS-102].
Add "/users/current_user_d" endpoint [GS-2].

### Changes
Make DynamoDb tables with prefix work with the GS DB Abstraction [GS-102].
Makefile "mongo_docker" runs the MongoDB and DynamoDB docker containers without calling "make run" by default [GS-102].

### Fixes
Fix error in "run_mongo_docker.sh" starting containers when Docker Desktop is not running [GS-102].


## 1.0.11 (2024-07-19)
---

### New
Add EC2+ALB App deployment using AWS CloudFormation (EBS volume encryption postponed) [GS-96].
Add password and API Keys to AWS Secrets using AWS CloudFormation [GS-41].
Add DynamoDB tables creation from the JSON configs using AWS CloudFormation [GS-84].
Add "scripts/aws_dynamodb/generate_dynamodb_cf/generate_dynamodb_cf.py" and its ".sh" to generate the "cf-template-dynamodb.yml" file in the project's scripts directory [GS-84]. 
Add "scripts/aws_dynamodb/run-dynamodb-deploy.sh" to deploy generated "cf-template-dynamodb.yml" [GS-84].
Add GET_SECRETS_CRITICAL and GET_SECRETS_CRITICAL envvars to fine-grained disabling of cloud secrets manager for critical secrets and plain envvars [GS-41].
Add aws_secrets to Makefile to deploy envvars to the AWS Secrets manager [GS-41].
Add depLoy_ec2 to Makefile [GS-96].
Add deploy_ecr_creation to Makefile to build the FastAPI docker image [GS-96].
Add: generate_cf_dynamodb and deploy_dynamodb to Makefile [GS-84].
Add "scripts/aws_cf_processor/run-cf-deployment.sh" to standarize all Cloudformation calls [GS-96].
Add "run-cf-deployment.sh" enhanced to simulate the EC2 + ALB in AWS LocalStack [GS-97].
Add Secret and KMS access policies to the "template-sam.yml" file [GS-41].
Add "scripts/aws_cf_processor/test_localstack.sh" to test localstack EC2 functionality with the LOCALSTACK_AUTH_TOKEN envvar [GS-97].
Add LOCAL_DNS_DISABLED and BRIDGE_PROXY_DISABLED envvars to disable local services working on the road.
Add NGROK_ENABLED envvar to enable/disable Ngrok service in the URL_MASK_EXTERNAL_HOSTNAME and DEV_MASK_EXT_HOSTNAME assignments on "scripts/get_domain_name_dev.sh".

### Changes
Change APP_STAGE dynamic assignment in run_aws.sh, set_chalice_cnf.sh, and big_lambdas_manager.sh, and secure_local_server/docker_entrypoint.sh [GS-41].
__pycache__ removal simplified in big_lambdas_manager.sh [GS-96].
APP_DB_URI and the secrets assignment removed in big_lambdas_manager.sh, docker-compose-big-lambda-AL2.yml, docker-compose-big-lambda-Alpine.yml [GS-41].
Remove all envvars from "template-sam.yml" [GS-96].
Change: set APP_DB_URI when GET_SECRETS_ENABLED=0 or GET_SECRETS_CRITICAL=0 in "run_aws.sh" [GS-41].
Change "scripts/aws/update_additional_envvars.sh" to be called from both "scripts/aws_secrets/aws_secrets_manager.sh" and "scripts/aws/set_chalice_cnf.sh", conditioning the config file variables replacement when 1st parameter (CONFIG_FILE) is passed, and setting the App specific secrets list (separated by blanks) in a export APP_SECRETS="..." used by the aws_secrets_manager [GS-41].
Check the CLOUD_PROVIDER variable in big_lambdas_manager.sh and avoid execution if not set.

### Fixes
Fix 'USER_AGENT environment variable not set...' LangSmith warning message removed in run_aws.sh, big_lambdas_manager.sh, aws_big_lambda/template-sam.yml, and secure_local_server/docker_entrypoint.sh.
Fix issue reporting the "_placeholder" missing parameter in the SAM template in verify_base_names() of big_lambdas_manager.sh.
Fix API_GATEWAY_PORT report in pre-process summary in big_lambdas_manager.sh.
Fix replace the fixed "us-east-1" region by $AWS_REGION on the AWS_DOCKER_IMAGE_URI_BASE assignment in big_lambdas_manager.sh.


## 1.0.10 (2024-06-07)
---

### New
Add "verify_base_names()" to "big_lambdas_manager.sh", to check mandatory env. vars. to have the "*_placeholder" in the SAM template.yml before deployment.
Add "clean_ecr_images.sh" to keep only 2 AWS ECR images for each App/Stage [GS-80].
Add DynamoDB tables creation from the JSON configs to the SAM template [GS-84].
Add "sam_run_local" to big lambdas to test the API Gateway and Lambda function with SAM local.

## Changes
Enhance "secure_local_server/run.sh" to resume the sls-backend docker image logs if it's already running (avoiding reinstall all dependecies), and also allows to have the local GE BE and BE AI repos for faster development.
Standarize BACKEND_LOCAL_PORT and FRONTEND_LOCAL_PORT env. vars.
Ignore the ".chalice/deployment/deployment.zip" file in big lambdas.

## Fixes
Fix the "/var/scripts/get_domain_name.sh not found" error running the development backend environment over https.
Fix error "cp: /tmp/sls/nginx.conf.tmp: No such file or directory" running the app over https.


## 1.0.9 (2024-05-17)
---

### New
Add "set_app_dir_and_main_file.sh" to load the ".env" file and set APP_DIR, APP_MAIN_FILE and APP_HANDLER environment variables with the Python entry point for uvicorn and gunicorn [FA-248].
Add ".npmignore" to the ".chalice" and "scripts/aws_big_lambda" directories [FA-258].
Add "get_domain_name_dev.sh" to support mask the S3 URL and avoid AWS over-billing attacks [GS-72].
Add STORAGE_URL_SEED and APP_HOST_NAME env. vars. to ".env.example", big lambda deployment, run_aws, secure_local_server and Chalice config [GS-72].
Add "run_generate_seed.sh" and "generate_seed.py" to suggest the STORAGE_URL_SEED value.
Add "show_date_time.sh" to replace the repetitive code to show current date/time in bash scripts.

### Changes
Change "run_aws.sh", "secure_local_server/run.sh" and "big_lambdas_manager.sh" to implement "set_app_dir_and_main_file.sh" [FA-248] and [FA-98].
Change "run_aws.sh" to call "secure_local_server/run.sh" for "gunicorn" and "uvicorn" RUN_METHODs and "https" RUN_PROTOCOL [FA-248].
Change "big_lambdas_manager.sh" and "run_local_dns.sh" to build templates and configuration files in "/tmp" [FA-248] and [FA-98].
Redirect README instructions to the GenericSuite Documentation [GS-73].
Unify the domain name getting with "get_domain_name.sh".
Change the way "big_lambdas_manager.sh" replace env. vars. using "*_placeholder".
Local DNS configuration /tmp/named-to-add.conf is added to /etc/bind/named.conf.local instead of /etc/bind/named.conf.
"db_mongo_backup.sh" and "db_mongo_restore.sh" enhanced to handle zip files.

### Fixes
Fix error "KeyError: 'APP_DB_NAME'" starting the app with "secure_local_server/docker_entrypoint.sh" by setting APP_DB_ENGINE, APP_DB_NAME, APP_DB_URI, APP_CORS_ORIGIN, AWS_S3_CHATBOT_ATTACHMENTS_BUCKET env. vars. before calling uvicorn and gunicorn [FA-248].
Fix the lack of responses issue calling the backend over https for "gunicorn" and "uvicorn" RUN_METHODs, by removing the SSL certificates path parameters in uvicorn and gunicorn calls in "secure_local_server/docker_entrypoint.sh", because the Nginx service takes care about SSL handling [FA-248].
Fix the frontend "Network error" running the app over local MongoDB when APP_CORS_ORIGIN is "*".


## 1.0.8 (2024-04-26)
---

### New
Add "npm_remove_ignored.sh" to remove files in ".gitignore" or ".npmignore" [FA-84].

### Changes
Change "npm_publish.sh" to implement "npm_remove_ignored.sh" [FA-84].


## 1.0.7 (2024-04-20)
---

### New
Add "make init_submodules" and "init_json_configs.sh" to copy the basic JSON files [FA-246].

### Changes
FastAPI enhanced support for deployments [FA-246].
AWS_API_GATEWAY_STAGE env. var. removed [FA-248].
"run_aws.sh" ask for protocol http/https for all RUN_METHODs [FA-248].
"run_aws.sh" use APP_DIR / APP_MAIN_FILE env. vars. to specify the python entry point in gunicorn and uvicorn RUN_METHODs [FA-248].
"set_fe_cloudfront_domain.sh" looks for a "[STAGE]" string in the "AWS_S3_BUCKET_NAME_FE" and replaces it with the `ENV` parameter value to handle the working stage.
"big_lambdas_manager.sh" take into account the different "AWS_LAMBDA_FUNCTION_ROLE_*" env. vars.
Remove not standard enpoints definitions from "template-sam.yml" [FA-248].
Change: README with main image from the official documentation site [FA-246].
Change: Homepage pointed to "https://genericsuite.carlosjramirez.com/Backend-Development/GenericSuite-Scripts/" [FA-257].

### Fixes
Fix "run_aws.sh" to replace "https" with "http" in APP_CORS_ORIGIN when CURRENT_FRAMEWORK is not chalice and add APP_VERSION env. var. assignment.


## 1.0.6 (2024-04-12)
---

### Fixes
Fix issues in "big_lambdas_manager.sh" script with environment variables that contains values with @ due to the "set_env_vars.sh" removal [FA-98].


## 1.0.5 (2024-04-11)
---

### Fixes
Remove "set_env_vars.sh" from the AWS Lambda docker image [FA-258].

### Changes
"big_lambdas_manager.sh" use APP_DIR / APP_MAIN_FILE env. vars. to specify the python entry point in fastapi and flask CURRENT_FRAMEWORKs [FA-98].
"big_lambdas_manager.sh" shows start and finish date/time [FA-98].


## 1.0.4 (2024-04-11)
---

### Changes
Change the initial run command in the Dockerfile when "big_lambdas_manager.sh" runs for non-Chalice frameworks [FA-98].
Run "set_chalice_cnf.sh" only if the current framework is Chalice [FA-248].


## 1.0.3 (2024-04-09)
---

### Changes
Add links to https://www.carlosjramirez.com/genericsuite/ to the README.


## 1.0.2 (2024-04-06)
---

### Fixes
Fix issues with AWS Lambda Func. deployment in "big_lambdas_manager.sh" script with environment variables that contains values with @.
Fix SAM template to include missing name and BinaryMediaTypes for the AWS API Gateway definition, and description for the AWS Lambda Func.


## 1.0.1 (2024-04-01)
---

### New
Add `make deploy_demo` and `make create_s3_bucket_demo` to manage the "demo" stage [FA-213].
Add "demo" stage to APP_DB_ENGINE, APP_DB_NAME, APP_DB_URI, APP_CORS_ORIGIN, and AWS_S3_CHATBOT_ATTACHMENTS_BUCKET [FA-213].

### Changes
"big_lambdas_manager.sh" uses get_ssl_cert_arn() to discover the ACM Certificate ARNs [FA-213].
License changed to ISC [FA-244].

### Fixes
Fix "set_chalice_cnf.sh" because replaces APP_DB_URI_* with @ unescaped and prevents MongoDB connection when customized "scripts/aws/update_additional_envvars.sh" exist.
Fix "set_chalice_cnf.sh" to remove things not needed in the deployment in CONFIG_FILE, not ENV_FILESPEC.
Fix "run_aws.sh" because generates empty "requirements.txt".


## 1.0.0 (2024-03-31)
---

### New
Add `genericsuite-be-scripts` to The GenericSuite [FA-241].
Add "scripts/aws/update_additional_envvars.sh" to customize additional environment variables replacement in "set_chalice_cnf.sh" and "big_lambdas_manager.sh" [FA-241].


## 0.0.23 (2024-03-19)
---

### New
Add `npm_publish.sh` to publish this library to NPMJS.

### Changes
Prepare the backend bash scripts to be exported as a separate repository [FA-84].


## 0.0.22 (2024-02-19)
---

### Changes
Change "un_app_tests.sh" uses HTTP_SERVER_URL env var, reports the database used and removes the .env.bak file [FA-228].


## 0.0.21 (2024-02-18)
---

### New
FA-169	Create a deployment and local testing for big AWS Lambdas
FA-204 	Add SAM validate to big lambdas script
FA-100	FE: bash script to deploy ReactJs app with AWS Cloudfront and S3


## 0.0.20 (2023-12-01)
---

### New
Add `big_lambdas_manager.sh` to deploy Python AWS Lambda functions with container images and solve the big lambdas issue.


## 0.0.19 (2023-12-01)
---

### New
Add `secure_local_server/run.sh` to run the backend local server in a Docker container and be able to serve with https secure connection using self-signed SSL certificates.


## 0.0.18 (2023-11-27)
---

### New
Add `local_ssl_certs_creation.sh` and `local_ssl_certs_copy.sh` to create local auto-signed SSL certificated and copy to the frontend local directory.
Add `change_local_ip_for_dev.sh` to change the local IP/domain for the dev environment (both frontend and backend).
Add `run_local_dns.sh` to create a local DNS server.


## 0.0.17 (2023-11-19)
---

### New
Add `create_chatbot_s3_bucket.sh` to create AWS S3 buckets.


## 0.0.16 (2023-11-17)
---

### New
Add `get_localhost_ip.sh` to get the local IP, to be used in the local DNS server.


## 0.0.15 (2023-07-30)
---

### Fixes
Fix remove REGION variable from `get_lambda_url.sh`.


## 0.0.14 (2023-07-20)
---

### New
`back_file_w_date.sh` to backup a file with a date suffix.

### Fixes
Fix test script to do the .env file backup and restore.
Fix `set_fe_cloudfront_domain.sh` to handle the environment as a parameter.
Fix `run_mongo_docker.sh` to use `tests`, not `test`.
Fix container_name in `mongodb_stack_for_test.yml` to pin the container names and use effectively on the test script.


## 0.0.13 (2023-07-19)
---

### New
`scripts/aws/set_fe_cloudfront_domain.sh` to set the CloudFront domain name in the frontend for the CORS config [FA-91].
`scripts/aws/get_lambda_url.sh` to get the AWS Lambda URL to be configured in the frontend [FA-91].

### Changes
`scripts/add_github_submodules.sh` uses the GIT_SUBMODULE_URL environment variable.
`run_local` separated from `run` in `scripts/aws/run_aws.sh`, so `run` is for productions, and `run_local` is for local development.
`api_gateway_stage` added to configs.json in all stages, and the value comes from the AWS_API_GATEWAY_STAGE environment variable.


## 0.0.12 (2023-07-17)
---

### New
Add `GIT_SUBMODULE_URL` environment variable to allow the use of a different git repository for the database definitions [FA-91].

### Fixes
Fix Chalice deployment to AWS Lambda [FA-91].


## 0.0.11 (2023-07-15)
---

### New
Add make `run_qa` to use MongoDB dev instead of local docker container.
Add `set_chalice_cnf.sh` a message to be shown with action done.

### Fixes
Fix Chalice deployment with stages dev and prod.


## 0.0.10 (2023-07-12)
---

### New
Add support to Database definitions in JSON files from an external Git repository [FA-87].


## 0.0.9 (2023-07-11)
---

### New
Add `install_dev_tools.sh`.


## 0.0.8 (2023-06-09)
---

### New
Add Makefile entries to work with lint, yapf, pycodestyle, prospector, mypy, and coverage [FA-49].


## 0.0.7 (2023-06-02)
---

### New
Add "run_tests.sh" script to effectively call the unit tests using a local MongoDB database in Docker container [FA-6].


## 0.0.6 (2023-05-23)
---

### New
Add `run_mongo_docker.sh` to create a MongoDb local Docker container for develop.

### Changes
`set_chalice_cnf.sh` takes into account the MongoDb docker configuration.


## 0.0.5 (2023-02-11)
---

### New
Add `set_chalice_cnf.sh` to handle runtime changes to the ".chalice/config.json" file.


## 0.0.4 (2023-02-02)
---

### New
Add `run_aws.sh` to run the backend App in AWS cloud environments and the Chalice framework.


## 0.0.3 (2022-11-17)
---

### New
Add `run_app_tests.sh` to run test script, with mount and unmount the local docker MongoDB container.


## 0.0.2 (2022-03-16)
---

### New
Add `db_mongo_backup.sh` and `db_mongo_restore.sh` scripts to backup and restore MongoDB databases [FA-57].


## 0.0.1 (2022-03-10)
---

### New
Add scripts to run and test the referring App.