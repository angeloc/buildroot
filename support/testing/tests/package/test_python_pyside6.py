import os

from tests.package.test_python import TestPythonPackageBase


# gitlab-runner: 2xlarge
class TestPythonPy3PySide6(TestPythonPackageBase):
    __test__ = True
    # We use a specific configuration for:
    # - using Aarch64, to have more than 256MB memory,
    # - to have an ext4 rootfs image exposed as a virtio storage
    #   (rather than cpio initrd). This will save some memory, as the
    #   rootfs image is big.
    config = \
        """
        BR2_aarch64=y
        BR2_TOOLCHAIN_EXTERNAL=y
        BR2_TARGET_GENERIC_GETTY_PORT="ttyAMA0"
        BR2_LINUX_KERNEL=y
        BR2_LINUX_KERNEL_CUSTOM_VERSION=y
        BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.1.81"
        BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG=y
        BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="board/qemu/aarch64-virt/linux.config"
        BR2_PACKAGE_MESA3D=y
        BR2_PACKAGE_MESA3D_GALLIUM_DRIVER_SOFTPIPE=y
        BR2_PACKAGE_MESA3D_OPENGL_EGL=y
        BR2_PACKAGE_MESA3D_OPENGL_ES=y
        BR2_PACKAGE_QT6=y
        BR2_PACKAGE_QT6BASE_GUI=y
        BR2_PACKAGE_QT6BASE_WIDGETS=y
        BR2_PACKAGE_QT6BASE_PRINTSUPPORT=y
        BR2_PACKAGE_QT6BASE_SQL=y
        BR2_PACKAGE_QT6BASE_SQLITE=y
        BR2_PACKAGE_QT6BASE_NETWORK=y
        BR2_PACKAGE_QT6BASE_TEST=y
        BR2_PACKAGE_QT6BASE_CONCURRENT=y
        BR2_PACKAGE_QT6BASE_DBUS=y
        BR2_PACKAGE_QT6BASE_XML=y
        BR2_PACKAGE_QT6BASE_OPENGL=y
        BR2_PACKAGE_QT6BASE_DEFAULT_QPA="offscreen"
        BR2_PACKAGE_QT6DECLARATIVE=y
        BR2_PACKAGE_QT6DECLARATIVE_QUICK=y
        BR2_PACKAGE_QT6SERIALPORT=y
        BR2_PACKAGE_QT6SERIALBUS=y
        BR2_PACKAGE_QT6SVG=y
        BR2_PACKAGE_PYTHON3=y
        BR2_PACKAGE_PYTHON_PYSIDE6=y
        BR2_TARGET_ROOTFS_EXT2=y
        BR2_TARGET_ROOTFS_EXT2_4=y
        BR2_TARGET_ROOTFS_EXT2_SIZE="512M"
        # BR2_TARGET_ROOTFS_TAR is not set
        """
    sample_scripts = ["tests/package/sample_python_pyside6.py"]
    timeout = 60

    def login(self):
        drive = os.path.join(self.builddir, "images", "rootfs.ext4")
        kern = os.path.join(self.builddir, "images", "Image")
        self.emulator.boot(arch="aarch64",
                           kernel=kern,
                           kernel_cmdline=["root=/dev/vda console=ttyAMA0"],
                           options=["-M", "virt", "-cpu", "cortex-a57", "-m", "512M",
                                    "-drive", f"file={drive},if=virtio,format=raw"])
        self.emulator.login()
