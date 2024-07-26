#!/bin/bash

# GitHub token and URL
REPO=${REPO}
ACCESS_TOKEN=${TOKEN}
RUNNER_LABELS=${RUNNER_LABELS}
RUNNER_WORKDIR=${RUNNER_WORKDIR:-_work}

REG_TOKEN=$(curl -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/repos/${REPO}/actions/runners/registration-token | jq .token --raw-output)

cd /home/docker/actions-runner

# Configure the runner
./config.sh --url https://github.com/${REPO} \
    --token ${REG_TOKEN} \
    --name $(hostname) \
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

# Run the runner
./run.sh & wait $!