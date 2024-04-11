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
if [ "${ERROR_MSG}" = "" ]; then
    if [ "${AWS_S3_BUCKET_NAME_FE}" = "" ];then
        ERROR_MSG="AWS_S3_BUCKET_NAME_FE is not set"
    fi
fi
# Region of the S3 bucket
if [ "${ERROR_MSG}" = "" ]; then
    if [ "${AWS_REGION}" = "" ];then
        ERROR_MSG="AWS_REGION is not set"
    fi
fi

if [ "${ERROR_MSG}" = "" ]; then
    if [ "$1" = "" ];then
        ERROR_MSG="Missing parameter. Usage: set_fe_cloudfront_domain.sh <environment> (DEV, QA, STAGING, PROD)"
    else
        ENV="${1}"
        ENV_UPPERCASE=$(echo $ENV | tr '[:lower:]' '[:upper:]')
        echo ""
        echo "ENV: ${ENV} | ENV_UPPERCASE: ${ENV_UPPERCASE}"
        echo ""
    fi
fi

if [ "${ERROR_MSG}" = "" ]; then
    echo ".env file backup..."
    # cp .env .env.`date +%Y-%m-%d`.bak
    if ! BKP_FILE=$("${SCRIPTS_DIR}/../back_file_w_date.sh" .env); then
        ERROR_MSG="Doing the .env file backup: ${BKP_FILE}"
    else
        echo "Backup file: ${BKP_FILE}"
    fi
fi

if [ "${ERROR_MSG}" = "" ]; then
    echo "Verifying the AWS Cloudfront distribution..."
    BUCKET_NAME="${AWS_S3_BUCKET_NAME_FE}"

    # Get CloudFront distribution ID
    echo "Getting CloudFront distribution ID for S3 Bucket: '${AWS_S3_BUCKET_NAME_FE}' at '${AWS_REGION}'"
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
fi

if [ "${ERROR_MSG}" = "" ]; then
    # Get CloudFront domain name
    echo "Getting CloudFront domain name..."
    DOMAIN_NAME=$(aws cloudfront get-distribution --id ${DIST_ID} --query 'Distribution.DomainName' --output text)
    echo "CloudFront domain name: $DOMAIN_NAME"
fi

if [ "${ERROR_MSG}" = "" ]; then
    echo "Updating .env file with cloudfront domain $DOMAIN_NAME"
    
    # replace the line APP_CORS_ORIGIN_QA=... (can be anything, until the end of the line) in env file with the cloudfront domain, using perl -i -pe
    if ! perl -i -pe"s|^APP_CORS_ORIGIN_${ENV_UPPERCASE}=.*|APP_CORS_ORIGIN_${ENV_UPPERCASE}=https://${DOMAIN_NAME}|g" .env
    then
        ERROR_MSG='ERROR updating .env file with cloudfront domain $DOMAIN_NAME'
    fi
fi

echo ""
if [ "${ERROR_MSG}" = "" ]; then
    echo "Cloudfront domain update complete."
else
    echo "ERROR: ${ERROR_MSG}"
fi
echo ""
