#!/bin/sh
# run_api_gateway.sh
# 2023-12-10 | CR

if ! samlocal
then
  echo pip install aws-sam-cli-local
  pip install aws-sam-cli-local
fi

# echo ""
# echo samlocal build
# samlocal build

# echo ""
# echo samlocal deploy --guided
# samlocal deploy --guided

echo ""
echo samlocal local start-api -p ${API_GATEWAY_PORT:-8080}
samlocal local start-api -p ${API_GATEWAY_PORT:-8080}