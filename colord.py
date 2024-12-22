#!/usr/bin/env python3

import json
import gi
import sys

try:
    gi.require_version("Colord", "1.0")
except ValueError:
    print("Colord bindings not available!", file=sys.stderr)
    print("Please install it using your package manager.", file=sys.stderr)
    exit(1)

from gi.repository import Colord

cd = Colord.Client()
cd.connect_sync()


def get_display_list():
    all_devices = cd.get_devices_sync()

    display_devices = []

    # we can't retrieve the kind without connecting first
    for device in all_devices:
        device.connect_sync()
        if device.get_kind() == Colord.DeviceKind.DISPLAY:
            display_devices.append(device)

    return display_devices


def get_display_info(device, index):
    info = {}
    device.connect_sync()

    info["index"] = index
    info["name"] = device.get_metadata()["XRANDR_name"]
    info["priority"] = device.get_metadata()["OutputPriority"]

    return info


def main():
    display_devices = get_display_list()
    display_infos = []

    for i, device in enumerate(display_devices):
        display_infos.append(get_display_info(device, i))

    print(json.dumps(display_infos))

if __name__ == "__main__":
    main()
