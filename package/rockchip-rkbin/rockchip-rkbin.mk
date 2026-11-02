################################################################################
#
# rockchip-rkbin
#
################################################################################

ROCKCHIP_RKBIN_VERSION = f43a462e7a1429a9d407ae52b4745033034a6cf9
ROCKCHIP_RKBIN_SITE = https://github.com/rockchip-linux/rkbin.git
ROCKCHIP_RKBIN_SITE_METHOD = git
ROCKCHIP_RKBIN_LICENSE = PROPRIETARY
ROCKCHIP_RKBIN_LICENSE_FILES = LICENSE

ROCKCHIP_RKBIN_INSTALL_IMAGES = YES
ROCKCHIP_RKBIN_INSTALL_TARGET = NO

ROCKCHIP_RKBIN_BL31_FILENAME = $(call qstrip,$(BR2_PACKAGE_ROCKCHIP_RKBIN_BL31_FILENAME))
ROCKCHIP_RKBIN_TPL_FILENAME = $(call qstrip,$(BR2_PACKAGE_ROCKCHIP_RKBIN_TPL_FILENAME))
ROCKCHIP_RKBIN_TEE_FILENAME = $(call qstrip,$(BR2_PACKAGE_ROCKCHIP_RKBIN_TEE_FILENAME))
ROCKCHIP_RKBIN_USB_LOADER_INI = $(call qstrip,$(BR2_PACKAGE_ROCKCHIP_RKBIN_USB_LOADER_INI))

ifeq ($(BR2_PACKAGE_ROCKCHIP_RKBIN_USB_LOADER),y)
ifeq ($(BR_BUILDING),y)
ifeq ($(ROCKCHIP_RKBIN_USB_LOADER_INI),)
$(error No USB loader configuration file, check BR2_PACKAGE_ROCKCHIP_RKBIN_USB_LOADER_INI)
endif
endif

ROCKCHIP_RKBIN_DEPENDENCIES += host-rkdeveloptool

# rkdeveloptool reads config.ini from the current directory, with the
# paths of the binaries relative to the rkbin repository
define ROCKCHIP_RKBIN_BUILD_CMDS
	mkdir -p $(@D)/usb-loader
	ln -sf ../bin $(@D)/usb-loader/bin
	cp $(@D)/$(ROCKCHIP_RKBIN_USB_LOADER_INI) $(@D)/usb-loader/config.ini
	cd $(@D)/usb-loader && $(HOST_DIR)/bin/rkdeveloptool pack
endef

define ROCKCHIP_RKBIN_INSTALL_USB_LOADER
	$(INSTALL) -m 0644 -t $(BINARIES_DIR) $(@D)/usb-loader/*.bin
endef
endif

define ROCKCHIP_RKBIN_INSTALL_IMAGES_CMDS
	$(foreach f, \
		$(ROCKCHIP_RKBIN_BL31_FILENAME) \
		$(ROCKCHIP_RKBIN_TPL_FILENAME) \
		$(ROCKCHIP_RKBIN_TEE_FILENAME) \
		, \
		$(INSTALL) -D -m 0644 -t $(BINARIES_DIR) $(@D)/$(f)
	)
	$(ROCKCHIP_RKBIN_INSTALL_USB_LOADER)
endef

$(eval $(generic-package))
