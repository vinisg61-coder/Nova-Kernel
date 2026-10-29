#!/usr/bin/env python3
"""Add a ColorOS-only APEX opt-out to the pinned AnyKernel3 backend."""
from pathlib import Path
import sys


def patch_backend(source: bytes) -> bytes:
    original = b"    mount_apex;\n"
    replacement = (
        b'    # ColorOS uses static repack tools; preserve recovery-owned APEX loops.\n'
        b'    if [ "$(file_getprop anykernel.sh do.mountapex)" != 0 ]; then\n'
        b'      mount_apex;\n'
        b'    fi;\n'
    )
    if source.count(original) != 1:
        raise ValueError("Unexpected AnyKernel3 backend: APEX call must match exactly once")
    return source.replace(original, replacement)


if __name__ == "__main__":
    path = Path(sys.argv[1])
    path.write_bytes(patch_backend(path.read_bytes()))
