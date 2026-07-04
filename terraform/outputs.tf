# outputs.tf — values exported by this module.

output "environment" {
  description = "The deployment environment passed to the module."
  value       = var.environment
}

# Add further module outputs below.
#
# Example:
#
# output "id" {
#   description = "Identifier of the created resource."
#   value       = resource_type.this.id
# }
