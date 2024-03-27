# .DEFAULT_GOAL := local
# .PHONY: tests
SHELL := /bin/bash

# General Commands

help:
	cat Makefile

## Install dependecies

install:
	pipenv install

install_dev:
	pipenv install --dev

locked_dev:
	pipenv install --dev --ignore-pipfile

locked_install:
	pipenv install --ignore-pipfile

lock_pip_file:
	sh scripts/aws/run_aws.sh pipfile

requirements: lock_pip_file

## Cleaning

clean: clean_rm clean_temp_dir clean_logs

clean_rm:
	pipenv --rm

clean_temp_dir:
	sh scripts/aws/run_aws.sh clean

clean_logs:
	sh scripts/clean_logs.sh

fresh: clean_rm install

## CLI Utilities

install_tools:
	bash scripts/install_dev_tools.sh

lsof:
	sh scripts/run_lsof.sh

## Automated Testing

test:
	sh scripts/run_app_tests.sh

test_only:
	sh scripts/aws/run_tests.sh

## Linting

lint:
	pipenv run prospector

types:
	pipenv run mypy .

coverage:
	pipenv run coverage run -m unittest discover tests;
	pipenv run coverage report

format:
	pipenv run yapf -i *.py **/*.py **/**/*.py
	pycodestyle

format_check:
	pipenv run yapf --diff *.py **/*.py **/**/*.py
	pycodestyle

## Development Commands

qa: lint types tests format_check pycodestyle

mongo_docker:
	sh scripts/mongo/run_mongo_docker.sh run

mongo_docker_down:
	sh scripts/mongo/run_mongo_docker.sh down

## Chalice Specific Commands

config:
	sh scripts/aws/update_config.sh prod

config_dev:
	sh scripts/aws/update_config.sh

config_local:
	sh scripts/aws/update_config.sh mongo_docker

config_qa:
	sh scripts/aws/update_config.sh qa

config_qa_for_deployment:
	sh scripts/aws/update_config.sh qa deploy

config_staging:
	sh scripts/aws/update_config.sh staging

build:
	sh scripts/aws/run_aws.sh create_stack

build_local:
	sh scripts/aws/run_aws.sh pipfile

build_check:
	sh scripts/aws/run_aws.sh describe_stack

unbuild: unbuild_qa

unbuild_qa:
	sh scripts/aws/run_aws.sh delete_app qa

unbuild_staging:
	sh scripts/aws/run_aws.sh delete_app staging

delete_stack:
	sh scripts/aws/run_aws.sh delete_stack

## AWS S3 and other

create_s3_bucket_dev:
	sh scripts/aws/create_chatbot_s3_bucket.sh dev

create_s3_bucket_qa:
	sh scripts/aws/create_chatbot_s3_bucket.sh qa

create_s3_bucket_staging:
	sh scripts/aws/create_chatbot_s3_bucket.sh staging

create_s3_bucket_prod:
	sh scripts/aws/create_chatbot_s3_bucket.sh prod

create_aws_config:
	sh scripts/aws/create_aws_config.sh

## Deployment

deploy_qa: create_s3_bucket_qa
	sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy qa

deploy_validate_qa: create_s3_bucket_qa
	sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_validate qa

deploy_package_qa: create_s3_bucket_qa
	sh scripts/aws_big_lambda/big_lambdas_manager.sh package qa

deploy_staging: create_s3_bucket_staging
	sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy staging

deploy_prod: create_s3_bucket_prod
	sh scripts/aws_big_lambda/big_lambdas_manager.sh sam_deploy prod

deploy: deploy_qa

## Application Specific Commands

run: config_qa clean_logs
	sh scripts/aws/run_aws.sh run_local

run_qa: config_qa clean_logs
	sh scripts/aws/run_aws.sh run_local qa

down_qa: config_qa clean_logs
	sh scripts/secure_local_server/run.sh "down" ""

restart_qa: config_qa clean_logs
	sh scripts/secure_local_server/run.sh "down" ""
	sh scripts/aws/run_aws.sh run_local qa

run_local_docker: config_local clean_logs
	sh scripts/aws/run_aws.sh run_local dev

run_prod: config clean_logs
	sh scripts/aws/run_aws.sh run

## Common JSON config

add_submodules:
	sh scripts/add_github_submodules.sh

# Local DNS server

local_dns:
	sh scripts/dns/run_local_dns.sh

local_dns_restart:
	sh scripts/dns/run_local_dns.sh restart

local_dns_rebuild:
	sh scripts/dns/run_local_dns.sh rebuild

local_dns_down:
	sh scripts/dns/run_local_dns.sh down

local_dns_test:
	sh scripts/dns/run_local_dns.sh test

## Self-signed local SSL certificates

copy_ssl_certs:
	sh scripts/local_ssl_certs_copy.sh

create_ssl_certs_only:
	sh scripts/local_ssl_certs_creation.sh

create_ssl_certs: create_ssl_certs_only copy_ssl_certs

# NPM scripts library

lock:
	npm install --package-lock-only

pre-publish:
	sh scripts/npm_publish.sh pre-publish

publish:
	sh scripts/npm_publish.sh publish

# Pypi library scripts

pypi-build:
	# Build 'dist' directory needed for the Pypi publish
	poetry lock --no-update
	rm -rf dist
	python3 -m build

pypi-publish-test: pypi-build
	# Pypi Test publish
	python3 -m twine upload --repository testpypi dist/*

pypi-publish: pypi-build
	# Production Pypi publish
	python3 -m twine upload dist/*
