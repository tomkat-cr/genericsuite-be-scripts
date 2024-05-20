#!/bin/bash
# scripts/aws/clean_ecr_images.sh
# 2024-05-18 | CR
# Keep only the 2 latest ECR repositories

STAGE="$1"
PERFORM_DELETION="$2"
IMAGES_TO_KEEP="$3"

STAGE_UPPERCASE=$(echo ${STAGE} | tr '[:lower:]' '[:upper:]')

echo ""
echo "AWS ECR Docker Images cleaner"
echo "================================"
echo "Stage: ${STAGE_UPPERCASE}"
echo ""

if [ -z "${STAGE}" ]; then
    echo "STAGE is required"
    echo ""
    echo "Usage: $0 STAGE PERFORM_DELETION IMAGES_TO_KEEP"
    echo "Default values:"
    echo "  PERFORM_DELETION: 0"
    echo "  IMAGES_TO_KEEP: 2"
    exit 1
fi

if [ -z "${PERFORM_DELETION}" ]; then
    PERFORM_DELETION="0"
    echo "PERFORM_DELETION is not set, defaulting to ${PERFORM_DELETION}"
fi

if [ -z "${IMAGES_TO_KEEP}" ]; then
    IMAGES_TO_KEEP="2"
    echo "IMAGES_TO_KEEP is not set, defaulting to ${IMAGES_TO_KEEP}"
fi

export REPO_BASEDIR="`pwd`"
cd "`dirname "$0"`"
export SCRIPTS_DIR="`pwd`"
cd "${REPO_BASEDIR}"

# Load environment variables from .env
set -o allexport ; source .env ; set +o allexport

# AWS_S3_CHATBOT_ATTACHMENTS_BUCKET=$(eval echo \$AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_${STAGE_UPPERCASE})
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output json --no-paginate | jq -r '.Account')
AWS_LAMBDA_FUNCTION_NAME_AND_STAGE=$(echo ${AWS_LAMBDA_FUNCTION_NAME}-${STAGE_UPPERCASE} | tr '[:upper:]' '[:lower:]')

# DOCKER_IMAGE_NAME="${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}"
# AWS_DOCKER_IMAGE_URI_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
# AWS_DOCKER_IMAGE_URI="${AWS_DOCKER_IMAGE_URI_BASE}/${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}:latest"

# Prefix to filter repositories
prefix="${AWS_LAMBDA_FUNCTION_NAME_AND_STAGE}"

# Get a list of repositories filtered by prefix
repositories=$(aws ecr describe-repositories --query "repositories[?starts_with(repositoryName, '$prefix')].repositoryName" --output text)

echo ""
echo "Account: ${AWS_ACCOUNT_ID}"
echo "ECR repositories prefix: ${prefix}"
echo "Repositories to evaluate:"
echo "$repositories"

# Loop through each repository
for repository in $repositories; do
    # Get a list of images sorted by creation date (newest last)
    images=$(aws ecr describe-images --repository-name $repository --query 'sort_by(imageDetails,& imagePushedAt)[*].imageDigest' --output text)

    echo ""
    echo "All Images in ${repository}:"
    echo "${images}"

    # Count the number of images
    num_images=$(echo "$images" | wc -w)
    echo "Number of images: $num_images"

    # Keep only the two latest images
    # images_to_keep=$(echo "$images" | tail -n ${IMAGES_TO_KEEP})
    # images_to_keep=$(echo "$images" | head -n -$(( ${IMAGES_TO_KEEP} + 1 )) | tail -n ${IMAGES_TO_KEEP})
    images_to_keep=""
    index=${num_images}
    for image in $images; do
        if [ $index -lt $(( $IMAGES_TO_KEEP + 1 )) ]; then
            images_to_keep="${images_to_keep}${image} "
        fi
        index=$(( $index - 1 ))
    done

    echo ""
    echo "Images to keep:"
    echo "${images_to_keep}"
    
    # Loop through each image
    echo ""
    for image in $images; do
        echo "Image: $image | Repository: $repository"
        # Image name, version and date
        image_tags=$(aws ecr describe-images --repository-name $repository --image-ids imageDigest=$image --query 'imageDetails[0].imageTags' --output text)
        image_date=$(aws ecr describe-images --repository-name $repository --image-ids imageDigest=$image --query 'imageDetails[0].imagePushedAt' --output text)
        echo "Tag: ${image_tags}, Date pushed: ${image_date}"
        # Delete the image if it's not in the list of images to keep
        if ! echo "$images_to_keep" | grep -q "$image"; then
            if [ "$PERFORM_DELETION" = "1" ]; then
                echo "Deleting..."
                delete_response=$(aws ecr batch-delete-image --repository-name $repository --image-ids imageDigest=$image)
                echo "Delete response:"
                echo "${delete_response}"
                # Check if the image was deleted successfully
                if echo "${delete_response}" | grep -q "Error"; then
                    echo "Error deleting image $image from repository $repository"
                else
                    echo "Deleted"
                fi
            else
                echo "Image will be DELETED..."
            fi
        else
            echo "Image will be kept..."
        fi
        echo ""
    done
done
