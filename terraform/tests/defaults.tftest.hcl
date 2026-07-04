# Module tests. The azurerm provider is mocked, so these run with no Azure
# credentials — both locally (`make test`) and in CI (ci-terraform).
#
# Add `assert` blocks as the module grows; see the commented example below.

mock_provider "azurerm" {}

run "plan_with_defaults" {
  # apply (against the mocked provider, so no real Azure calls) rather than
  # plan: the resource group's name comes from the naming module's random
  # suffix, which isn't known until after apply.
  command = apply

  variables {
    environment = "dev"
    location    = "uksouth"
  }

  assert {
    condition     = output.environment == "dev"
    error_message = "output environment did not match the requested environment"
  }

  assert {
    condition     = azurerm_resource_group.this.location == "uksouth"
    error_message = "resource group location did not match the requested location"
  }

  assert {
    condition     = strcontains(azurerm_resource_group.this.name, "dev")
    error_message = "resource group name did not include the environment"
  }
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "not-a-real-environment"
    location    = "uksouth"
  }

  expect_failures = [var.environment]
}

# Add further assert blocks as the module grows; see the commented example
# below.
#
# assert {
#   condition     = output.name == var.name
#   error_message = "output name did not match the requested name"
# }
