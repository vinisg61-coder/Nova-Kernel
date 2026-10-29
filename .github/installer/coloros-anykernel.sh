#!/sbin/sh
# Samsung A52s ColorOS 16 port, boot/vendor_boot header v3.
properties() { '
kernel.string=NovaKernel ColorOS 16 A52s
kernel.revision=5.4
do.devicecheck=1
do.modules=0
do.mountapex=0
do.cleanup=1
device.name1=a52sxq
supported.versions=16
supported.patchlevels=
supported.vendorpatchlevels=
'; }

BLOCK=vendor_boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;
. tools/ak3-core.sh;

# Fail before any write on an unexpected image layout.
for partition in boot vendor_boot; do
    part=/dev/block/bootdevice/by-name/$partition;
    [ -b "$part" ] || abort "Missing $partition partition";
    offset=40;
    [ "$partition" = vendor_boot ] && offset=8;
    version=$(dd if="$part" bs=1 skip="$offset" count=4 2>/dev/null | od -An -tu4 | tr -d '[:space:]');
    [ "$version" = 3 ] || abort "Unsupported $partition header: $version (expected 3)";
done;

# Preserve the port's fstab, init, SELinux files and firmware. Only replace
# the complete module set with modules built against this kernel.
dump_boot;
[ -s "$RAMDISK/first_stage_ramdisk/fstab.qcom" ] || abort "Port fstab.qcom is missing";
[ -s "$AKHOME/coloros-modules/stm_ts.ko" ] || abort "Touch module missing";
[ -s "$AKHOME/coloros-modules/wlan.ko" ] || abort "Wi-Fi module missing";
rm -rf "$RAMDISK/lib/modules";
mkdir -p "$RAMDISK/lib/modules" "$RAMDISK/lib/firmware/tsp_stm" || abort "Cannot prepare vendor ramdisk";
cp -f "$AKHOME/coloros-modules/"* "$RAMDISK/lib/modules/" || abort "Cannot copy modules";
cp -f "$AKHOME/coloros-firmware/fts5cu56a_a52sxq.bin" "$RAMDISK/lib/firmware/tsp_stm/" || abort "Cannot copy touch firmware";
chmod 644 "$RAMDISK/lib/modules/"* "$RAMDISK/lib/firmware/tsp_stm/fts5cu56a_a52sxq.bin";
write_boot;

# Retain the installed port boot ramdisk and command line; AK3 swaps Image.
BLOCK=boot;
reset_ak;
split_boot;
flash_boot;
flash_generic dtbo;
ui_print "NovaKernel ColorOS 16 installed. Existing fingerprint/camera hotfix modules are still required.";
