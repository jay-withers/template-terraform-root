# variables.tf — module input variables.

variable "environment" {
  description = "Deployment environment. Drives environment-specific behaviour (naming, sizing, etc.) as the module grows."
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "environment must be one of: dev, stg, prd."
  }
}

# Add further module input variables below.
#
# Example:
#
# variable "name" {
#   description = "Name applied to created resources."
#   type        = string
# }
