# ACTION-5 development commands (GNU Make, Linux/macOS)
# The import target intentionally runs on every dependent invocation: Godot
# updates the generated .godot/ class registry and imported resources itself.
# Never check the generated .godot/ directory into version control.

.DEFAULT_GOAL := help
# Avoid parallel import/export writes to the same Godot resource cache.
.NOTPARALLEL:
SHELL := /bin/bash
GODOT ?= godot
RUN_ARGS ?=
PYTHON ?= python3
PORT ?= 8765

WEB_EXPORT := build/web/index.html
LINUX_EXPORT := build/linux/action5-demo.x86_64

.PHONY: help verify-assets check import test run editor web linux build serve-web clean-build

help:
	@printf '%s\n' \
		'ACTION-5 (Godot 4.7.2) development commands:' \
		'  make import       Import resources and refresh the GDScript class registry' \
		'  make test         Import, then run all Godot headless tests' \
		'  make check        Verify asset fixtures and run the PR checks locally' \
		'  make run          Import, then run the game' \
		'  make editor       Import, then open the Godot editor' \
		'  make web          Import, then export the browser build' \
		'  make linux        Import, then export a Linux x86_64 executable' \
		'  make build        Build both Linux and Web exports' \
		'  make serve-web    Export Web and serve it on localhost:$(PORT)' \
		'  make clean-build  Remove generated build/ files only' \
		'' \
		'Override executable paths as needed: make run GODOT=/path/to/godot'

verify-assets:
	@node tools/generate_training_character.mjs
	@node tools/generate_alternate_training_character.mjs
	@git diff --exit-code -- demo/assets/action5_training_character.glb tests/fixtures/alternate_training_character.glb
	@echo ACTION5_D04_GLB_REPRO_OK

# Run the same quick checks as PR CI. Godot's import happens just once.
check: verify-assets test

import:
	@mkdir -p build/logs
	@set -o pipefail; $(GODOT) --headless --path . --import 2>&1 | tee build/logs/import.log
	@$(PYTHON) tools/check_godot_log.py build/logs/import.log

test: import
	@set -o pipefail; $(GODOT) --headless --path . --script res://tests/run_all.gd 2>&1 | tee build/logs/test.log
	@$(PYTHON) tools/check_godot_log.py build/logs/test.log

run: import
	$(GODOT) --path . $(RUN_ARGS)

editor: import
	$(GODOT) --editor --path .

web: import
	@mkdir -p build/web
	@set -o pipefail; $(GODOT) --headless --path . --export-release "Web" $(WEB_EXPORT) 2>&1 | tee build/logs/export-web.log
	@$(PYTHON) tools/check_godot_log.py build/logs/export-web.log
	test -s $(WEB_EXPORT)
	test -s build/web/index.js
	test -s build/web/index.wasm
	test -s build/web/index.pck

linux: import
	@mkdir -p build/linux
	@set -o pipefail; $(GODOT) --headless --path . --export-release "Linux" $(LINUX_EXPORT) 2>&1 | tee build/logs/export-linux.log
	@$(PYTHON) tools/check_godot_log.py build/logs/export-linux.log
	test -s $(LINUX_EXPORT)
	test -x $(LINUX_EXPORT)

build: linux web
	@$(PYTHON) tools/check_exports.py

serve-web: web
	$(PYTHON) -m http.server $(PORT) --bind 127.0.0.1 --directory build/web

clean-build:
	rm -rf build
