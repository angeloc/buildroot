Luckfox Pico Mini A and B
=========================

https://wiki.luckfox.com/Luckfox-Pico-Plus-Mini/

The Luckfox Pico Mini boards are based on the Rockchip RV1103 SoC
(single Cortex-A7, 64MB in-package DDR2) and have a microSD card slot.
The Pico Mini B adds a 128MB SPI NAND flash.

Mainline support for the RV1103/RV1106 is still being upstreamed, so
these configurations use:
- Linux 7.3.1 with the RV1103 and board devicetrees, from
  https://github.com/angeloc/linux (luckfox-pico-mini branch);
- U-Boot 2026.10 with the RV1103B/RV1103/RV1106 series by Simon Glass,
  not merged yet, and the Pico Mini A and B support, from
  https://github.com/angeloc/u-boot (luckfox-pico-mini branch).

The DDR initialization blob comes from rkbin.

The BootROM loads the idbloader (DDR init and U-Boot SPL) from the SPI
NAND if it holds a valid one, else from the microSD card, else it
enters the USB download mode (maskrom).

Pico Mini A: boot from the microSD card
=======================================

Build:

  $ make luckfox_pico_mini_a_defconfig
  $ make

Files created in output/images:

├── rootfs.ext2
├── rootfs.ext4 -> rootfs.ext2
├── rv1103-luckfox-pico-mini-a.dtb
├── rv1106_ddr_924MHz_v1.15.bin
├── sdcard.img
├── u-boot-rockchip.bin
└── zImage

Write the image to a microSD card (as root):

  $ sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M conv=fsync

where /dev/sdX is the microSD card device.

The SPL loads U-Boot from the microSD card, which boots the system
from its first partition (extlinux.conf).

Pico Mini B: boot from the SPI NAND
===================================

Build:

  $ make luckfox_pico_mini_b_defconfig
  $ make

Files created in output/images:

├── boot.itb
├── idbloader.img
├── rootfs.ubi
├── rootfs.ubifs
├── rv1103-luckfox-pico-mini-b.dtb
├── rv1106_ddr_924MHz_v1.15.bin
├── rv1106_download_v1.15.108.bin
├── u-boot.img
├── u-boot-rockchip.bin
└── zImage

SPI NAND layout:

  0x000000 - 0x040000  env
  0x040000 - 0x140000  idblock (idbloader.img)
  0x140000 - 0x240000  uboot   (u-boot.img)
  0x240000 - 0xa40000  boot    (boot.itb: kernel and devicetree)
  0xa40000 - end       ubi     (rootfs.ubi: UBIFS root filesystem)

The SPL loads U-Boot from the SPI NAND, which loads the FIT image from
the "boot" partition and boots it, with the UBIFS root filesystem in
the "ubi" partition.

Flashing the SPI NAND
---------------------

The SPI NAND is written in USB download (maskrom) mode, connecting the
board USB-C port to the host, with rkdeveloptool (built as a host
package) and the USB loader packed from rkbin (rv1106_download_*.bin).

Put the board in maskrom mode (see below), then run:

  $ board/luckfox/pico-mini/b/flash-spinand.sh output

The script waits for the board (USB device 2207:110c), erases the SPI
NAND, writes the images and resets the board.

The root filesystem is created with the UBIFS free space fixup option,
as the USB loader also writes the empty pages of the image.

If the SPI NAND already held a UBI image, also erase the end of the
"ubi" partition, which the USB loader cannot access: stop the
U-Boot autoboot by pressing a key on the first boot, and run:

  => mtd erase ubi 0x74c0000 0x100000
  => reset

Otherwise, UBI fails to attach with "bad image sequence number".

Entering maskrom mode
---------------------

- From U-Boot: stop the autoboot by pressing a key, then write the
  download mode flag in the boot mode register and reset:

    => mw.l 0xff020200 0xef08a53c
    => reset

  The DDR initialization blob finds the flag at the next boot and gives
  control back to the BootROM, which enters the USB download mode.

- With the BOOT button: hold it while plugging the USB-C cable. This
  does not work on all boards when the SPI NAND holds a valid
  idbloader.

- As a last resort, if the SPI NAND holds an idbloader that does not
  start U-Boot: shorting the clock pin of the SPI NAND (pin 6) to GND
  while plugging the USB-C cable prevents the BootROM from reading it,
  so it enters the USB download mode (without microSD card).

Serial console
==============

The console is on UART2 (pins 1.B2 TX / 1.B3 RX, 3.3V), at 115200 8N1.

Login
=====

Log in as 'root', with no password.
