# deployer/

Tooling container that runs the deploy commands for this project
(`sam build`/`sam deploy`, `src/scripts/build-image.sh`, the SSM parameter
steps, `src/scripts/verify.py`) so nothing has to be installed on the host
beyond Docker + the 1Password CLI.

- `Dockerfile` — Python 3.14 base (matches the template's `python3.14`
  runtime, so `sam build` works without `--use-container`), AWS CLI v2,
  SAM CLI via pipx, and the Lambda MicroVMs service model.
- `lambda-microvms.json` — the `lambda-microvms` service model, extracted
  from this repo's own vendored botocore wheel
  (`src/functions/wheels/botocore-*.whl` →
  `botocore/data/lambda-microvms/2025-09-09/service-2.json.gz`), registered
  into the AWS CLI at image build time via `aws configure add-model`.
- `env.tmpl` — 1Password references (resolved on the host by deploy.sh;
  never baked into the image).
- `deploy.sh` — runs one command (or an interactive shell) in the container
  with the repo mounted at `/repo` and credentials injected.

## Usage

```bash
cd deployer
docker build -t lambda-microvm-deployer .

./deploy.sh "sam build"
./deploy.sh "sam deploy --guided --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides AnthropicEnvironmentId=env_..."
./deploy.sh "aws ssm put-parameter --type SecureString \
  --name /claude-microvm-sandbox/anthropic-environment-key \
  --value <environment-key>"        # value comes from the Claude Console
./deploy.sh "src/scripts/build-image.sh claude-microvm-sandbox"
./deploy.sh                          # interactive shell for verify.py etc.
```

Host prerequisites: Docker Desktop running, `op` signed in to the
`my.1password.com` account with the `hermes1` vault.
