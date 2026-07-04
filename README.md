# template-terraform

A GitHub repository template for Azure Terraform modules, providing a dev container,
Terraform pre-commit hooks (fmt, validate, tflint w/ the `azurerm` ruleset,
terraform-docs, checkov), CI workflows, and Renovate dependency updates. The
module scaffold creates an `azurerm_resource_group`, named via
[Azure/naming/azurerm](https://registry.terraform.io/modules/Azure/naming/azurerm/latest)
— replace/extend it with real resources as the module grows.

## Getting started

Open the repository in the dev container (VS Code: **Reopen in Container**, or
GitHub Codespaces). The container ships with Terraform, TFLint, terraform-docs,
and Checkov, and runs `make install` on creation to wire up the pre-commit hooks.

Outside a dev container, install the hooks manually:

```bash
make install
```

## Commands

Run `make` (or `make help`) to list the available targets:

```bash
make install           # install pre-commit hooks (run once after cloning)
make configure-github  # configure GitHub repo settings (auto-merge, branch protection)
make lint              # run all pre-commit hooks against every file
make fmt               # terraform fmt -recursive
make validate          # terraform init + validate
make plan              # terraform init + plan the basic example (set ENV=dev|stg|prd, default dev)
make test              # terraform test (mocked azurerm provider — no Azure auth needed)
```

`fmt`/`validate`/`test` run against the `terraform/` module directory via
`-chdir`. `plan` runs against `terraform/examples/basic/` instead — the module
itself has no provider block (by design; modules shouldn't configure
providers), so it can't be planned on its own. See [Azure auth for `terraform
plan`](#azure-auth-for-terraform-plan) below: `make plan` creates a real
`azurerm_resource_group`, so — unlike `fmt`/`validate`/`test` — it needs real
Azure credentials. The Terraform version is pinned in `.terraform-version`
(used by tfenv/tenv and CI).

## Testing

`terraform/tests/*.tftest.hcl` holds the module's tests. They mock the `azurerm`
provider, so `make test` (and the `ci-terraform` **test** job) run with no Azure
credentials. Add `assert` blocks as the module grows.

## Environments

`terraform/environments/{dev,stg,prd}.tfvars` hold per-environment inputs for
the module and for root configs like `terraform/examples/basic/`. `make plan`
picks one via `ENV` (default `dev`):

```bash
make plan            # plans the basic example with environments/dev.tfvars
make plan ENV=stg    # plans the basic example with environments/stg.tfvars
make plan ENV=prd    # plans the basic example with environments/prd.tfvars
```

Planning a different root config (e.g. the example) directly needs a
`-var-file` path relative to *that* config's own directory:

```bash
terraform -chdir=terraform/examples/basic plan -var-file=../../environments/dev.tfvars
```

These files are **committed, not gitignored** — see `.gitignore`. Don't put
secrets in them; use Azure Key Vault, GitHub Actions secrets, or `ARM_*`
environment variables instead. `gitleaks` (pre-commit and CI) scans every
commit as a backstop. The module's `environment` input (`terraform/variables.tf`)
validates against exactly these three values.

## File layout convention

Every root config and the module itself follow a fixed layout, enforced (not
just documented): `locals`/`variable`/`output` blocks must live in a matching
`locals.tf`/`variables.tf`/`outputs.tf`, or a topic-scoped variant of any of
them (e.g. `outputs.network.tf`, `locals.network.tf`), via the local
pre-commit hook `check-tf-file-layout` (`scripts/check-tf-file-layout.sh`).
`main.tf` is left for resources, data sources, and module blocks.

## Linting against every environment

`make lint` runs TFLint and Checkov once per file in `terraform/environments/`
(via `scripts/tflint-per-env.sh` and `scripts/checkov-per-env.sh`, wired in as
local pre-commit hooks) rather than once with unresolved variables. Passing
each environment's real `-var-file` gives rules that depend on concrete
values — resource naming, tags, region-specific checks — something to
actually evaluate. Both scripts glob `terraform/environments/*.tfvars` at
run time, so adding a new environment's tfvars file is enough to get it
linted — no `.pre-commit-config.yaml` change needed. `tflint-per-env.sh` also
lints every directory under `terraform/` with `.tf` files (the module and
`terraform/examples/basic/`, and any future example) since tflint doesn't
recurse into subdirectories the way Checkov does.

Checkov does *not* run with `--download-external-modules` — it was tried, but
cost ~15s per invocation regardless of caching (checkov's own graph-building
overhead, not network time) for zero benefit, since `Azure/naming/azurerm` has
no resources of its own to find. Checkov logs a harmless "Failed to download
module" warning as a result; revisit if the module tree grows to include
modules with real resources.

## Tags and resource protection

The module applies default tags (`environment`, `managed-by = "terraform"`) to
every resource it creates, merged with — and overridable by — `var.tags`. See
`terraform/locals.tf`'s `local.default_tags`.

Azure-side deletion protection (`prevent_deletion_if_contains_resources`) is a
provider `features` block setting, so it can't live in the module itself
(modules shouldn't configure providers). `terraform/examples/basic/main.tf`
sets it explicitly — it already defaults to `true` in the `azurerm` provider,
but consumers of this module should set it in their own root provider block
too, since the module can't do it for them.

## Azure auth for `terraform plan`

The module creates a real `azurerm_resource_group`, so both `make plan` and
the `ci-terraform` **plan** job need real Azure credentials — `terraform test`
(mocked provider) is the only credential-free check.

In CI, the `ci-terraform` **plan** job runs `terraform plan` against
`terraform/examples/basic/` once per environment (`environments/{dev,stg,prd}.tfvars`,
as a matrix) using GitHub OIDC (no long-lived secrets). It is **skipped until
you set the `AZURE_CLIENT_ID` repository variable**, so a freshly created repo
stays green until Azure auth is wired up. All three environments currently
share one Azure subscription (`ARM_SUBSCRIPTION_ID`) — if you later split
environments across subscriptions, the `plan` job's matrix is where to wire up
per-environment credentials. To enable it:

1. Create an Azure app registration / managed identity and add a **federated
   credential** trusting this repository's GitHub Actions.
2. Grant it the roles it needs on the target subscription.
3. Add three **repository variables** (Settings → Secrets and variables →
   Actions → Variables): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
   `AZURE_SUBSCRIPTION_ID`.

Locally, `make plan` uses whatever the `azurerm` provider picks up normally —
`az login`, or `ARM_*` environment variables for a service principal/OIDC.

## Configuring GitHub for a repo created from this template

Some settings can't be templated as files and need to be set once per repo via
the GitHub API. Run, with the [`gh` CLI](https://cli.github.com) authenticated
as an account with admin rights on the new repo:

```bash
make configure-github
```

This is idempotent (safe to re-run) and:

- Enables repository **auto-merge**, which `renovate.json`'s
  `platformAutomerge` setting depends on — without it, Renovate's PRs sit
  fully green forever with nothing to merge them.
- Enables **delete branch on merge**, so merged Renovate branches don't pile up.
- Creates a ruleset on the default branch requiring these status checks before
  merge, enforced on everyone including Renovate:
  - **ci-pre-commit** — `pre-commit` job
  - **ci-terraform** — the `ci-terraform` gate job (always runs and reports
    even when a PR has no Terraform changes — do **not** require `test`/`plan`
    directly, require this gate instead)
- Creates a second ruleset requiring 1 approving review before merge, with the
  Renovate GitHub App exempted (so its automerge still works) — this is a
  separate ruleset because a review requirement can't be selectively bypassed
  within a single ruleset's other rules.

Set `RENOVATE_APP_ID=<id>` (e.g. `RENOVATE_APP_ID=123 make configure-github`) if
you run a self-hosted Renovate under a different bot account — the script
otherwise derives the app ID from the `renovate[bot]` user's avatar URL, which
only works for the public Renovate app.

## Structure

```text
.devcontainer/
  devcontainer.json    # dev container (ghcr.io/jay-withers/dev-container/terraform)
.terraform-version     # pinned Terraform version (tfenv/tenv + CI)
terraform/
  versions.tf          # required_version / required_providers
  main.tf              # resources (azurerm_resource_group, named via Azure/naming/azurerm)
  locals.tf            # local values (e.g. default tags)
  variables.tf         # inputs (environment, location, tags)
  outputs.tf           # outputs
  README.md            # generated by terraform-docs
  .terraform-docs.yml  # terraform-docs config (also in examples/basic/)
  .tflint.hcl          # TFLint config (terraform + azurerm rulesets)
  tests/
    defaults.tftest.hcl  # terraform test (mocked azurerm provider)
  environments/
    dev.tfvars         # -var-file inputs per environment (committed, not gitignored)
    stg.tfvars
    prd.tfvars
  examples/
    basic/             # example ci-terraform plans against (main.tf, variables.tf, outputs.tf)
.pre-commit-config.yaml
commitlint.config.js
CONTRIBUTING.md         # contributor workflow and expectations
.github/
  CODEOWNERS
  pull_request_template.md
  ISSUE_TEMPLATE/
    bug_report.yml
    feature_request.yml
    config.yml
  workflows/
    ci-pre-commit.yml  # lints all files on PRs to main
    ci-terraform.yml   # terraform test + plan (matrix over dev/stg/prd), gated to Terraform changes
    cd-tag.yml         # auto-tags on merge to main (semver patch bump)
renovate.json          # automated dependency updates
scripts/
  configure-github.sh       # one-time GitHub settings (auto-merge, branch protection)
  check-tf-file-layout.sh   # pre-commit hook: enforces locals/variables/outputs file layout
  tflint-per-env.sh         # pre-commit hook: tflint once per terraform/environments/*.tfvars
  checkov-per-env.sh        # pre-commit hook: checkov once per terraform/environments/*.tfvars
Makefile
```
