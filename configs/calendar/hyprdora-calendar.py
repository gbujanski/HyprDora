#!/usr/bin/python3
"""HyprDora's calendar helper: Nextcloud calendars and the offline one.

The code is in the hyprdora_calendar package next to this file; its cli module describes the usage.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))

from hyprdora_calendar.cli import main

sys.exit(main())
