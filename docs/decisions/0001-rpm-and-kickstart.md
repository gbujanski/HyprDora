# 1. RPM packages and kickstart

**Context.** The first HyprDora configured a netinst Fedora with bash scripts. Files placed that way have no owner: `dnf` cannot update or remove them, and reinstalling means re-running everything.

**Decision.** A `hyprdora` meta-package holds applications and default configs in `/usr/share/hyprdora`. Kickstart handles system-level setup, and `mkksiso` builds the ISO. A local `.rpm` is enough at first; a COPR or own repository can come later.

**Rejected.**

- Install scripts: the problems above.
- `bootc`: an image-based system needs an image build and a registry, which is more than this project needs for now.
