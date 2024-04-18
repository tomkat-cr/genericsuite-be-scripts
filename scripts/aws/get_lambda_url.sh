#!/bin/bash
# scripts/aws/get_lambda_url.sh
# Get Lambda function URL
# 2023-07-18 | CR

ERROR_MSG=""
REPO_BASEDIR="`pwd`"

ENV_FILESPEC=""
if [ -f "${REPO_BASEDIR}/.env" ]; then
    ENV_FILESPEC="${REPO_BASEDIR}/.env"
fi
if [ "$ENV_FILESPEC" != "" ]; then
    set -o allexport; source ${ENV_FILESPEC}; set +o allexport ;
fi

# AWS Lambda function name
if [ "${ERROR_MSG}" = "" ]; then
    if [ "${AWS_LAMBDA_FUNCTION_NAME}" = "" ];then
        ERROR_MSG="AWS_LAMBDA_FUNCTION_NAME is not set"
    fi
fi
# API Gateway stage name
# if [ "${ERROR_MSG}" = "" ]; then
#     if [ "${AWS_API_GATEWAY_STAGE}" = "" ];then
#         ERROR_MSG="AWS_API_GATEWAY_STAGE is not set"
#     fi
# fi
# Region of the S3 bucket
if [ "${ERROR_MSG}" = "" ]; then
    if [ "${AWS_REGION}" = "" ];then
        ERROR_MSG="AWS_REGION is not set"
    fi
fi
# AWS Lambda function stage (parameter # 1 of this script)
if [ "${ERROR_MSG}" = "" ]; then
    if [ "$1" = "" ];then
        ERROR_MSG="AWS Lambda function stage must be specified as parameter # 1"
    fi
fi

if [ "${ERROR_MSG}" = "" ]; then
    # Stage name
    LAMBDA_STAGE="$1"

    echo ""
    echo "Getting Lambda function info..."
    echo "Function name: $AWS_LAMBDA_FUNCTION_NAME"
    echo "Region: ${AWS_REGION}"
    echo ""

    # Get Lambda function ARN
    LAMBDA_ARN=$(aws lambda get-function --function-name ${AWS_LAMBDA_FUNCTION_NAME}-${LAMBDA_STAGE} --query 'Configuration.FunctionArn' --region ${AWS_REGION} --output text)

    # LAMBDA_CONFIG=$(aws lambda get-function --function-name ${AWS_LAMBDA_FUNCTION_NAME}-${LAMBDA_STAGE} --query 'Configuration' --region ${AWS_REGION} --output json)

    # LAMBDA_ALL_DATA=$(aws lambda get-function --function-name ${AWS_LAMBDA_FUNCTION_NAME}-${LAMBDA_STAGE}  --region ${AWS_REGION} --output json)

    echo ""
    echo "Lambda ARN: $LAMBDA_ARN"
    # echo ""
    # echo "Lambda Config: $LAMBDA_CONFIG"
    # echo ""
    # echo "Lambda All Data: $LAMBDA_ALL_DATA"

    # Get API ID from Lambda ARN
    # API_ID_RAW=$(echo $LAMBDA_ARN | awk -F":" '{print $7}')

    API_ID=$(aws apigateway get-rest-apis --query "items[?name=='${AWS_LAMBDA_FUNCTION_NAME}'].id" --output text --region ${AWS_REGION})

    echo ""
    echo "API ID: $API_ID"
    # echo "API ID RAW (response from aws-cli): $API_ID_RAW"

    # Get root resource
    # APIGATEWAY_ALL_RESOURCES=$(aws apigateway get-resources --rest-api-id $API_ID --output json --region ${AWS_REGION})

    # ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/'].id" --output text --region ${AWS_REGION})

    # echo ""
    # echo "ROOT ID: $ROOT_ID"
    # echo "APIGATEWAY_ALL_RESOURCES: $APIGATEWAY_ALL_RESOURCES"

    # Get invoke URL

    # APIGATEWAY_ALL_STAGE_INFO=$(aws apigateway get-stage --rest-api-id $API_ID --stage-name ${AWS_API_GATEWAY_STAGE} --output json --region ${AWS_REGION})

    # APIGATEWAY_ALL_APIREST_INFO=$(aws apigateway get-rest-api --rest-api-id $API_ID --stage-name ${AWS_API_GATEWAY_STAGE} --output json --region ${AWS_REGION})

    # API_URL=$(aws apigateway get-stage --rest-api-id $API_ID --stage-name ${AWS_API_GATEWAY_STAGE} --query "invokeUrl" --output text --region ${AWS_REGION})

    DOMAIN_NAME="${API_ID}.execute-api.${AWS_REGION}.amazonaws.com"
    API_URL="https://${DOMAIN_NAME}"

    echo ""
    echo "API URL: $API_URL"
    # echo "APIGATEWAY_ALL_RESOURCES: $APIGATEWAY_ALL_STAGE_INFO"

    # Print URL 
    # echo ""
    # echo "API URL + ROOT_ID: $API_URL$ROOT_ID"
fi

echo ""
if [ "${ERROR_MSG}" = "" ]; then
    echo "Done!"
else
    echo "ERROR: ${ERROR_MSG}"
fi
echo ""
