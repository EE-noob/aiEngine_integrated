#!/usr/bin/env python3
"""Update the staged sensor_hw_v2 Vitis component from a fresh Vivado XSA."""
import os
import sys

import vitis


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: update_vitis_sensor_platform.py <workspace> <xsa>")
    workspace = os.path.abspath(sys.argv[1])
    xsa = os.path.abspath(sys.argv[2])
    if not os.path.isfile(xsa):
        raise FileNotFoundError(xsa)

    client = vitis.create_client()
    try:
        client.set_workspace(path=workspace)
        platform = client.get_component(name="sensor_hw_v2")
        if platform is None:
            raise RuntimeError("Vitis component sensor_hw_v2 was not found")
        print("Updating sensor_hw_v2 from", xsa, flush=True)
        platform.update_hw(hw_design=xsa)
        platform.build()
        domain = platform.get_domain(name="standalone_microblaze_riscv_0")
        domain.regenerate()
        platform.build()
        app = client.get_component(name="sensor_sw_v2")
        if app is None:
            raise RuntimeError("Vitis component sensor_sw_v2 was not found")
        print("Building sensor_sw_v2 against the updated platform", flush=True)
        app.build()
        print("Vitis platform update/build and application build completed", flush=True)
    finally:
        vitis.dispose()


if __name__ == "__main__":
    main()
