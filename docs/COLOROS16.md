# A52s ColorOS 16 build

Base: `update/oneui-ksunext-3.4.2`, Samsung SM7325/A52s hardware and vendor.
The port tested during preparation runs a Samsung Linux 5.4 kernel and uses
boot/vendor_boot header version 3, EROFS, ET713 and the STM touch driver.
ColorOS userspace does not turn this hardware into an Oplus device.

Run **NovaKernel ColorOS 16 A52s** from Actions on
`update/coloros16-ksunext-3.4.2`. Pushing build changes to that branch also builds
KernelSU Next v3.4.2 with its built-in hooks. Manual runs can disable KernelSU
or enable the branch's existing SUSFS integration. No Telegram upload is used.

The ZIP is an **AnyKernel3 recovery installer**, not a KernelSU module.
It repacks the phone's installed boot and vendor_boot instead of substituting
Samsung reference ramdisks. It retains the ColorOS fstab/init and boot command
line, installs the newly compiled vendor module set and STM touch firmware,
and replaces Image, vendor DTB and DTBO. Unsupported devices or header versions
are rejected before flashing. Only A52s is included; A73/M52 are not validated.

The original One UI workflow remains available. Its packaging is unchanged.
EROFS, SELinux, ET7XX, modular STM touch and WLAN are checked before compilation.
Existing fingerprint v1.0.1 and GCam hotfix modules remain separate; this kernel
does not implement their userspace fixes or bundle calibration/personal data.

Compilation success is not an on-device boot test. Until the new kernel is
booted and touch, display, Wi-Fi, camera, fingerprint and root are tested,
consider this an experimental ColorOS build. Keep recovery access and backups
of the current boot, vendor_boot and dtbo before flashing. No automatic flash
or changes to the connected phone are performed by this workflow.
