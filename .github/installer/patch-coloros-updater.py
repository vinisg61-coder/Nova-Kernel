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


def patch_core(source: bytes) -> bytes:
    # This pinned fork mixes legacy lowercase names with its uppercase API.
    replacements = {
        b'"$split_img/ramdisk.cpio.gz" -o -f "$split_img/ramdisk.cpio"':
            b'"$SPLITIMG/ramdisk.cpio.gz" -o -f "$SPLITIMG/ramdisk.cpio"',
        b'[ -d "$ramdisk" ] && repack_ramdisk;':
            b'[ -d "$RAMDISK" ] && repack_ramdisk;',
    }
    for original, replacement in replacements.items():
        if source.count(original) != 1:
            raise ValueError("Unexpected AnyKernel3 core: ramdisk API must match exactly once")
        source = source.replace(original, replacement)
    return source


if __name__ == "__main__":
    path = Path(sys.argv[1])
    path.write_bytes(patch_backend(path.read_bytes()))
    core = Path(sys.argv[2])
    core.write_bytes(patch_core(core.read_bytes()))
