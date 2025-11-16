# .DEFAULT_GOAL := local
.PHONY:  help install install_dev locked_dev locked_install lock_pip_file requirements clean clean_rm clean_temp_dir clean_logs fresh install_tools lsof test test_only lint types coverage format format_check qa mongo_docker mongo_docker_down mongo_backup mongo_restore config config_dev config_local config_qa config_qa_for_deployment config_staging build build_local build_check unbuild unbuild_qa unbuild_staging delete_stack create_s3_bucket_dev create_s3_bucket_qa create_s3_bucket_staging create_s3_bucket_prod create_s3_bucket_demo create_aws_config generate_sam_dynamodb deploy_qa deploy_run_local_qa deploy_validate_qa deploy_package_qa deploy_staging deploy_prod deploy_demo deploy run run_qa down_qa restart_qa run_local_docker run_prod add_submodules init_submodules local_dns local_dns_restart local_dns_rebuild local_dns_down local_dns_test copy_ssl_certs create_ssl_certs_only create_ssl_certs init_sam init_chalice generate_seed lock pre-publish publish pypi-build pypi-publish-test pypi-publish
SHELL := /bin/bash

## General Commands

help:
	cat Makefile

## Install dependecies

install:
	npm install # "npm install" is called before to install GS BE Scripts
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh install

install_dev:
	npm install # "npm install" is called before to install GS BE Scripts
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh install_dev

update:
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh update
	npm update

update_dev:
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh update_dev
	npm update

locked_dev:
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh locked_dev

locked_install:
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh locked_install

lock:
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh lock

# lock_pip_file:
# 	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh pipfile

requirements:
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh requirements

## Cleaning

clean: clean_rm clean_temp_dir clean_logs

clean_rm:
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh clean_rm

clean_temp_dir:
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh clean

clean_logs:
	bash node_modules/genericsuite-be-scripts/scripts/clean_logs.sh

fresh: clean_rm install

## CLI Utilities

install_tools:
	bash node_modules/genericsuite-be-scripts/scripts/install_dev_tools.sh

lsof:
	bash node_modules/genericsuite-be-scripts/scripts/run_lsof.sh

## Automated Testing

test:
	bash node_modules/genericsuite-be-scripts/scripts/run_app_tests.sh

test_only:
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_tests.sh

## Linting

lint:
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh lint

types:
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh types

coverage:
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh coverage

format:
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh format
	pycodestyle

format_check:
	bash node_modules/genericsuite-be-scripts/scripts/run_pem.sh format_check
	pycodestyle

## Development Commands

qa: lint types tests format_check pycodestyle

mongo_docker:
	bash node_modules/genericsuite-be-scripts/scripts/mongo/run_mongo_docker.sh run "0"

mongo_docker_down:
	bash node_modules/genericsuite-be-scripts/scripts/mongo/run_mongo_docker.sh down

mongo_backup:
	# E.g. STAGE=qa BACKUP_DIR=/tmp/exampleapp make mongo_backup
	bash node_modules/genericsuite-be-scripts/scripts/mongo/db_mongo_backup.sh ${STAGE} ${BACKUP_DIR}

mongo_restore:
	# E.g. STAGE=qa RESTORE_DIR=/tmp/exampleapp make mongo_restore
	bash node_modules/genericsuite-be-scripts/scripts/mongo/db_mongo_restore.sh ${STAGE} ${RESTORE_DIR}

link_gs_libs:
	bash node_modules/genericsuite-be-scripts/scripts/link_gs_libs_for_dev.sh

## Chalice Specific Commands

config:
	bash node_modules/genericsuite-be-scripts/scripts/aws/set_chalice_cnf.sh prod

config_dev:
	bash node_modules/genericsuite-be-scripts/scripts/aws/set_chalice_cnf.sh

config_local:
	bash node_modules/genericsuite-be-scripts/scripts/aws/set_chalice_cnf.sh mongo_docker

config_qa:
	bash node_modules/genericsuite-be-scripts/scripts/aws/set_chalice_cnf.sh qa

config_qa_for_deployment:
	bash node_modules/genericsuite-be-scripts/scripts/aws/set_chalice_cnf.sh qa deploy

config_staging:
	bash node_modules/genericsuite-be-scripts/scripts/aws/set_chalice_cnf.sh staging

build:
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh create_stack

build_local:
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh pipfile

build_check:
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh describe_stack

unbuild: unbuild_qa

unbuild_qa:
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh delete_app qa

unbuild_staging:
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh delete_app staging

delete_stack:
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh delete_stack

## AWS S3 and other

create_s3_bucket_dev:
	bash node_modules/genericsuite-be-scripts/scripts/aws/create_chatbot_s3_bucket.sh dev

create_s3_bucket_qa:
	bash node_modules/genericsuite-be-scripts/scripts/aws/create_chatbot_s3_bucket.sh qa

create_s3_bucket_staging:
	bash node_modules/genericsuite-be-scripts/scripts/aws/create_chatbot_s3_bucket.sh staging

create_s3_bucket_prod:
	bash node_modules/genericsuite-be-scripts/scripts/aws/create_chatbot_s3_bucket.sh prod

create_s3_bucket_demo:
	bash node_modules/genericsuite-be-scripts/scripts/aws/create_chatbot_s3_bucket.sh demo

create_aws_config:
	bash node_modules/genericsuite-be-scripts/scripts/aws/create_aws_config.sh

generate_sam_dynamodb:
	bash node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/generate_sam_dynamodb/run_generate_sam_dynamodb.sh

generate_cf_dynamodb:
	# make generate_cf_dynamodb
	# ACTION=create_tables STAGE=dev make generate_cf_dynamodb
	bash node_modules/genericsuite-be-scripts/scripts/aws_dynamodb/generate_dynamodb_cf/generate_dynamodb_cf.sh

## Deployment

deploy_qa: create_s3_bucket_qa
	bash node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy qa

deploy_run_local_qa: create_s3_bucket_qa
	bash node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/big_lambdas_manager.sh sam_run_local qa

deploy_validate_qa: create_s3_bucket_qa
	bash node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/big_lambdas_manager.sh sam_validate qa

deploy_package_qa: create_s3_bucket_qa
	bash node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/big_lambdas_manager.sh package qa

deploy_staging: create_s3_bucket_staging
	bash node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy staging

deploy_prod: create_s3_bucket_prod
	bash node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy prod

deploy_demo: create_s3_bucket_demo
	bash node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy demo

deploy_ecr_creation:
	bash node_modules/genericsuite-be-scripts/scripts/aws_ec2_elb/run-fastapi-ecr-creation.sh

deploy_ec2:
	# E.g.
	# CICD_MODE=0 ACTION=run STAGE=qa TARGET=ec2 ECR_DOCKER_IMAGE_TAG=0.0.16 make deploy_ec2
	# CICD_MODE=0 ACTION=destroy STAGE=qa TARGET=ec2 ECR_DOCKER_IMAGE_TAG=0.0.16 make deploy_ec2
	bash node_modules/genericsuite-be-scripts/scripts/aws_ec2_elb/run-ec2-cloud-deploy.sh

deploy_dynamodb:
	# CICD_MODE=0 ACTION=run STAGE=qa TARGET=dynamodb ENGINE=localstack make deploy_dynamodb
	# CICD_MODE=0 ACTION=run STAGE=qa TARGET=dynamodb make deploy_dynamodb
	bash node_modules/genericsuite-be-scripts/scripts/aws_dynamodb/run-dynamodb-deploy.sh

deploy: deploy_qa

## Secrets

generate_seed:
	# To assign the STORAGE_URL_SEED environment variable
	bash node_modules/genericsuite-be-scripts/scripts/cryptography/run_generate_seed.sh

aws_secrets:
	# E.g.
	# CICD_MODE=0 ACTION=run STAGE=qa TARGET=kms make aws_secrets
	# CICD_MODE=0 ACTION=run STAGE=qa TARGET=kms ENGINE=localstack make aws_secrets
	# CICD_MODE=0 ACTION=run STAGE=qa TARGET=secrets make aws_secrets
	bash node_modules/genericsuite-be-scripts/scripts/aws_secrets/aws_secrets_manager.sh

# aws_secrets_create:
# 	bash node_modules/genericsuite-be-scripts/scripts/aws_secrets/aws_secrets_manager.sh create

# aws_secrets_describe:
# 	bash node_modules/genericsuite-be-scripts/scripts/aws_secrets/aws_secrets_manager.sh describe

# aws_secrets_update:
# 	bash node_modules/genericsuite-be-scripts/scripts/aws_secrets/aws_secrets_manager.sh update

# aws_secrets_delete:
# 	bash node_modules/genericsuite-be-scripts/scripts/aws_secrets/aws_secrets_manager.sh delete

## Application Specific Commands

run: config_local clean_logs
	bash node_modules/genericsuite-be-scripts/scripts/mongo/run_mongo_docker.sh run "0" dev
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh run_local

run_qa: config_qa clean_logs
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh run_local qa

down_qa: config_qa clean_logs
	bash node_modules/genericsuite-be-scripts/scripts/secure_local_server/run.sh "down" ""

restart_qa: config_qa clean_logs
	bash node_modules/genericsuite-be-scripts/scripts/secure_local_server/run.sh "down" ""
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh run_local qa

run_local_docker: run

run_prod: config clean_logs
	bash node_modules/genericsuite-be-scripts/scripts/aws/run_aws.sh run

## Common JSON config

add_submodules:
	bash node_modules/genericsuite-be-scripts/scripts/add_github_submodules.sh

init_submodules:
	bash node_modules/genericsuite-be-scripts/scripts/init_json_configs.sh

## Local DNS server

local_dns:
	bash node_modules/genericsuite-be-scripts/scripts/dns/run_local_dns.sh

local_dns_restart:
	bash node_modules/genericsuite-be-scripts/scripts/dns/run_local_dns.sh restart

local_dns_rebuild:
	bash node_modules/genericsuite-be-scripts/scripts/dns/run_local_dns.sh rebuild

local_dns_down:
	bash node_modules/genericsuite-be-scripts/scripts/dns/run_local_dns.sh down

local_dns_test:
	bash node_modules/genericsuite-be-scripts/scripts/dns/run_local_dns.sh test

## Self-signed local SSL certificates

copy_ssl_certs:
	bash node_modules/genericsuite-be-scripts/scripts/local_ssl_certs_copy.sh

create_ssl_certs_only:
	bash node_modules/genericsuite-be-scripts/scripts/local_ssl_certs_creation.sh

create_ssl_certs: create_ssl_certs_only copy_ssl_certs

## GenericSuite Scripts

init_sam:
	bash node_modules/genericsuite-be-scripts/scripts/aws_big_lambda/init_sam.sh

init_chalice:
	bash node_modules/genericsuite-be-scripts/scripts/aws/init_chalice.sh

## NPM scripts library

# lock:
npm_lock:
	npm install --package-lock-only

pre-publish:
	bash scripts/npm_publish.sh pre-publish

publish:
	bash scripts/npm_publish.sh publish

## Pypi library scripts

pypi-build:
	# Build 'dist' directory needed for the Pypi publish
	poetry lock
	# poetry lock --no-update
	rm -rf dist
	python3 -m build

pypi-publish-test: pypi-build
	# Pypi Test publish
	python3 -m twine upload --repository testpypi dist/*

pypi-publish: pypi-build
	# Production Pypi publish
	python3 -m twine upload dist/*
