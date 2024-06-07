#!/bin/bash
# scripts/aws/create_chatbot_s3_bucket.sh
# Create AWS S3 bucket
# 2023-11-19 | CR
# Usage:
# AWS_S3_CHATBOT_ATTACHMENTS_CREATION=1 make create_s3_bucket_qa

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 environment. E.g. dev, qa, staging, prod"
  exit 1
fi

REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`" ;
SCRIPTS_DIR="`pwd`" ;
cd "${REPO_BASEDIR}"

set -o allexport ; . .env ; set +o allexport ;

# The "AWS_S3_CHATBOT_ATTACHMENTS_CREATION" variable must be "1"
# in ".env" file or externally to make this work

if [ "${AWS_S3_CHATBOT_ATTACHMENTS_CREATION}" = "1" ]; then
  if [ $1 = "dev" ]; then
    sh ${SCRIPTS_DIR}/create_s3_bucket.sh ${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_DEV}
  fi
  if [ $1 = "qa" ]; then
    sh ${SCRIPTS_DIR}/create_s3_bucket.sh ${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_QA}
  fi
  if [ $1 = "staging" ]; then
    sh ${SCRIPTS_DIR}/create_s3_bucket.sh ${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_STAGING}
  fi
  if [ $1 = "prod" ]; then
    sh ${SCRIPTS_DIR}/aws/create_s3_bucket.sh ${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_PROD}
  fi
  if [ $1 = "demo" ]; then
    sh ${SCRIPTS_DIR}/aws/create_s3_bucket.sh ${AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_DEMO}
  fi
else
  echo "AWS_S3_CHATBOT_ATTACHMENTS_CREATION is not set to 1"
fi
