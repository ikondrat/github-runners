#!/bin/bash

# GitHub token and URL
REPO=${REPO}
ACCESS_TOKEN=${TOKEN}
RUNNER_NAME=${RUNNER_NAME:-"custom-runner"}
RUNNER_LABELS=${RUNNER_LABELS}
RUNNER_WORKDIR=${RUNNER_WORKDIR:-_work}

# Function to get a new registration token
get_registration_token() {
    REG_TOKEN=$(curl -s -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/repos/${REPO}/actions/runners/registration-token | jq .token --raw-output)
    if [[ -z "$REG_TOKEN" || "$REG_TOKEN" == "null" ]]; then
        echo "Failed to obtain registration token"
        exit 1
    fi
}

# API token is valid nly one hour
# https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#create-a-registration-token-for-an-organization
TOKEN_EXPIRATION_TIME=3600  # 1 hour

# Get the initial registration token
get_registration_token

cd /home/docker/actions-runner

# Configure the runner
./config.sh --url https://github.com/${REPO} \
    --token ${REG_TOKEN} \
    --name "$RUNNER_NAME-$(hostname)" \
    --labels $RUNNER_LABELS \
    --work $RUNNER_WORKDIR \
    --unattended \
    --replace

cleanup() {
    echo "Removing runner..."
    ./config.sh remove --unattended --token ${REG_TOKEN}
    exit
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# Function to renew the expired token
renew_token_if_needed() {
    while true; do
        sleep $TOKEN_EXPIRATION_TIME  # Check every hour; adjust as needed
        echo "Renewing token..."
        get_registration_token
        ./config.sh --url https://github.com/${REPO} \
            --token ${REG_TOKEN} \
            --name "$RUNNER_NAME-$(hostname)" \
            --labels $RUNNER_LABELS \
            --work $RUNNER_WORKDIR \
            --unattended \
            --replace
    done
}

# Run the token renewal in the background
renew_token_if_needed &

# Run the runner
./run.sh & wait $!
