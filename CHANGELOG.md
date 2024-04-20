# CHANGELOG

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a Changelog](http://keepachangelog.com/).



## Unreleased
---

### New

### Changes

### Fixes

### Breaks


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