#!/bin/bash
# File: scripts/aws/set_fe_cloudfront_domain.sh
# 2023-07-18 | CR

ERROR_MSG=""
REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`" ;
SCRIPTS_DIR="`pwd`" ;
cd "${REPO_BASEDIR}"

ENV_FILESPEC=""
if [ -f "${REPO_BASEDIR}/.env" ]; then
    ENV_FILESPEC="${REPO_BASEDIR}/.env"
fi
if [ "$ENV_FILESPEC" != "" ]; then
    set -o allexport; source ${ENV_FILESPEC}; set +o allexport ;
fi

# Name of the S3 bucket
if [ "${AWS_S3_BUCKET_NAME_FE}" = "" ];then
    if [ "$2" = "" ];then
        echo "ERROR: If AWS_S3_BUCKET_NAME_FE is not set, second parameter must be the AWS S3 bucket name"
        exit 1
    else
        AWS_S3_BUCKET_NAME_FE="$2"
    fi
fi

# Region of the S3 bucket
if [ "${AWS_REGION}" = "" ];then
    echo "ERROR: AWS_REGION is not set"
    exit 1
fi

if [ "$1" = "" ];then
    echo "ERROR: Missing parameter(s). Usage:"
    echo "set_fe_cloudfront_domain.sh <environment> [<AWS S3 bucket name>]"
    echo "Environment must be: dev, qa, staging, demo or prod"
    echo "If AWS_S3_BUCKET_NAME_FE is not set, second parameter must be the AWS S3 bucket name."
    exit 1
fi

ENV="${1}"
ENV_UPPERCASE=$(echo $ENV | tr '[:lower:]' '[:upper:]')
echo ""
echo "ENV: ${ENV} | ENV_UPPERCASE: ${ENV_UPPERCASE}"
echo ""

echo ".env file backup..."
if ! BKP_FILE=$("${SCRIPTS_DIR}/../back_file_w_date.sh" .env); then
    echo "ERROR: Doing the .env file backup: ${BKP_FILE}"
    exit 1
fi
echo "Done... Backup file: ${BKP_FILE}"

echo ""
echo "Verifying the AWS Cloudfront distribution..."
echo ""

# Replace [STAGE] in the AWS_S3_BUCKET_NAME_FE value with $ENV value
BUCKET_NAME=$(echo $AWS_S3_BUCKET_NAME_FE | perl -i -pe"s/\[STAGE\]/${ENV}/g")

# Get CloudFront distribution ID
echo "Getting CloudFront distribution ID for S3 Bucket: '${BUCKET_NAME}'"
DIST_ID=$(aws cloudfront list-distributions \
--query "DistributionList.Items[?Origins.Items[0].DomainName=='${BUCKET_NAME}.s3.amazonaws.com'].{Id:Id}[0]" \
--output text)
echo "CloudFront Distribution ID: $DIST_ID"

# Verify existence of CloudFront distribution ID
echo "Verifying CloudFront distribution ID..."
if [ "${DIST_ID}" != "" ]; then
    aws cloudfront get-distribution --id ${DIST_ID} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "CloudFront Distribution ${DIST_ID} exists"
    else
        echo "CloudFront Distribution ${DIST_ID} does not exist"
        DIST_ID=""
    fi
fi

# Get CloudFront domain name
echo "Getting CloudFront domain name..."
DOMAIN_NAME=$(aws cloudfront get-distribution --id ${DIST_ID} --query 'Distribution.DomainName' --output text)
echo "CloudFront domain name: $DOMAIN_NAME"

echo "Updating .env file with cloudfront domain $DOMAIN_NAME"

# replace the line APP_CORS_ORIGIN_QA=... (can be anything, until the end of the line) in env file with the cloudfront domain, using perl -i -pe
if ! perl -i -pe"s|^APP_CORS_ORIGIN_${ENV_UPPERCASE}=.*|APP_CORS_ORIGIN_${ENV_UPPERCASE}=https://${DOMAIN_NAME}|g" .env
then
    echo "ERROR: Updating .env file with cloudfront domain $DOMAIN_NAME"
    exit 1
fi

echo ""
echo "Cloudfront domain update complete."
echo ""
