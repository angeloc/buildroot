################################################################################
#
# overlayfs
#
################################################################################

OVERLAYFS_LICENSE = Public domain

define OVERLAYFS_LINUX_CONFIG_FIXUPS
	$(call KCONFIG_ENABLE_OPT,CONFIG_OVERLAY_FS)
endef

define OVERLAYFS_INSTALL_TARGET_CMDS
	$(INSTALL) -m 0755 -d $(TARGET_DIR)/data
	$(INSTALL) -m 0755 -D package/overlayfs/overlayfs-helper.sh \
		$(TARGET_DIR)/usr/bin
endef

define OVERLAYFS_INSTALL_INIT_SYSV
	$(INSTALL) -m 0755 -D package/overlayfs/S000overlayfs \
		$(TARGET_DIR)/etc/init.d/S000overlayfs
endef

define OVERLAYFS_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 package/overlayfs/overlayfs.service \
		$(TARGET_DIR)/usr/lib/systemd/system/overlayfs.service
endef

$(eval $(generic-package))
