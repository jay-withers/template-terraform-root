# repo-template

A GitHub repository template providing pre-commit hooks, CI workflows, Renovate dependency updates, and Makefile scaffolding.

## Development

Install pre-commit hooks:

```bash
make install
```

Run linting:

```bash
make lint
```

Test the Linux setup in a local Docker container (requires Docker Desktop):

```bash
make test
```

## Structure

```text
config/
  .pre-commit-config.yaml
  commitlint.config.js
.github/
  workflows/
    pre-commit.yml   # lints all files on PRs to main
    tag.yml          # auto-tags on merge to main (semver patch bump)
renovate.json        # automated dependency updates
Makefile
```
