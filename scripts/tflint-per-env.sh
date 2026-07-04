#!/usr/bin/env bash
# Runs tflint against terraform/ once per environment tfvars file
# (terraform/environments/*.tfvars) so rules that depend on concrete variable
# values (naming, tags, region-specific checks) are evaluated against what
# each environment actually deploys, not just unresolved variables.
# Environments are discovered dynamically — add a new one by dropping a new
# tfvars file in terraform/environments/, no config changes needed here.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
tf_dir="$repo_root/terraform"

shopt -s nullglob
tfvars_files=("$tf_dir"/environments/*.tfvars)
shopt -u nullglob

if [ ${#tfvars_files[@]} -eq 0 ]; then
  echo "error: no tfvars files found in $tf_dir/environments" >&2
  exit 1
fi

tflint --init --chdir="$tf_dir" --config="$tf_dir/.tflint.hcl"

status=0
for tfvars in "${tfvars_files[@]}"; do
  env=$(basename "$tfvars" .tfvars)
  echo "==> tflint ($env)"
  if ! tflint --chdir="$tf_dir" --config="$tf_dir/.tflint.hcl" --var-file="$tfvars"; then
    status=1
  fi
done

exit "$status"
