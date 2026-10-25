# docker-atlantis-op

[![Build](https://github.com/aurimasniekis/docker-atlantis-op/actions/workflows/build.yml/badge.svg)](https://github.com/aurimasniekis/docker-atlantis-op/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[Atlantis](https://www.runatlantis.io) Docker image with the [1Password CLI](https://developer.1password.com/docs/cli/).
Configuration and Terraform credentials are `op://` secret references, resolved at startup from a
**1Password service account** or a **1Password Connect** server. The container needs only one secret.

```
docker-entrypoint.sh (upstream, dumb-init)
 └─ atlantis-op          validates 1Password auth, loads *_FILE secrets
     └─ op run           resolves op:// refs from env + OP_ENV_FILE
         └─ atlantis server
             └─ terraform   1Password provider authenticates with the same env, no config needed
```

```sh
docker pull ghcr.io/aurimasniekis/docker-atlantis-op:latest
```

## Authentication

Set exactly one of these:

| Mode            | Variables                                                         |
| --------------- | ----------------------------------------------------------------- |
| Service account | `OP_SERVICE_ACCOUNT_TOKEN` or `OP_SERVICE_ACCOUNT_TOKEN_FILE`     |
| Connect server  | `OP_CONNECT_HOST` + `OP_CONNECT_TOKEN` or `OP_CONNECT_TOKEN_FILE` |

The `*_FILE` variants read the value from a file (Docker / Compose / Kubernetes secrets) and are
unset before Atlantis starts. If both modes or neither are set, the container refuses to start.

## Providing secrets

There are two ways, and you can mix them:

**An env file** (default path `/etc/atlantis/atlantis.env.op`), in dotenv format with `op://` references
or plain values:

```sh
ATLANTIS_GH_USER=my-github-user
ATLANTIS_GH_TOKEN=op://Atlantis/GitHub/token
ATLANTIS_GH_WEBHOOK_SECRET=op://Atlantis/GitHub/webhook_secret
ATLANTIS_REPO_ALLOWLIST=github.com/my-github-user/my-infra-repo

# Terraform backend credentials (backends can't read from providers)
AWS_ACCESS_KEY_ID=op://Atlantis/Terraform State/access_key_id
AWS_SECRET_ACCESS_KEY=op://Atlantis/Terraform State/secret_access_key
```

**References directly in the environment:**

```sh
docker run -e ATLANTIS_GH_TOKEN=op://Atlantis/GitHub/token …
```

| Variable      | Default                         | Description                                                                 |
| ------------- | ------------------------------- | --------------------------------------------------------------------------- |
| `OP_ENV_FILE` | `/etc/atlantis/atlantis.env.op` | Comma-separated env files. The default is optional; explicitly set files must exist. |

All Atlantis [server configuration](https://www.runatlantis.io/docs/server-configuration) works as
usual through `ATLANTIS_*` variables or flags.

Secrets are resolved **once at startup**, so restart the container after rotating one.

## Terraform

Every Terraform run inherits the 1Password credentials, so the
[1Password provider](https://registry.terraform.io/providers/1Password/onepassword) works without any
configuration. Use **ephemeral** items so provider credentials never reach state:

```hcl
provider "onepassword" {}

data "onepassword_vault" "atlantis" {
  name = "Atlantis"
}

ephemeral "onepassword_item" "github" {
  vault = data.onepassword_vault.atlantis.uuid
  title = "GitHub Terraform"
}

provider "github" {
  token = ephemeral.onepassword_item.github.credential
}
```

The same code runs on a laptop with the 1Password desktop app: set `OP_ACCOUNT` locally and nothing else.
See [`examples/terraform`](examples/terraform).

## Examples

- [`examples/service-account`](examples/service-account/compose.yaml): Compose with a service account token as a Docker secret
- [`examples/connect`](examples/connect/compose.yaml): Compose with self-hosted Connect (`connect-api` + `connect-sync`)
- [`examples/atlantis.env.op`](examples/atlantis.env.op), [`examples/repos.yaml`](examples/repos.yaml): shared config

```sh
cd examples/service-account
mkdir -p secrets && printf %s "$OP_SERVICE_ACCOUNT_TOKEN" > secrets/op_service_account_token
cp .env.example .env    # set ATLANTIS_ATLANTIS_URL
docker compose up -d
```

## Image

| Tag                        | Description                          |
| -------------------------- | ------------------------------------ |
| `latest`                   | Latest build from `main`             |
| `v0.49.0`                  | Atlantis version (floating)          |
| `v0.49.0-op2.41.1`         | Atlantis + 1Password CLI versions    |
| `sha-<commit>`             | Exact build                          |

Images are built for `linux/amd64` and `linux/arm64`. Dependabot keeps the Atlantis and
1Password CLI base images up to date.

- **Base:** `ghcr.io/runatlantis/atlantis` (Alpine), with the same entrypoint, user (`atlantis`) and healthcheck
- **Added:** `/usr/local/bin/op` and `/usr/local/bin/atlantis-op`
- **Data:** `/home/atlantis/.atlantis`. Mount a volume here.

The image contains no secrets, only the tooling to resolve them.

Running other commands works too, still under `op run`:

```sh
docker run --rm -e OP_SERVICE_ACCOUNT_TOKEN … ghcr.io/aurimasniekis/docker-atlantis-op sh -c 'echo $ATLANTIS_GH_USER'
```

## Security notes

- Anyone who can open a PR on an allowed repo can run code during `plan` (e.g. `external` data sources).
  That code can read the 1Password credentials from its environment. Scope the service account or
  Connect token to a **dedicated vault** holding only what Atlantis needs, and keep
  `ATLANTIS_REPO_ALLOWLIST` tight.
- Keep workflows and requirements in a server-side `repos.yaml` with `allow_custom_workflows: false`.
- `op run` masks resolved secret values in Atlantis' own stdout and stderr.

## License

[MIT](LICENSE)
