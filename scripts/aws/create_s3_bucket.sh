#!/bin/bash
# scripts/aws/create_s3_bucket.sh
# Create AWS S3 bucket
# Usage:    
# 2023-11-19 | CR

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 BUCKET_NAME [STAGE=qa] [MAKE_IT_PUBLIC=1]"
  exit 1
fi

STAGE="$2"
if [ "${STAGE}" = "" ]; then
  STAGE="qa"
fi
STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')

MAKE_IT_PUBLIC="$3"
if [ "${MAKE_IT_PUBLIC}" = "" ]; then
  MAKE_IT_PUBLIC="1"
fi

set -o allexport ; . .env ; set +o allexport ;

if [ "${APP_NAME}" = "" ]; then
    echo "APP_NAME not set"
    exit 1
fi

# Stop on any command error
set -e

BUCKET_NAME="$1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output json --no-paginate | jq -r '.Account')
AWS_PROFILE="default"
CREATION_DATE=$(date +%Y-%m-%d)
ENVIRONMENT=$(echo $BUCKET_NAME | awk -F '-' '{print tolower($NF)}')
export APP_NAME_LOWERCASE=$(echo ${APP_NAME} | tr '[:upper:]' '[:lower:]')
LAMBDA_ARN="arn:aws:lambda:us-east-1:${AWS_ACCOUNT_ID}:function:${APP_NAME_LOWERCASE}-backend-${ENVIRONMENT}"

export S3_BUCKET_POLICY="{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
        {
            \"Sid\": \"Allow${APP_NAME}${STAGE}ReadAccess\",
            \"Effect\": \"Allow\",
            "Principal": {
                "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:root",
                "Service": "${LAMBDA_ARN}"
            },
            "Action": [
                \"s3:ListBucketMultipartUploads\",
                \"s3:ListBucket\",
                \"s3:GetObjectTagging\",
                \"s3:GetObjectAcl\",
                \"s3:GetObject\",
                \"s3:DeleteObject\",
                \"s3:AbortMultipartUpload\"
            ],
            \"Resource\": [
                \"arn:aws:s3:::${BUCKET_NAME}/*\",
                \"arn:aws:s3:::${BUCKET_NAME}\"
            ]
        },
        {
            \"Sid\": \"Allow${APP_NAME}${STAGE}WriteAccess\",
            \"Effect\": \"Allow\",
            \"Principal\": {
                "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:root",
                "Service": "${LAMBDA_ARN}"
            },
            \"Action\": [
                \"s3:PutObjectAcl\",
                \"s3:PutObject\"
            ],
            \"Resource\": [
                \"arn:aws:s3:::${BUCKET_NAME}/*\",
                \"arn:aws:s3:::${BUCKET_NAME}\"
            ]
        },
        {
            \"Sid\": \"AllowPublicRead\",
            \"Effect\": \"Allow\",
            \"Principal\": \"*\",
            \"Action\": \"s3:GetObject\",
            \"Resource\": \"arn:aws:s3:::${BUCKET_NAME}/*\"
        }
    ]
}"

# aws s3 mb s3://$1
# aws s3api put-bucket-acl --bucket $1 --acl public-read

if aws s3api head-bucket --bucket ${BUCKET_NAME} --region ${AWS_REGION} --profile ${AWS_PROFILE} 2>/dev/null; then
    echo "Bucket ${BUCKET_NAME} already exists in region ${AWS_REGION} with profile ${AWS_PROFILE}."
else
    echo "Bucket ${BUCKET_NAME} does not exist in region ${AWS_REGION} with profile ${AWS_PROFILE}. Proceeding with creation."

    echo ""
    echo "1) " aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${AWS_REGION} --profile $AWS_PROFILE --acl bucket-owner-full-control --create-bucket-configuration LocationConstraint=${AWS_REGION} --output text
    # RESULT=$(aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${AWS_REGION} --profile $AWS_PROFILE --acl bucket-owner-full-control --create-bucket-configuration LocationConstraint=${AWS_REGION} --output text)
    RESULT=$(aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${AWS_REGION} --profile $AWS_PROFILE --acl bucket-owner-full-control  --output text)

    echo ""
    echo "Result: ${RESULT}"
    echo ""
    echo "S3 Bucket created: ${BUCKET_NAME} !"
    echo ""

    # Add a tag with the creation date and environment
    echo "1.2) " aws s3api put-bucket-tagging --bucket ${BUCKET_NAME} --tagging 'TagSet=[{Key=comment,Value="Created on '${CREATION_DATE}' in '${ENVIRONMENT}' environment."}]' --profile $AWS_PROFILE
    aws s3api put-bucket-tagging --bucket ${BUCKET_NAME} --tagging 'TagSet=[{Key=comment,Value="Created on '${CREATION_DATE}' in '${ENVIRONMENT}' environment."}]' --profile $AWS_PROFILE --output text

    if [ "${MAKE_IT_PUBLIC}" = "1" ]; then

    echo ""
    echo "1.3) " aws s3api put-bucket-acl --acl public-read --bucket ${BUCKET_NAME} --profile $AWS_PROFILE --region ${AWS_REGION}
    aws s3api put-bucket-acl --acl public-read --bucket ${BUCKET_NAME} --profile $AWS_PROFILE --region ${AWS_REGION} --output text
    echo ""

    # echo ""
    # echo "1.5) " s3api put-bucket-policy --bucket ${BUCKET_NAME} --profile $AWS_PROFILE --policy "${S3_BUCKET_POLICY}"
    # aws s3api put-bucket-policy --bucket ${BUCKET_NAME} --profile $AWS_PROFILE --region ${AWS_REGION} --policy "${S3_BUCKET_POLICY}"
    # echo ""

    # Enable ACLs for the bucket
    echo "2) " aws s3api put-bucket-acl --bucket $BUCKET_NAME --acl bucket-owner-full-control --profile $AWS_PROFILE
    aws s3api put-bucket-acl --bucket $BUCKET_NAME --acl bucket-owner-full-control --profile $AWS_PROFILE --output text
    echo ""

    # Set ACLs for the bucket owner
    echo "3) " aws s3api put-object-acl --bucket $BUCKET_NAME --key "" --grant-full-control id=$AWS_ACCOUNT_ID --profile $AWS_PROFILE
    aws s3api put-object-acl --bucket $BUCKET_NAME --key "" --grant-full-control id=$AWS_ACCOUNT_ID --profile $AWS_PROFILE --output text
    echo ""

    # Set ACLs for Everyone (public access)
    echo "4) " aws s3api put-object-acl --bucket $BUCKET_NAME --key "" --grant-read-acp uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $AWS_PROFILE
    aws s3api put-object-acl --bucket $BUCKET_NAME --key "" --grant-read-acp uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $AWS_PROFILE --output text
    echo ""
    
    echo "5) " aws s3api put-object-acl --bucket $BUCKET_NAME --key "" --grant-listing uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $AWS_PROFILE
    aws s3api put-object-acl --bucket $BUCKET_NAME --key "" --grant-listing uri=http://acs.amazonaws.com/groups/global/AllUsers --profile $AWS_PROFILE --output text
    echo ""

    echo "ACL enabled Object Ownership Permissions set successfully for: ${BUCKET_NAME} !"
    echo ""
    fi
fi
