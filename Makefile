CONFIG := config/.pre-commit-config.yaml

.PHONY: install lint

install:
	pre-commit install --config $(CONFIG)
	pre-commit install --hook-type commit-msg --config $(CONFIG)

lint:
	pre-commit run --all-files --config $(CONFIG)
