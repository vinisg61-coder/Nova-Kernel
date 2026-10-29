#!/usr/bin/env bash
# Exercise the real packager with dummy build outputs; never flash a device.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
TEST="$(mktemp -d)"
trap 'rm -rf "$TEST"' EXIT
mkdir -p "$TEST/bin" "$TEST/template/tools" "$TEST/out/arch/arm64/boot/dts/vendor/qcom" "$TEST/mods" "$TEST/packages" "$TEST/runner"
cat > "$TEST/template/tools/ak3-core.sh" <<'CORE'
dump_boot() {
  [ -f "$split_img/ramdisk.cpio.gz" -o -f "$split_img/ramdisk.cpio" ] && unpack_ramdisk;
}
write_boot() {
  [ -d "$ramdisk" ] && repack_ramdisk;
}
CORE
mkdir -p "$TEST/template/META-INF/com/google/android"
cat > "$TEST/template/META-INF/com/google/android/update-binary" <<'UPDATER'
#!/usr/bin/env bash
file_getprop() { grep "^$2=" "$1" | cut -d= -f2-; }
mount_apex() { echo APEX_MOUNT; }
mount_all() {
    mount_apex;
}
mount_all
UPDATER
cat > "$TEST/bin/git" <<'GIT'
#!/usr/bin/env bash
if [[ "$1" == clone ]]; then
    cp -a "$TEMPLATE" "${@: -1}"
else
    echo 9b7a4800205d0b5d74c9733baa87441de192ee56
fi
GIT
chmod +x "$TEST/bin/git"
for item in Image dtbo.img; do printf 'fixture\n' > "$TEST/out/arch/arm64/boot/$item"; done
printf 'fixture\n' > "$TEST/out/arch/arm64/boot/dts/vendor/qcom/yupik.dtb"
for item in stm_ts.ko wlan.ko modules.dep modules.load; do printf 'fixture\n' > "$TEST/mods/$item"; done
export GITHUB_WORKSPACE="$ROOT" RUNNER_TEMP="$TEST/runner" GITHUB_ENV="$TEST/env"
export TEMPLATE="$TEST/template" PATH="$TEST/bin:$PATH"
export VARIANT=a52sxq OS=ColorOS16 AK3_REPO=fixture DTB_NAME=yupik.dtb
export OUT_DIR="$TEST/out" MODULES_DIR="$TEST/mods" PACKAGE_BASE="$TEST/packages" ZIP_NAME=test.zip
bash "$ROOT/.github/actions/pack-process/scripts/coloros.sh"
python3 - "$PACKAGE_BASE/$ZIP_NAME" <<'PY'
import sys,zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    assert z.testzip() is None
    files=set(z.namelist())
    for name in ['boot-files/Image','boot-files/dtbo.img','vendor_boot-files/dtb','coloros-modules/stm_ts.ko','coloros-modules/wlan.ko','anykernel.sh']:
        assert name in files, name
    assert not any(n.endswith(('boot.img','vendor_boot.img','fstab.qcom')) for n in files)
    assert not any(n.startswith('.git/') for n in files)
    assert 'do.mountapex=0' in z.read('anykernel.sh').decode()
    backend=z.read('META-INF/com/google/android/update-binary').decode()
    assert 'file_getprop anykernel.sh do.mountapex' in backend
    core=z.read('tools/ak3-core.sh').decode()
    assert '"$SPLITIMG/ramdisk.cpio"' in core
    assert '[ -d "$RAMDISK" ] && repack_ramdisk;' in core
PY
# Exercise the patched recovery guard, without mount/flash commands.
mkdir -p "$TEST/guard"
unzip -p "$PACKAGE_BASE/$ZIP_NAME" META-INF/com/google/android/update-binary > "$TEST/guard/updater"
printf 'do.mountapex=0\n' > "$TEST/guard/anykernel.sh"
[[ -z "$(cd "$TEST/guard"; bash updater)" ]]
printf 'do.mountapex=1\n' > "$TEST/guard/anykernel.sh"
[[ "$(cd "$TEST/guard"; bash updater)" == APEX_MOUNT ]]
cp "$TEST/template/tools/ak3-core.sh" "$TEST/core-good"
printf 'unexpected core\n' > "$TEST/template/tools/ak3-core.sh"
if bash "$ROOT/.github/actions/pack-process/scripts/coloros.sh"; then
    echo 'Packager accepted incompatible AnyKernel core' >&2; exit 1
fi
cp "$TEST/core-good" "$TEST/template/tools/ak3-core.sh"
# Refuse drift in the pinned backend instead of shipping an unpatched ZIP.
printf 'unexpected backend\n' > "$TEST/template/META-INF/com/google/android/update-binary"
if bash "$ROOT/.github/actions/pack-process/scripts/coloros.sh"; then
    echo 'Packager accepted incompatible AnyKernel backend' >&2; exit 1
fi
printf '    mount_apex;\n' > "$TEST/template/META-INF/com/google/android/update-binary"
rm "$TEST/mods/stm_ts.ko"
if bash "$ROOT/.github/actions/pack-process/scripts/coloros.sh"; then
    echo 'Packager accepted missing touch module' >&2; exit 1
fi
export VARIANT=a73xq
if bash "$ROOT/.github/actions/pack-process/scripts/coloros.sh"; then
    echo 'Packager accepted unsupported device' >&2; exit 1
fi
echo 'ColorOS packaging positive/negative tests passed'
