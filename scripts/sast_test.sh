#!/bin/bash
# scripts/sast_test.sh
# 2026-04-17 | CR

FAILED_TESTS="0"

run() {
    echo ""
    echo "Run: $@"
    $@
    if [ $? -ne 0 ]; then
        FAILED_TESTS="1"
    fi
}

verify_envvar() {
    if [ -z "${1}" ]; then
        echo "${2} is not set"
        exit 1
    fi
}

ask_to_continue() {
    echo ""
    echo "Do you want to continue? (y/n)"
    read -r answer
    if [ "${answer}" != "y" ]; then
        exit 1
    fi
}

set -o allexport; source .env ; set +o allexport ;

verify_envvar "${SNYK_ENVIRONMENT}" "SNYK_ENVIRONMENT"
verify_envvar "${SNYK_ORG}" "SNYK_ORG"
verify_envvar "${SNYK_API_KEY}" "SNYK_API_KEY"

run snyk config environment ${SNYK_ENVIRONMENT}
snyk auth ${SNYK_API_KEY}
run snyk code test --severity-threshold=high --org=${SNYK_ORG} --all-projects ${SNYK_ADDITIONAL_FLAGS} .
run snyk test --severity-threshold=high --org=${SNYK_ORG} --all-projects ${SNYK_ADDITIONAL_FLAGS} .

if [ "${FAILED_TESTS}" = "1" ]; then
    echo "SAST tests failed"
    if [ "${CICD}" = "1" ]; then
        exit 1
    else
        ask_to_continue
    fi
else
    echo "SAST tests passed"
fi


