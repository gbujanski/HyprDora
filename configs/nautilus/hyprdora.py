"""Nautilus menu item for HyprDora: open a folder in a terminal.

Setting a wallpaper needs no item here: Nautilus's own "Set as Background" goes through the
HyprDora wallpaper portal.
"""

import os
import subprocess

import gi

gi.require_version("Nautilus", "4.1")
from gi.repository import GObject, Nautilus

LABELS = {
    "en": {"terminal": "Open in Terminal"},
    "pl": {"terminal": "Otwórz w terminalu"},
}


def label(key):
    """Returns a menu label in the session language.

    Args:
        key: label name in LABELS.

    Returns:
        The translated label, English when the language has none.
    """
    for variable in ("LC_ALL", "LC_MESSAGES", "LANG"):
        value = os.environ.get(variable, "")
        if value:
            return LABELS.get(value.split("_")[0], LABELS["en"])[key]
    return LABELS["en"][key]


def run(command):
    """Starts a program detached from Nautilus.

    Args:
        command: program and arguments.
    """
    subprocess.Popen(command, start_new_session=True)


class HyprDoraMenu(GObject.GObject, Nautilus.MenuProvider):
    """Adds the terminal item to the folder menus."""

    def get_file_items(self, files):
        """Returns items for the selected files."""
        if len(files) != 1:
            return []
        path = files[0].get_location().get_path()
        if not path:
            return []
        if files[0].is_directory():
            return [self.terminal_item(path)]
        return []

    def get_background_items(self, folder):
        """Returns items for the empty area of a folder."""
        path = folder.get_location().get_path()
        return [self.terminal_item(path)] if path else []

    def terminal_item(self, path):
        """Builds the item that opens a terminal in a folder.

        Args:
            path: folder to open.

        Returns:
            The menu item.
        """
        item = Nautilus.MenuItem(name="HyprDora::terminal", label=label("terminal"))
        item.connect("activate", lambda _item: run(["alacritty", "--working-directory", path]))
        return item
