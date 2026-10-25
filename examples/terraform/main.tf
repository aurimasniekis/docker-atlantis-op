# Terraform side: the 1Password provider picks up the same credentials Atlantis
# runs with (OP_SERVICE_ACCOUNT_TOKEN, or OP_CONNECT_HOST + OP_CONNECT_TOKEN).
# Nothing to configure.

terraform {
  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.4"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }
}

provider "onepassword" {}

data "onepassword_vault" "atlantis" {
  name = "Atlantis"
}

# Ephemeral: the token is never written to state or plan files.
ephemeral "onepassword_item" "github" {
  vault = data.onepassword_vault.atlantis.uuid
  title = "GitHub Terraform"
}

provider "github" {
  token = ephemeral.onepassword_item.github.credential
}
