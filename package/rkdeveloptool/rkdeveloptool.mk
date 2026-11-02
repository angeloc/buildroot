################################################################################
#
# rkdeveloptool
#
################################################################################

RKDEVELOPTOOL_VERSION = 304f073752fd25c854e1bcf05d8e7f925b1f4e14
RKDEVELOPTOOL_SITE = $(call github,rockchip-linux,rkdeveloptool,$(RKDEVELOPTOOL_VERSION))
RKDEVELOPTOOL_LICENSE = GPL-2.0+
RKDEVELOPTOOL_LICENSE_FILES = license.txt
# Sources from git, no configure script provided
RKDEVELOPTOOL_AUTORECONF = YES
HOST_RKDEVELOPTOOL_DEPENDENCIES = host-libusb host-pkgconf

$(eval $(host-autotools-package))
