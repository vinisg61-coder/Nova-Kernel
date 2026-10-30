# A52s One UI / KernelSU Next 3.4.2: experimental CPU OC

Base: `update/oneui-ksunext-3.4.2` at
`aeeef647c2a6fe185bec3e03c34f49bb1504334d`.
The build pins official KernelSU Next v3.4.2 to
`4c706b5938665866ebe16944a481a7b91e3396af` and uses the base branch's
Linux 5.4 compatibility patches and A52s defconfig.

## Scope and status

This is an **unverified hardware experiment**, not a proven working CPU OC.
The stock driver reads EPSS firmware frequency/voltage LUTs and requests a
row index. Editing only Linux's reported frequencies would not overclock
the CPU. This branch instead attempts to update the last prime-domain
hardware frequency row and its duplicate terminator, and checks readback
before constructing Linux's frequency table.

The experiment is compiled in but **off by default**. With no boot parameter,
the OC code performs no register writes. It only accepts the Yupik EPSS
layout, single-core CPU7 domain, 19.2 MHz reference clock, and an expected
2.4 GHz duplicate terminal row. Other configurations retain stock behavior.

An explicitly supplied kernel boot parameter enables a test:

```
qcom_cpufreq_hw.nova_oc_steps=1
```

One step requests 2,419,200 kHz; five steps request 2,496,000 kHz.
Values above five are rejected. Start with one step if on-device testing is
later authorized. This build does not add the parameter to the boot image.
It does not modify voltage rows, disable thermal management, write firmware
partitions, or automatically select an OC governor/frequency.

Protected hardware may ignore writes. The driver restores the original two
frequency words on a readback mismatch, reports `firmware-rejected`, and
retains stock tables. A rollback mismatch stops CPUFreq resource setup.
Even when readback succeeds, the status is
`lut-updated-clock-unverified`: hardware readback does **not** establish
that the actual CPU clock increased. A protected MMIO access may itself
fault; readback checks do not make this experiment hardware-safe.

## Build and validation

`Build_CPU_OC.yml` builds A52s One UI with the exact official KSU release.
Artifacts contain the raw kernel, device trees, modules, final configuration,
build log and checksums. They are not a ROM-matched flashable boot image.
No device partitions are written by the workflow.

After a separately authorized installation/test, inspect
`/sys/devices/system/cpu/cpufreq/policy7/nova_oc_status`, CPUFreq tables,
kernel logs and independent CPU-cycle/time measurements under load. Validate
stock operation first, then compare actual cycles and stability with one OC
step. Do not treat `scaling_cur_freq` or the LUT status alone as proof of OC.
Boot/stability/temperature and ROM compatibility have not been validated by
compilation. Keep the original boot image and a tested recovery route.
