# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

A GitHub repository template providing pre-commit hooks, CI workflows (linting, auto-tagging), Renovate dependency updates, and Makefile scaffolding.

## Commands

```bash
make install   # install pre-commit hooks (run once after cloning)
make lint      # run all pre-commit hooks against every file
```

## Commit messages

Commits must follow [Conventional Commits](https://www.conventionalcommits.org/) — enforced by commitlint at commit-msg time. Examples: `feat: add tflint`, `fix: correct arch detection`, `chore: update Brewfile`.

## Pre-commit config

Hooks are in `config/.pre-commit-config.yaml` (not the repo root). Pass `--config config/.pre-commit-config.yaml` to any `pre-commit` command run manually. The `no-commit-to-branch` hook blocks direct commits to `main`.

## CI

- **pre-commit**: runs all linters on PRs to `main`
- **tag**: auto-creates a semver tag on every merge to `main` (default bump: patch)
