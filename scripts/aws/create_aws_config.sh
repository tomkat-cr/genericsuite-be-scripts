#!/bin/sh
# Default values
if [ "${AWS_ACCESS_KEY_ID}" = "" ]; then
    export AWS_ACCESS_KEY_ID="test" ;
fi
if [ "${AWS_SECRET_ACCESS_KEY}" = "" ]; then
    export AWS_SECRET_ACCESS_KEY="test" ;
fi
if [ "${AWS_REGION}" = "" ]; then
    export AWS_REGION="us-east-1" ;
fi
# AWS local config dir creation
if [ ! -d "${HOME}/.aws" ]; then
    mkdir -p "${HOME}/.aws" ;
fi

# AWS local config files creation
if [ ! -f "${HOME}/.aws/credentials" ]; then

    cat > "${HOME}/.aws/credentials" <<END \

[default]
aws_access_key_id = test
aws_secret_access_key = test
END
    cat > "${HOME}/.aws/config" <<END \

[default]
region = test
output = json
END
    # Replace placeholders with values on environment variables
    perl -i -pe"s/aws_access_key_id = test/aws_access_key_id = ${AWS_ACCESS_KEY_ID}/g" "${HOME}/.aws/credentials" ;
    perl -i -pe"s/aws_secret_access_key = test/aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}/g" "${HOME}/.aws/credentials" ;
    perl -i -pe"s/region = test/region = ${AWS_REGION}/g" "${HOME}/.aws/config" ;
fi
