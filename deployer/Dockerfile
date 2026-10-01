# Deployer container for sample-lambda-microvm-claude-managed-agents.
# Contains every tool the deploy needs; the repo is mounted at runtime and
# credentials are injected via env-file — nothing sensitive is baked in.
#
# Build:   docker build -t lambda-microvm-deployer .
# Run:     ./deploy.sh "sam build"   (or interactive: ./deploy.sh)
FROM python:3.14-slim-bookworm

ARG AWS_CLI_VERSION=2.36.42

# curl/unzip: fetch AWS CLI v2. zip: used by build-image.sh.
# git: repo ops inside the mount. jq: stack-output parsing convenience.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl unzip zip git jq ca-certificates bash \
    && rm -rf /var/lib/apt/lists/*

# AWS CLI v2 from the official binary bundle (no python deps).
RUN curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m)-${AWS_CLI_VERSION}.zip" \
        -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# SAM CLI via pipx on the image's Python 3.14 — matches the template's
# Runtime python3.14, so `sam build` works WITHOUT --use-container
# (no Docker-in-Docker / socket mount needed).
RUN pip install --no-cache-dir pipx && pipx install aws-sam-cli
ENV PATH="/root/.local/bin:${PATH}"

# Lambda MicroVMs service model, extracted from the repo's own vendored
# botocore wheel (src/functions/wheels/botocore-*.whl ->
# botocore/data/lambda-microvms/2025-09-09/service-2.json.gz).
# Registered into the AWS CLI at image build time.
COPY lambda-microvms.json /opt/lambda-microvms.json
RUN aws configure add-model --service-model file:///opt/lambda-microvms.json

# Non-interactive-friendly defaults.
ENV AWS_PAGER="" \
    AWS_DEFAULT_REGION=us-east-1

WORKDIR /repo

# No ENTRYPOINT/CMD: deploy.sh runs one command per invocation, or an
# interactive shell when called with no argument.
