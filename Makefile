QT_BIN ?= /usr/lib64/qt6/bin

QML_FILES := $(shell find shell -name '*.qml' 2>/dev/null)
SHELL_FILES := $(shell find kickstart -name '*.sh' 2>/dev/null)
PYTHON_FILES := $(shell find shell/scripts -name '*.py' 2>/dev/null)
LUA_FILES := $(shell find hypr -name '*.lua' 2>/dev/null)

.DEFAULT_GOAL := help
.PHONY: help dev lint lint-qml lint-shell lint-python lint-lua rpm iso

help:
	@echo "make dev    run the shell in a nested Hyprland (stage 1)"
	@echo "make lint   run all linters on existing files"
	@echo "make rpm    build RPM packages (stage 4)"
	@echo "make iso    build the install ISO (stage 5)"

lint: lint-qml lint-shell lint-python lint-lua

lint-qml:
ifneq ($(QML_FILES),)
	$(QT_BIN)/qmllint $(QML_FILES)
	@for file in $(QML_FILES); do \
		$(QT_BIN)/qmlformat "$$file" | diff -u "$$file" - || exit 1; \
	done
endif

lint-shell:
ifneq ($(SHELL_FILES),)
	shellcheck $(SHELL_FILES)
endif

lint-python:
ifneq ($(PYTHON_FILES),)
	ruff check $(PYTHON_FILES)
endif

lint-lua:
ifneq ($(LUA_FILES),)
	stylua --check $(LUA_FILES)
endif

dev rpm iso:
	@echo "make $@ is not implemented yet, see docs/roadmap.md" >&2
	@exit 1
