################################################################################
#
# rtl8723ds-bt
#
################################################################################

RTL8723DS_BT_VERSION = 14cedf3a9fec1aa8c500fa52f3e3acc433cbcf08
RTL8723DS_BT_SITE = $(call github,wsyco,RTL8723DS_BT_Linux,$(RTL8723DS_BT_VERSION))
RTL8723DS_BT_LICENSE = PROPRIETARY
RTL8723DS_BT_INSTALL_STAGING = YES

define RTL8723DS_BT_LINUX_CONFIG_FIXUPS
	$(call KCONFIG_ENABLE_OPT,CONFIG_SERIAL_DEV_BUS)
	$(call KCONFIG_ENABLE_OPT,CONFIG_SERIAL_DEV_CTRL_TTYPORT)
	$(call KCONFIG_ENABLE_OPT,CONFIG_BT)
	$(call KCONFIG_ENABLE_OPT,CONFIG_BT_HCIUART)
	$(call KCONFIG_ENABLE_OPT,CONFIG_BT_HCIUART_3WIRE)
	$(call KCONFIG_ENABLE_OPT,CONFIG_BT_HCIUART_RTL)
	$(call KCONFIG_APPEND_OPT,CONFIG_EXTRA_FIRMWARE,rtl_bt/rtl8723ds_fw.bin rtl_bt/rtl8723ds_config.bin)
endef

define RTL8723DS_BT_INSTALL_STAGING_CMDS
	mkdir -p $(STAGING_DIR)/lib/firmware/rtl_bt/
	cp $(@D)/8723D/rtl8723d_fw $(STAGING_DIR)/lib/firmware/rtl_bt/rtl8723ds_fw.bin
	cp $(@D)/8723D/rtl8723d_config $(STAGING_DIR)/lib/firmware/rtl_bt/rtl8723ds_config.bin
endef

$(eval $(generic-package))
