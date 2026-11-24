#!/usr/bin/python3 -I
"""Installs applications from the welcome screen's catalog, run as root through pkexec by the shell.

Usage: install-extras ID...

Each ID is an item of catalog.json. Its repository is added first, with the key pinned in the package, so
dnf checks every package's signature; RPM Fusion's own release packages are installed the same way when
missing. Items are installed one after another, and a failed one does not stop the rest. Progress goes to
stdout, one line each: "start ID", "done ID" or "failed ID MESSAGE". Only the user who ran pkexec is added
to groups or given a login shell.
"""

import json
import os
import pwd
import shutil
import subprocess
import sys

ROOT = "/usr/share/hyprdora"
CATALOG = f"{ROOT}/configs/extras/catalog.json"
REPOS = f"{ROOT}/configs/extras/repos"
KEYS = f"{ROOT}/keys"
BOOTSTRAP = "/etc/yum.repos.d/hyprdora-rpmfusion-bootstrap.repo"


class Failure(Exception):
    """A step that failed, with the line to show for it."""


def run(command):
    """Runs a command and raises Failure with its last line of output when it fails."""
    result = subprocess.run(command, check=False, capture_output=True, text=True)
    if result.returncode != 0:
        lines = [
            line.strip()
            for line in (result.stderr + result.stdout).splitlines()
            if line.strip()
        ]
        raise Failure(lines[-1] if lines else f"{command[0]} failed")


def installed(package):
    """Tells whether an RPM package is installed."""
    return (
        subprocess.run(
            ["rpm", "-q", package], check=False, capture_output=True
        ).returncode
        == 0
    )


def ensure_rpmfusion(kind):
    """Installs RPM Fusion's release packages, free and for nonfree also nonfree, through a temporary
    repository whose key is the one pinned in the package."""
    kinds = ["free"] if kind == "free" else ["free", "nonfree"]
    missing = [k for k in kinds if not installed(f"rpmfusion-{k}-release")]
    if not missing:
        return
    release = subprocess.run(
        ["rpm", "-E", "%fedora"], check=False, capture_output=True, text=True
    ).stdout.strip()
    sections = []
    for k in missing:
        sections.append(
            f"[hyprdora-rpmfusion-{k}]\n"
            f"name=RPM Fusion {k}, to install its release package\n"
            f"metalink=https://mirrors.rpmfusion.org/metalink?repo={k}-fedora-$releasever&arch=$basearch\n"
            "enabled=1\ngpgcheck=1\n"
            f"gpgkey=file://{KEYS}/rpmfusion-{k}-{release}.asc\n"
        )
    with open(BOOTSTRAP, "w") as f:
        f.write("\n".join(sections))
    try:
        run(["dnf", "install", "-y", *(f"rpmfusion-{k}-release" for k in missing)])
    finally:
        os.remove(BOOTSTRAP)


def ensure_flathub():
    """Adds Flathub, as the base system does, when it is missing."""
    run(
        [
            "flatpak",
            "remote-add",
            "--system",
            "--if-not-exists",
            "flathub",
            "https://dl.flathub.org/repo/flathub.flatpakrepo",
        ]
    )


def install(item, user):
    """Installs one item of the catalog and sets up what it needs."""
    if item.get("rpmfusion"):
        ensure_rpmfusion(item["rpmfusion"])
    if item.get("repo"):
        target = f"/etc/yum.repos.d/{item['repo']}.repo"
        if not os.path.exists(target):
            shutil.copyfile(f"{REPOS}/{item['repo']}.repo", target)
            os.chmod(target, 0o644)
    if item.get("packages"):
        run(
            [
                "dnf",
                "install",
                "-y",
                *(["--allowerasing"] if item.get("allowErasing") else []),
                *item["packages"],
            ]
        )
    if item.get("flatpaks"):
        ensure_flathub()
        run(
            [
                "flatpak",
                "install",
                "--system",
                "--noninteractive",
                "flathub",
                *item["flatpaks"],
            ]
        )
    for service in item.get("services", []):
        run(["systemctl", "enable", "--now", service])
    for group in item.get("userGroups", []):
        run(["usermod", "-aG", group, user])
    if item.get("loginShell"):
        run(["usermod", "-s", item["loginShell"], user])


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    if "PKEXEC_UID" not in os.environ:
        print("install-extras: run it through pkexec", file=sys.stderr)
        return 2
    with open(CATALOG) as f:
        catalog = json.load(f)
    items = {item["id"]: item for group in catalog["groups"] for item in group["items"]}
    user = pwd.getpwuid(int(os.environ["PKEXEC_UID"])).pw_name
    for item_id in sys.argv[1:]:
        if item_id not in items:
            print(f"failed {item_id} unknown item", flush=True)
            continue
        print(f"start {item_id}", flush=True)
        try:
            install(items[item_id], user)
            print(f"done {item_id}", flush=True)
        except (Failure, OSError) as error:
            print(f"failed {item_id} {error}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
