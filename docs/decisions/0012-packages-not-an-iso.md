# 12. Packages from COPR, applications on a welcome screen, no published ISO

**Context.** A published ISO would distribute everything on it: Fedora's and RPM Fusion's GPL packages, whose sources would have to go with it, codecs covered by patents, VS Code, whose license does not allow passing it on, and Apple's camera firmware. Installed systems also need somewhere to get HyprDora's updates from.

**Decision.**

- HyprDora publishes its code and its packages. Packit builds the packages in the COPR project `gbujanski/hyprdora` for each GitHub release; COPR keeps their sources. Local builds are numbered as snapshots after the last release, so the next release replaces them.
- `make iso` stays, to build an ISO for one's own use. Whoever builds it downloads every package from its maker, so nothing of theirs is distributed by HyprDora.
- Applications beyond the base, the browser and the full codecs among them, are chosen on a welcome screen at a user's first session, then the default applications among them. A helper installs them through pkexec from their makers' repositories, with keys pinned in the package. This replaced the `hyprdora-extras` package, which installed the author's own set for everyone.

**Rejected.**

- A published ISO with the sources of its packages beside it: possible, but every release would carry gigabytes of sources and the codec question would remain.
- A live image built with Kiwi or lorax, which would give Wi-Fi in the installer on a MacBook: a much larger build, and the whole of Fedora on the medium.
- Packages chosen in the installer: with a live image the installer copies the image and offers no choice, and an Anaconda add-on would tie HyprDora to the installer's internals.
- Repositories added with `repo` lines in the kickstart: the installer does not check package signatures.
