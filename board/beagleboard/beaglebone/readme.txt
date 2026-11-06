CircuitCo BeagleBone
Texas Instuments AM335x Evaluation Module (TMDXEVM3358)

Description
===========

This configuration will build a complete image for the beaglebone and
the TI AM335x-EVM, the board type is identified by the on-board
EEPROM. The configuration is based on the
ti-processor-sdk-06.01.00.08. Device tree blobs for beaglebone
variants and the evm-sk are built too.

For Qt6 support use the beaglebone_qt5_defconfig.

How to build it
===============

Select the default configuration for the target:
$ make beaglebone_defconfig

Optional: modify the configuration:
$ make menuconfig

Build:
$ make

Result of the build
===================
output/images/
+-- am335x-boneblack.dtb
+-- am335x-boneblack-wireless.dtb
+-- am335x-boneblue.dtb
+-- am335x-bonegreen.dtb
+-- am335x-bonegreen-eco.dtb
+-- am335x-bonegreen-wireless.dtb
+-- am335x-bone.dtb
+-- am335x-evm.dtb
+-- am335x-evmsk.dtb
+-- boot.vfat
+-- MLO
+-- rootfs.ext2
+-- rootfs.tar
+-- sdcard.img
+-- u-boot.img
+-- uEnv.txt
+-- zImage

To copy the image file to the sdcard use dd:
$ dd if=output/images/sdcard.img of=/dev/XXX


Running the Qt6 openglwindow example:
===================
# export QT_QPA_EGLFS_KMS_CONFIG=/etc/qt6/eglfs_kms_cfg.json
# export QT_QPA_PLATFORM=eglfs
# export QT_QPA_EGLFS_INTEGRATION=none
# /usr/examples/opengl/openglwindow/bin/openglwindow


Tested hardware
===============
am335x-evm (rev. 1.1A)
beagleboneblack (rev. A5A)
beaglebone (rev. A6)

2020, Adam Duskett <aduskett@gmail.com>
2016, Lothar Felten <lothar.felten@gmail.com>
