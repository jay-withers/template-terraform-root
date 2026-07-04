# Basic example — the configuration ci-terraform plans against.
#
# subscription_id is supplied via the ARM_SUBSCRIPTION_ID environment variable;
# use_oidc lets the provider authenticate with GitHub's OIDC token in CI.
#
# environment selects which tfvars file to plan with, e.g.
# `terraform plan -var-file=../../environments/dev.tfvars` — see
# terraform/environments/{dev,stg,prd}.tfvars.

provider "azurerm" {
  features {}
  use_oidc = true
}

variable "environment" {
  description = "Deployment environment. Selected via -var-file=../../environments/<dev|stg|prd>.tfvars."
  type        = string
}

module "basic" {
  source = "../../"

  environment = var.environment
}
