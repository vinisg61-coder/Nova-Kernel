# KernelSU Next v3.4.2 on Nova One UI (Linux 5.4)

The build starts from the official `v3.4.2` tag, commit
`4c706b5938665866ebe16944a481a7b91e3396af`:
https://github.com/KernelSU-Next/KernelSU-Next/tree/v3.4.2

It does not use the `legacy` driver or override its reported version.
All release driver components remain in Kbuild, including module blacklist,
forced feature values, ADB-only shell root, policy profiles and SELinux hide.
Features conditional on platform/build mode retain upstream conditions.

## Compatibility patches

* `path-mount-linux54.patch`: split `do_mount` into a resolved-path mount API
  and the user-path wrapper. The kernel now provides `path_mount`, including
  its original security checks, mount flag handling and propagation behavior.
  The caller retains ownership of the resolved path reference.

* `ksu-v3.4.2-linux54.patch`: include/header compatibility, the 5.4 boolean
  task-work notification API, an fsnotify callback adapter, and selection of
  the backported SELinux hash-table interfaces. The arm64 page-table walker
  recognizes Linux 5.4 PMD/PUD block mappings; the dispatcher is published only
  after its syscall-table slot is verified. No feature is disabled.
* `selinux-510-policy.patch`: the Linux 5.10 SELinux policy engine, RCU policy
  lifecycle, policyfs/status interfaces and dependent private policy data
  structures. Sources are from `gregkh/linux` revision
  `aca95a35f1bcc0626c4fa4d1252bf2d4c990a1a2` (linux-5.10.y).
  Original Nova hook registration and object security layout are retained;
  state initialization, the audit callback ABI and Android netlink policy
  extensions are adapted to Nova 5.4. The SID-to-string cache Kconfig setting
  and context hashing object are included with the policy engine.

These patches are applied with `git apply`, and the build verifies the release
SHA before patching. Their SHA-256 values and the upstream revision are logged
in Actions. Review these patches as a kernel port, not as a version string change.

## Actions settings

Use `a52sxq`, enable KernelSU, select the official repository, `v3.4.2` and
`builtin`. Leave the custom branch empty. Old hook patches are skipped because
this release provides its own syscall/tracepoint hooks.

The workflow checks the resolved Kconfig dependencies before compiling.
Compilation does not validate boot, Samsung vendor modules, root grants or
SELinux policy behavior on the phone; those require device testing.

## Compilation evidence

The complete SELinux engine and all KernelSU driver objects compiled successfully
on the A52s One UI defconfig, with Clang 18, LTO and CFI enabled:
https://github.com/vinisg61-coder/Nova-Kernel/actions/runs/39163147063

The build reported `KernelSU-Next tag: v3.4.2` and
`KernelSU-Next version: 33355`. Full kernel linking/packaging and hardware
validation are separate checks.

## First device boot failure and correction

The build at `8d2deec32` panicked on A52s at 1.779 seconds. Its pstore logs
showed `failed to find phy addr for patch dst addr`, followed by a misleading
`dispatcher installed at slot 42`. The slot still pointed to ni_syscall, but
sys_enter redirected stat/execve calls to it. Init received ENOSYS and exited:
`Kernel panic - not syncing: Attempted to kill init! exitcode=0x00007f00`.

Nova 5.4 arm64 exposes `pmd_sect`/`pud_sect`, not the newer `*_leaf` macros.
The release walker skipped block mappings and rejected them as bad tables.
The compatibility patch now recognizes these blocks, tests a PUD block before
pud_bad, and enables dispatcher redirection only after verifying installation.
The earlier successful compile was not evidence of a successful device boot.
The corrected build still requires testing on the phone.

## Optional built-in SUSFS 2.3.0

Select `v3.4.2-susfs` in Actions to build the same official v3.4.2 source
with SUSFS integrated. `v3.4.2` retains the device-tested configuration.
The Linux 5.4 filesystem port derives from
https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/blob/dcd789634247c77d8549a42aef232c680a905585/Patches/Patch/susfs_patch_to_5.4.patch
with Nova-specific context, Samsung uname preservation and the 5.4 fsnotify qstr fix.
SUSFS Kconfig/command ABI derives from simonpunk/susfs4ksu's
`gki-android12-5.10` integration patch, adapted to retain v3.4.2's working hooks.
Commands use the upstream root-only reboot ABI in sleepable syscall context.
Root-granted processes clear visibility flags; zygote children marked for
unmount receive them. All ten SUSFS Kconfig options are verified after olddefconfig.
This changes filesystem behavior and needs device testing separately from the
previous successful boot without SUSFS.
