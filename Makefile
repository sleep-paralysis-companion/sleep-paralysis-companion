SHELL := /bin/bash

.PHONY: bootstrap format lint static privacy secrets simulator build unit ui verify

bootstrap:
	bash scripts/bootstrap.sh

format:
	bash scripts/format_check.sh

lint:
	bash scripts/lint_check.sh

static:
	bash scripts/static_check.sh

privacy:
	bash scripts/privacy_manifest_check.sh

secrets:
	bash scripts/secret_scan.sh

simulator:
	bash scripts/prepare_simulator.sh

build:
	bash scripts/build.sh

unit:
	bash scripts/unit_tests.sh

ui:
	bash scripts/ui_tests.sh

verify:
	bash scripts/verify_ci.sh
