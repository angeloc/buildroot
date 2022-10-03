Lichee RV
===============

Lichee RV - Nezha CM is a compute module with modular design, equipped
with Allwinner D1 chip (based on T-Head XuanTie C906 core), 512MB DDR3 RAM.
It can boot from TF card or SD-NAND, uses two sets of M.2 b key 67 pin
connectors to route all IO, making it convient for wide use and easy to replace.

How to build
============

$ make lichee_rv_defconfig
$ make

Lichee RV dock
===============

Lichee RV Dock is a RISC-V Linux development kits with high integration, small
size and affordable price designed for opensource developer. It's equipped with
HDMI interface and it supports many screen by its screen convert board. It's
also equipped with many peripherals, including a UAB-A port, 2.4G Wifi-BT module,
an analog microphone and a speaker jack interface.

How to build
============

$ make lichee_rv_dock_defconfig
$ make

Wifi
==========

Edit board/lichee_rv/overlay_dock/etc/wpa_supplicant.conf

* Replace YOURSSID with your AP ssid
* Replace YOURPASSWD with your AP password

How to write the SD card
========================

Once the build process is finished you will have an image called "sdcard.img"
in the output/images/ directory.

Copy the bootable "sdcard.img" onto an SD card with "dd":

  $ sudo dd if=output/images/sdcard.img of=/dev/sdX

Connect a TTL UART to the debug connector, insert the microSD card and
plug in a USB-C cable to the PWR connector to boot the system.
