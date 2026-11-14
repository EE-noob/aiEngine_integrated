#!/usr/bin/env python3
"""Build the already-updated sensor_hw_v2 platform and its application."""

import os
import vitis


def main() -> None:
    workspace = "/home/etc/FPGA/BIT_PROJ_S1/Vitis"
    client = vitis.create_client()
    try:
        client.set_workspace(path=workspace)
        platform = client.get_component(name="sensor_hw_v2")
        if platform is None:
            raise RuntimeError("Vitis component sensor_hw_v2 was not found")
        platform.build()
        domain = platform.get_domain(name="standalone_microblaze_riscv_0")
        domain.regenerate()
        platform.build()
        app = client.get_component(name="sensor_sw_v2")
        if app is None:
            raise RuntimeError("Vitis component sensor_sw_v2 was not found")
        app.build()
        print("Vitis platform and sensor_sw_v2 build completed", flush=True)
    finally:
        vitis.dispose()


if __name__ == "__main__":
    main()
