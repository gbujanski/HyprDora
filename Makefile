QT_BIN ?= /usr/lib64/qt6/bin
DEV_DIR := $(CURDIR)/build/dev/config
RPM_DIR := $(CURDIR)/build/rpm
# The package's own version; hyprdora-release follows Fedora's instead.
VERSION := $(shell sed -n 's/^Version: *//p' packaging/hyprdora.spec | head -1)
# The Fedora release to build for; another one builds hyprdora-release ahead of an upgrade.
FEDORA ?= $(shell rpm -E %fedora)
ISO_DIR := $(CURDIR)/build/iso
ISO_SOURCE ?= $(ISO_DIR)/source/Fedora-Everything-netinst-x86_64-44-1.7.iso
ISO_OUT ?= $(ISO_DIR)/hyprdora-$(VERSION).iso
KICKSTART ?= kickstart/hyprdora.ks


QML_FILES := $(shell find shell -name '*.qml' 2>/dev/null)
SHELL_FILES := $(shell find kickstart configs packaging tools -name '*.sh' 2>/dev/null) bin/hyprdora
PYTHON_FILES := $(shell find shell/scripts configs/nautilus configs/portal configs/calendar packaging/logo tools -name '*.py' 2>/dev/null)
LUA_FILES := $(shell find hypr configs/nvim -name '*.lua' 2>/dev/null)

.DEFAULT_GOAL := help
.PHONY: help dev lint lint-qml lint-shell lint-python lint-lua lint-i18n rpm install iso

help:
	@echo "make dev    run the shell in a nested Hyprland"
	@echo "make lint   run all linters on existing files"
	@echo "make rpm    build RPM packages"
	@echo "make install  build and install the hyprdora package on this system"
	@echo "make iso    build the install ISO"

lint: lint-qml lint-shell lint-python lint-lua lint-i18n

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

# Every language has the same keys as English, in alphabetical order.
lint-i18n:
	python3 -I tools/check-i18n.py shell/i18n/*.json

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
	rpmbuild -bb --define "_topdir $(RPM_DIR)" --define "fedora $(FEDORA)" packaging/hyprdora.spec
	@echo "Packages are in $(RPM_DIR)/RPMS/noarch"

# Neither Hyprland nor the shell takes in a package update by itself: Hyprland misses replaced files, and a
# live shell reload misses new files. Both are restarted; the shell loses its notification history.
# Hyprland would reload itself for each config file the package replaces, and every reload makes the
# screen flash, so autoreload is off during the install and one reload follows; it also turns autoreload
# back on. The shell does not watch its installed files and is restarted once.
install: rpm
	-hyprctl eval 'hl.config({ misc = { disable_autoreload = true } })' >/dev/null
	# hyprdora-extras goes along when installed, as some of the desktop's defaults live in it.
	pkgs="$$(ls $(RPM_DIR)/RPMS/noarch/hyprdora-$(VERSION)-*.noarch.rpm)"; \
	if rpm -q hyprdora-extras >/dev/null 2>&1; then pkgs="$$pkgs $$(ls $(RPM_DIR)/RPMS/noarch/hyprdora-extras-$(VERSION)-*.noarch.rpm)"; fi; \
	sudo dnf reinstall -y $$pkgs || sudo dnf install -y $$pkgs || { hyprctl reload >/dev/null; exit 1; }
	-hyprctl reload >/dev/null
	-systemctl --user daemon-reload
	-systemctl --user try-restart hyprdora-shell.service

iso: rpm
	rm -rf $(ISO_DIR)/content
	packaging/iso/build-repo.sh $(KICKSTART) $(RPM_DIR)/RPMS/noarch $(ISO_DIR)/content/hyprdora
	packaging/iso/make-product.sh $(ISO_DIR)/content/images/product.img
	rm -f $(ISO_OUT)
	# The installer is Fedora's: product.img gives it HyprDora's name and look, inst.profile picks HyprDora's
	# profile in it, and the boot menu names HyprDora.
	sudo mkksiso --ks $(KICKSTART) --add $(ISO_DIR)/content/hyprdora --add $(ISO_DIR)/content/images \
		-c inst.profile=hyprdora -R "Fedora $(FEDORA)" "HyprDora $(FEDORA)" -R "a Fedora system" "a HyprDora system" \
		-V HyprDora-$(FEDORA) $(ISO_SOURCE) $(ISO_OUT)
	sudo chown $(shell id -u):$(shell id -g) $(ISO_OUT)
	@echo "ISO is $(ISO_OUT)"
