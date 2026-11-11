QT_BIN ?= /usr/lib64/qt6/bin
DEV_DIR := $(CURDIR)/build/dev/config
RPM_DIR := $(CURDIR)/build/rpm
VERSION := $(shell sed -n 's/^Version: *//p' packaging/hyprdora.spec)
ISO_DIR := $(CURDIR)/build/iso
ISO_SOURCE ?= $(ISO_DIR)/source/Fedora-Everything-netinst-x86_64-44-1.7.iso
ISO_OUT ?= $(ISO_DIR)/hyprdora-$(VERSION).iso
KICKSTART ?= kickstart/hyprdora.ks

# qmllint cannot see Quickshell's types or the qs.* modules, so these categories only report noise.
QMLLINT_FLAGS := --import disable --unqualified disable --unresolved-type disable --missing-type disable \
	--missing-property disable --uncreatable-type disable --required disable \
	--signal-handler-parameters disable --incompatible-type disable

QML_FILES := $(shell find shell -name '*.qml' 2>/dev/null)
SHELL_FILES := $(shell find kickstart -name '*.sh' 2>/dev/null) bin/hyprdora
PYTHON_FILES := $(shell find shell/scripts configs/nautilus configs/portal -name '*.py' 2>/dev/null)
LUA_FILES := $(shell find hypr -name '*.lua' 2>/dev/null)

.DEFAULT_GOAL := help
.PHONY: help dev lint lint-qml lint-shell lint-python lint-lua rpm install iso

help:
	@echo "make dev    run the shell in a nested Hyprland"
	@echo "make lint   run all linters on existing files"
	@echo "make rpm    build RPM packages"
	@echo "make install  build and install the hyprdora package on this system"
	@echo "make iso    build the install ISO"

lint: lint-qml lint-shell lint-python lint-lua

lint-qml:
ifneq ($(QML_FILES),)
	$(QT_BIN)/qmllint $(QMLLINT_FLAGS) $(QML_FILES)
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

dev:
	@mkdir -p $(DEV_DIR)/hypr $(DEV_DIR)/hyprdora
	@cp -n $(HOME)/.config/hyprdora/settings.json $(DEV_DIR)/hyprdora/ 2>/dev/null || true
	@cp -n $(HOME)/.config/hypr/settings.lua $(DEV_DIR)/hypr/ 2>/dev/null || true
	XDG_CONFIG_HOME=$(DEV_DIR) HYPRDORA_SHELL=$(CURDIR)/shell Hyprland --config $(CURDIR)/hypr/init.lua

rpm:
	@mkdir -p $(RPM_DIR)/SOURCES
	git ls-files -co --exclude-standard | xargs -d '\n' ls -d 2>/dev/null | \
		tar -czf $(RPM_DIR)/SOURCES/hyprdora-$(VERSION).tar.gz --transform 's,^,hyprdora-$(VERSION)/,' -T -
	rpmbuild -bb --define "_topdir $(RPM_DIR)" packaging/hyprdora.spec
	@echo "Packages are in $(RPM_DIR)/RPMS/noarch"

# The running shell and Hyprland reload changed files by themselves.
install: rpm
	sudo dnf reinstall -y $(RPM_DIR)/RPMS/noarch/hyprdora-$(VERSION)-*.noarch.rpm || \
		sudo dnf install -y $(RPM_DIR)/RPMS/noarch/hyprdora-$(VERSION)-*.noarch.rpm

iso: rpm
	rm -rf $(ISO_DIR)/content
	mkdir -p $(ISO_DIR)/content/hyprdora
	cp $(RPM_DIR)/RPMS/noarch/hyprdora*-$(VERSION)-*.rpm $(ISO_DIR)/content/hyprdora/
	createrepo_c -q $(ISO_DIR)/content/hyprdora
	rm -f $(ISO_OUT)
	sudo mkksiso --ks $(KICKSTART) --add $(ISO_DIR)/content/hyprdora -V HyprDora-44 $(ISO_SOURCE) $(ISO_OUT)
	sudo chown $(shell id -u):$(shell id -g) $(ISO_OUT)
	@echo "ISO is $(ISO_OUT)"
