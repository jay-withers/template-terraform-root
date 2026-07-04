TF_DIR := terraform
ENV ?= dev

.DEFAULT_GOAL := help

.PHONY: help install configure-github lint init fmt validate plan test

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

install: ## Install pre-commit hooks (run once after cloning)
	pre-commit install
	pre-commit install --hook-type commit-msg

configure-github: ## Configure GitHub repo settings for a template-derived repo (auto-merge, branch protection) via gh CLI
	./scripts/configure-github.sh

lint: ## Run all pre-commit hooks against every file
	pre-commit run --all-files

init: ## terraform init
	terraform -chdir=$(TF_DIR) init

fmt: ## terraform fmt -recursive
	terraform -chdir=$(TF_DIR) fmt -recursive

validate: init ## terraform init + validate
	terraform -chdir=$(TF_DIR) validate

plan: init ## terraform init + plan (set ENV=dev|stg|prd, default dev)
	terraform -chdir=$(TF_DIR) plan -var-file=environments/$(ENV).tfvars

test: init ## terraform test (mocked azurerm provider — no Azure auth)
	terraform -chdir=$(TF_DIR) test
