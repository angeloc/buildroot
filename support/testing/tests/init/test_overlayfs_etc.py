import os
import subprocess

import infra.basetest


class InitSystemOverlayfsEtcBase(infra.basetest.BRTest):
    # The kernel fragment disables overlayfs, to check that
    # BR2_ROOTFS_OVERLAYFS_ETC enables it.
    kern_frag = infra.filepath(
        "tests/init/test_overlayfs_etc/linux-no-overlayfs.fragment")
    config = \
        f"""
        BR2_aarch64=y
        BR2_TOOLCHAIN_EXTERNAL=y
        BR2_TARGET_GENERIC_GETTY_PORT="ttyAMA0"
        # BR2_TARGET_GENERIC_REMOUNT_ROOTFS_RW is not set
        BR2_ROOTFS_OVERLAYFS_ETC=y
        BR2_ROOTFS_OVERLAYFS_ETC_DEVICE="/dev/vdb"
        BR2_ROOTFS_OVERLAYFS_ETC_EXPOSE_LOWER=y
        BR2_LINUX_KERNEL=y
        BR2_LINUX_KERNEL_CUSTOM_VERSION=y
        BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.18.60"
        BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG=y
        BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="board/qemu/aarch64-virt/linux.config"
        BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES="{kern_frag}"
        BR2_LINUX_KERNEL_NEEDS_HOST_OPENSSL=y
        BR2_TARGET_ROOTFS_EXT2=y
        BR2_TARGET_ROOTFS_EXT2_4=y
        # BR2_TARGET_ROOTFS_TAR is not set
        """

    def create_data_disk(self):
        disk = os.path.join(self.builddir, "images", "data.ext4")
        subprocess.check_call(
            ["dd", "if=/dev/zero", f"of={disk}", "bs=1M", "count=32"],
            stdout=self.emulator.logfile, stderr=self.emulator.logfile)
        mkfs = os.path.join(self.builddir, "host", "sbin", "mkfs.ext4")
        subprocess.check_call(
            [mkfs, "-F", "-q", disk],
            stdout=self.emulator.logfile, stderr=self.emulator.logfile)
        return disk

    def boot(self, data_disk):
        rootfs = os.path.join(self.builddir, "images", "rootfs.ext2")
        kernel = os.path.join(self.builddir, "images", "Image")
        options = ["-M", "virt", "-cpu", "cortex-a57", "-m", "256M",
                   "-drive", f"file={rootfs},if=virtio,format=raw"]
        if data_disk:
            options += ["-drive", f"file={data_disk},if=virtio,format=raw"]
        self.emulator.boot(arch="aarch64",
                           kernel=kernel,
                           kernel_cmdline=["root=/dev/vda", "ro", "rootwait",
                                           "console=ttyAMA0"],
                           options=options)
        self.emulator.login()

    def check_common(self):
        # The original init runs as PID 1, after the pre-init
        self.assertRunOk("cmp /proc/1/exe /usr/libexec/overlayfs-etc/init")
        # The root filesystem stays read-only
        self.assertRunOk("grep -q '^/dev/root / ext4 ro' /proc/mounts")
        self.assertRunNotOk("touch /usr/foo")

    def check_overlay(self):
        disk = self.create_data_disk()

        self.boot(disk)
        self.check_common()

        # /etc is an overlay with its upper on the persistent device
        self.assertRunOk("grep -q '^overlay-etc /etc overlay ' /proc/mounts")
        self.assertRunOk("grep -q '^/dev/vdb /data ext4 ' /proc/mounts")

        self.assertRunOk("echo foobar >/etc/br-test")
        self.assertRunOk("test -e /data/overlay-etc/upper/br-test")

        # The original /etc is exposed read-only
        self.assertRunOk("cmp /data/overlay-etc/lower/passwd /etc/passwd")
        self.assertRunNotOk("test -e /data/overlay-etc/lower/br-test")
        self.assertRunNotOk("touch /data/overlay-etc/lower/foo")

        # The changes persist across boots
        self.assertRunOk("sync")
        self.emulator.stop()
        self.boot(disk)
        out, exit_code = self.emulator.run("cat /etc/br-test")
        self.assertEqual(exit_code, 0)
        self.assertEqual(out[0], "foobar")


class TestInitSystemOverlayfsEtcBusybox(InitSystemOverlayfsEtcBase):
    config = InitSystemOverlayfsEtcBase.config

    def test_run(self):
        self.check_overlay()


class TestInitSystemOverlayfsEtcSysv(InitSystemOverlayfsEtcBase):
    config = InitSystemOverlayfsEtcBase.config + \
        """
        BR2_INIT_SYSV=y
        """

    def test_run(self):
        self.check_overlay()


class TestInitSystemOverlayfsEtcSystemd(InitSystemOverlayfsEtcBase):
    config = InitSystemOverlayfsEtcBase.config + \
        """
        BR2_INIT_SYSTEMD=y
        """

    def test_run(self):
        self.check_overlay()


class TestInitSystemOverlayfsEtcNoDevice(InitSystemOverlayfsEtcBase):
    config = InitSystemOverlayfsEtcBase.config

    def test_run(self):
        # Without the persistent device, the system still boots, with
        # the read-only /etc
        self.boot(None)
        self.check_common()
        self.assertRunNotOk("grep -q ' /etc overlay ' /proc/mounts")
        self.assertRunNotOk("touch /etc/foo")
