#!/usr/bin/env bash
# Exercise the real packager with dummy build outputs; never flash a device.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
TEST="$(mktemp -d)"
trap 'rm -rf "$TEST"' EXIT
mkdir -p "$TEST/bin" "$TEST/template/tools" "$TEST/out/arch/arm64/boot/dts/vendor/qcom" "$TEST/mods" "$TEST/packages" "$TEST/runner"
printf 'fixture\n' > "$TEST/template/tools/ak3-core.sh"
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
PY
rm "$TEST/mods/stm_ts.ko"
if bash "$ROOT/.github/actions/pack-process/scripts/coloros.sh"; then
    echo 'Packager accepted missing touch module' >&2; exit 1
fi
export VARIANT=a73xq
if bash "$ROOT/.github/actions/pack-process/scripts/coloros.sh"; then
    echo 'Packager accepted unsupported device' >&2; exit 1
fi
echo 'ColorOS packaging positive/negative tests passed'
