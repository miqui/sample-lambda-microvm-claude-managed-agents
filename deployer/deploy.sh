#!/usr/bin/env bash
# Thin wrapper: runs one command (or an interactive shell) inside the
# lambda-microvm-deployer container, with the repo mounted and credentials
# resolved from 1Password on the HOST. Secrets never enter the image.
#
# Usage:
#   ./deploy.sh "sam build"
#   ./deploy.sh "sam deploy --guided --capabilities CAPABILITY_NAMED_IAM \
#     --parameter-overrides AnthropicEnvironmentId=env_..."
#   ./deploy.sh "src/scripts/build-image.sh claude-microvm-sandbox"
#   ./deploy.sh                                   # interactive shell
#
# First time: docker build -t lambda-microvm-deployer .
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE=lambda-microvm-deployer
REPO_DIR="$(cd "${DIR}/.." && pwd)"

docker image inspect "$IMAGE" >/dev/null 2>&1 \
  || { echo "Image '$IMAGE' not built yet: cd $DIR && docker build -t $IMAGE ." >&2; exit 1; }

# Resolve credentials from 1Password via `op run --env-file` on the host.
# Only the keys we need are forwarded into the container; the resolved
# values live in a temp file that is deleted on exit.
ENV_TMP="$(mktemp /tmp/deployer-env.XXXXXX)"
trap 'rm -f "$ENV_TMP"' EXIT
op run --env-file "${DIR}/env.tmpl" -- env \
  | grep -E '^(AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|ANTHROPIC_API_KEY)=' \
  > "$ENV_TMP"
if ! grep -q '=' "$ENV_TMP"; then
  echo "Failed to resolve credentials from 1Password (env.tmpl)." >&2
  exit 1
fi

# Docker socket mount is optional (only needed for `sam build --use-container`,
# which this design avoids because the image already has Python 3.14).
DOCKER_SOCK=()
if [[ -S /var/run/docker.sock ]]; then
  DOCKER_SOCK=(-v /var/run/docker.sock:/var/run/docker.sock)
fi

exec docker run --rm -it \
  -v "$REPO_DIR":/repo \
  -w /repo \
  "${DOCKER_SOCK[@]}" \
  --env-file "$ENV_TMP" \
  "$IMAGE" \
  ${1:-/bin/bash} "$@"
