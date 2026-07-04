# main.tf — module resources.

locals {
  default_tags = {
    environment = var.environment
    managed-by  = "terraform"
  }

  # Applied to every resource below; var.tags takes precedence on conflicts.
  tags = merge(local.default_tags, var.tags)
}

module "naming" {
  # checkov:skip=CKV_TF_1: Terraform Registry module pinned by semver
  # (version below), not a git source — there's no commit hash to pin.
  source  = "Azure/naming/azurerm"
  version = "~> 0.4"
  suffix  = [var.environment]
}

resource "azurerm_resource_group" "this" {
  name     = module.naming.resource_group.name_unique
  location = var.location
  tags     = local.tags
}

# Add further module resources below, then declare their inputs in
# variables.tf and outputs in outputs.tf.
