#!/bin/bash
# scripts/aws_tf/run-tf-deployment.sh
# Generic OpenTofu deployment wrapper for GenericSuite backend stacks.
# OpenTofu counterpart of scripts/aws_cf_processor/run-cf-deployment.sh.
# 2026-07-16 | CR [GS-334]
#
# Usage:
#   bash scripts/aws_tf/run-tf-deployment.sh ACTION STAGE STACK [EXTRA_TOFU_ARGS...]
#
# Parameters:
#   ACTION: init | validate | plan | apply | destroy | output
#   STAGE:  dev | qa | staging | demo | prod
#   STACK:  directory name under scripts/aws_tf/stacks (s3, dynamodb, kms,
#           secrets, ecr, domain, ec2, lambda)
#
# Environment:
#   CICD_MODE=1        -> non-interactive (-auto-approve on apply/destroy)
#   TF_STATE_BUCKET    -> override state bucket name
set -euo pipefail

REPO_BASEDIR="$(pwd)"
SCRIPTS_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

ACTION="${1:-}"
STAGE="${2:-}"
STACK="${3:-}"
if [ $# -ge 3 ]; then shift 3; else shift $#; fi

usage_abort() {
    echo "ERROR: $1"
    echo "Usage: $0 ACTION STAGE STACK [EXTRA_TOFU_ARGS...]"
    echo "  ACTION: init | validate | plan | apply | destroy | output"
    echo "  STAGE:  dev | qa | staging | demo | prod"
    echo "  STACK:  one of: $(ls "${SCRIPTS_DIR}/stacks" | tr '\n' ' ')"
    exit 1
}

if [ "${ACTION}" = "" ]; then usage_abort "ACTION is not set"; fi
if [ "${STAGE}" = "" ]; then usage_abort "STAGE is not set"; fi
if [ "${STACK}" = "" ]; then usage_abort "STACK is not set"; fi
if [ ! -d "${SCRIPTS_DIR}/stacks/${STACK}" ]; then usage_abort "Unknown STACK '${STACK}'"; fi
case "${ACTION}" in
    init|validate|plan|apply|destroy|output) ;;
    *) usage_abort "Unknown ACTION '${ACTION}'" ;;
esac

case "${STAGE}" in
    dev|qa|staging|demo|prod) ;;
    *) usage_abort "Unknown STAGE '${STAGE}'" ;;
esac

CICD_MODE="${CICD_MODE:-0}"

# Load the consuming app's .env
if [ -f "${REPO_BASEDIR}/.env" ]; then
    set -o allexport
    # shellcheck disable=SC1091
    . "${REPO_BASEDIR}/.env"
    set +o allexport
else
    echo "WARNING: no .env file in ${REPO_BASEDIR}"
fi

: "${APP_NAME:?ERROR: APP_NAME is not set}"
: "${AWS_REGION:?ERROR: AWS_REGION is not set}"

STAGE_UPPERCASE="$(echo "${STAGE}" | tr '[:lower:]' '[:upper:]')"
APP_NAME_LOWERCASE="$(echo "${APP_NAME}" | tr '[:upper:]' '[:lower:]')"

if [ "${AWS_ACCOUNT_ID:-}" = "" ]; then
    AWS_ACCOUNT_ID="$(aws sts get-caller-identity --output json --no-paginate 2>/dev/null | jq -r '.Account' || true)"
fi
if [ "${AWS_ACCOUNT_ID}" = "" ] || [ "${AWS_ACCOUNT_ID}" = "null" ]; then
    echo "ERROR: AWS_ACCOUNT_ID could not be retrieved. Configure AWS credentials."
    exit 1
fi

TF_STATE_BUCKET="${TF_STATE_BUCKET:-${APP_NAME_LOWERCASE}-tf-state-${AWS_ACCOUNT_ID}}"
bash "${SCRIPTS_DIR}/bootstrap-tf-state.sh" "${TF_STATE_BUCKET}" "${AWS_REGION}"

# Common TF_VARs (every stack declares only the ones it needs)
export TF_VAR_app_name="${APP_NAME_LOWERCASE}"
export TF_VAR_stage="${STAGE}"
export TF_VAR_aws_region="${AWS_REGION}"
export TF_VAR_aws_account_id="${AWS_ACCOUNT_ID}"
export TF_VAR_kms_key_alias="${KMS_KEY_ALIAS:-genericsuite-key}"
chatbot_bucket_varname="AWS_S3_CHATBOT_ATTACHMENTS_BUCKET_${STAGE_UPPERCASE}"
TF_VAR_chatbot_attachments_bucket_name="${!chatbot_bucket_varname:-}"
export TF_VAR_chatbot_attachments_bucket_name
if [ "${AWS_LAMBDA_FUNCTION_NAME:-}" != "" ]; then
    TF_VAR_lambda_function_name="$(echo "${AWS_LAMBDA_FUNCTION_NAME}-${STAGE}" | tr '[:upper:]' '[:lower:]')"
    export TF_VAR_lambda_function_name
fi
export TF_VAR_app_domain_name="${APP_DOMAIN_NAME:-}"

# Optional per-stack variable builder (e.g. secrets maps, dynamodb tables)
if [ -f "${SCRIPTS_DIR}/stacks/${STACK}/build-tfvars.sh" ]; then
    # shellcheck disable=SC1090
    . "${SCRIPTS_DIR}/stacks/${STACK}/build-tfvars.sh"
fi

cd "${SCRIPTS_DIR}/stacks/${STACK}"

echo ""
echo "RUN-TF-DEPLOYMENT | action=${ACTION} stage=${STAGE} stack=${STACK}"
echo "State: s3://${TF_STATE_BUCKET}/${STAGE}/${STACK}.tfstate"
echo ""

tofu init -reconfigure -input=false \
    -backend-config="bucket=${TF_STATE_BUCKET}" \
    -backend-config="key=${STAGE}/${STACK}.tfstate" \
    -backend-config="region=${AWS_REGION}" \
    -backend-config="encrypt=true" \
    -backend-config="use_lockfile=true"

APPROVE_ARG=""
if [ "${CICD_MODE}" = "1" ]; then
    APPROVE_ARG="-auto-approve"
fi

case "${ACTION}" in
    init)
        ;;
    validate)
        tofu validate "$@"
        ;;
    plan)
        tofu plan -input=false "$@"
        ;;
    apply)
        # shellcheck disable=SC2086
        tofu apply -input=false ${APPROVE_ARG} "$@"
        ;;
    destroy)
        # shellcheck disable=SC2086
        tofu destroy -input=false ${APPROVE_ARG} "$@"
        ;;
    output)
        tofu output "$@"
        ;;
esac

echo ""
echo "Done with '${ACTION}' over stack '${STACK}' (stage '${STAGE}')"
cd "${REPO_BASEDIR}"
