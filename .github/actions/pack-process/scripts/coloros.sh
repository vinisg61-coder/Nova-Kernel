#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

[[ "$VARIANT" == a52sxq && "$OS" == ColorOS16 ]] || {
    echo "::error::ColorOS packaging is supported only for A52s"; exit 1;
}
: "${ZIP_NAME:?}"
: "${MODULES_DIR:?}"
# Pin the installer whose v3 vendor_boot repacking was inspected.
AK3_REV=9b7a4800205d0b5d74c9733baa87441de192ee56
AK3_DIR="$RUNNER_TEMP/NovaKernel-ColorOS-AnyKernel3"
rm -rf "$AK3_DIR"
git clone --quiet --depth=1 "$AK3_REPO" "$AK3_DIR"
[[ "$(git -C "$AK3_DIR" rev-parse HEAD)" == "$AK3_REV" ]] || {
    git -C "$AK3_DIR" fetch --depth=1 origin "$AK3_REV"
    git -C "$AK3_DIR" checkout --detach FETCH_HEAD
}
rm -rf "$AK3_DIR/ramdisk" "$AK3_DIR/patch" "$AK3_DIR/modules"
mkdir -p "$AK3_DIR/boot-files" "$AK3_DIR/vendor_boot-files" "$AK3_DIR/coloros-modules" "$AK3_DIR/coloros-firmware"
cp "$GITHUB_WORKSPACE/.github/installer/coloros-anykernel.sh" "$AK3_DIR/anykernel.sh"
# Recovery already owns APEX loop devices. This port only needs the static
# repack tools, so avoid reconfiguring those loops during environment setup.
python3 "$GITHUB_WORKSPACE/.github/installer/patch-coloros-updater.py" "$AK3_DIR/META-INF/com/google/android/update-binary"
cp "$OUT_DIR/arch/arm64/boot/Image" "$AK3_DIR/boot-files/Image"
cp "$OUT_DIR/arch/arm64/boot/dtbo.img" "$AK3_DIR/boot-files/dtbo.img"
cp "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/$DTB_NAME" "$AK3_DIR/vendor_boot-files/dtb"
cp "$MODULES_DIR/"* "$AK3_DIR/coloros-modules/"
cp "$GITHUB_WORKSPACE/firmware/tsp_stm/fts5cu56a_a52sxq.bin" "$AK3_DIR/coloros-firmware/"
# These modules must be replaced together with the kernel, never left at the old ABI.
for module in stm_ts.ko wlan.ko; do
    [[ -s "$AK3_DIR/coloros-modules/$module" ]] || {
        echo "::error::Missing required module: $module"; exit 1;
    }
done
cp "$GITHUB_WORKSPACE/docs/COLOROS16.md" "$AK3_DIR/README-ColorOS16.md"
ZIP_PATH="$PACKAGE_BASE/$ZIP_NAME"
(cd "$AK3_DIR"; zip -q -r -9 "$ZIP_PATH" . -x '.git' '.git/*' '*/.git/*')
printf 'PACKAGE_MODE=ColorOS-AnyKernel3\n' >> "$GITHUB_ENV"
echo "ColorOS package preserves installed boot/vendor_boot ramdisks; no Samsung reference images."
