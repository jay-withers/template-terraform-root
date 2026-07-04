# Basic example — the configuration ci-terraform plans against.
#
# subscription_id is supplied via the ARM_SUBSCRIPTION_ID environment variable;
# use_oidc lets the provider authenticate with GitHub's OIDC token in CI.
#
# environment selects which tfvars file to plan with, e.g.
# `terraform plan -var-file=../../environments/dev.tfvars` — see
# terraform/environments/{dev,stg,prd}.tfvars.
#
# prevent_deletion_if_contains_resources is a provider-level feature (Azure
# refuses to delete a resource group that still contains resources not
# managed by this Terraform run) — it can't live in the module itself since
# modules shouldn't configure providers. It already defaults to true, but is
# set explicitly here so real consumers of this module know to set it in
# their own root provider block.
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
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
