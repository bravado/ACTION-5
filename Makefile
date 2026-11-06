# ACTION-5 development commands (GNU Make, Linux/macOS)
# The import target intentionally runs on every dependent invocation: Godot
# updates the generated .godot/ class registry and imported resources itself.
# Never check the generated .godot/ directory into version control.

.DEFAULT_GOAL := help
GODOT ?= godot
PYTHON ?= python3
PORT ?= 8765

WEB_EXPORT := build/web/index.html
LINUX_EXPORT := build/linux/action5-demo.x86_64

.PHONY: help import test run editor web linux build serve-web clean-build

help:
	@printf '%s\n' \
		'ACTION-5 (Godot 4.7.2) development commands:' \
		'  make import       Import resources and refresh the GDScript class registry' \
		'  make test         Import, then run all Godot headless tests' \
		'  make run          Import, then run the game' \
		'  make editor       Import, then open the Godot editor' \
		'  make web          Import, then export the browser build' \
		'  make linux        Import, then export a Linux x86_64 executable' \
		'  make build        Build both Linux and Web exports' \
		'  make serve-web    Export Web and serve it on localhost:$(PORT)' \
		'  make clean-build  Remove generated build/ files only' \
		'' \
		'Override executable paths as needed: make run GODOT=/path/to/godot'

import:
	$(GODOT) --headless --path . --import

test: import
	$(GODOT) --headless --path . --script res://tests/run_all.gd

run: import
	$(GODOT) --path .

editor: import
	$(GODOT) --editor --path .

web: import
	mkdir -p build/web
	$(GODOT) --headless --path . --export-release "Web" $(WEB_EXPORT)
	test -s $(WEB_EXPORT)
	test -s build/web/index.wasm
	test -s build/web/index.pck

linux: import
	mkdir -p build/linux
	$(GODOT) --headless --path . --export-release "Linux" $(LINUX_EXPORT)
	test -s $(LINUX_EXPORT)

build: linux web

serve-web: web
	$(PYTHON) -m http.server $(PORT) --bind 127.0.0.1 --directory build/web

clean-build:
	rm -rf build
