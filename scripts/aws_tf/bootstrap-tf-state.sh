#!/bin/bash
# scripts/aws_tf/bootstrap-tf-state.sh
# Create/verify the S3 bucket that stores OpenTofu remote state.
# 2026-07-16 | CR [GS-334]
# Usage: bash scripts/aws_tf/bootstrap-tf-state.sh BUCKET_NAME AWS_REGION
set -euo pipefail

BUCKET_NAME="${1:-}"
AWS_REGION="${2:-}"

if [ "${BUCKET_NAME}" = "" ] || [ "${AWS_REGION}" = "" ]; then
    echo "Usage: $0 BUCKET_NAME AWS_REGION"
    exit 1
fi

if aws s3api head-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}" 2>/dev/null; then
    echo "TF state bucket '${BUCKET_NAME}' already exists."
    exit 0
fi

echo "Creating TF state bucket '${BUCKET_NAME}' in '${AWS_REGION}'..."
if [ "${AWS_REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}" --output text
else
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}" \
        --create-bucket-configuration "LocationConstraint=${AWS_REGION}" --output text
fi

aws s3api put-bucket-versioning --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "TF state bucket '${BUCKET_NAME}' created (versioned, encrypted, private)."
