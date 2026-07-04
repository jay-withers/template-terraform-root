# Module tests. The azurerm provider is mocked, so these run with no Azure
# credentials — both locally (`make test`) and in CI (ci-terraform).
#
# Add `assert` blocks as the module grows; see the commented example below.

mock_provider "azurerm" {}

run "plan_with_defaults" {
  command = plan

  variables {
    environment = "dev"
  }

  assert {
    condition     = output.environment == "dev"
    error_message = "output environment did not match the requested environment"
  }
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "not-a-real-environment"
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
