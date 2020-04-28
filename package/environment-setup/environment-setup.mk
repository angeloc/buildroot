################################################################################
#
# environment-setup
#
################################################################################

ENVIRONMENT_SETUP_FILE = $(HOST_DIR)/environment-setup
ENVIRONMENT_SETUP_HOST_DIR_SED_EXP = 's+$(HOST_DIR)+\$$SDK_PATH+g'
ENVIRONMENT_SETUP_HOST_BIN_DIR_SED_EXP = 's+$(HOST_DIR)/bin/++g'

define HOST_ENVIRONMENT_SETUP_INSTALL_CMDS
	cp package/environment-setup/environment-setup $(ENVIRONMENT_SETUP_FILE)
	for var in $(TARGET_CONFIGURE_OPTS); do \
		printf "export \"$$var\"\n" >> $(ENVIRONMENT_SETUP_FILE); \
	done
	printf "export \"CROSS_COMPILE=$(TARGET_CROSS)\"\n" >> $(ENVIRONMENT_SETUP_FILE)
	printf "export \"CONFIGURE_FLAGS=--target=$(GNU_TARGET_NAME) \
		--host=$(GNU_TARGET_NAME) \
		--build=$(GNU_HOST_NAME) \
		--prefix=/usr \
		--exec-prefix=/usr \
		--sysconfdir=/etc \
		--localstatedir=/var \
		--program-prefix=\"\n" >> $(ENVIRONMENT_SETUP_FILE)
	$(SED) $(ENVIRONMENT_SETUP_HOST_BIN_DIR_SED_EXP) \
		-e $(ENVIRONMENT_SETUP_HOST_DIR_SED_EXP) \
		-e '/^export "PATH=/c\' \
		$(ENVIRONMENT_SETUP_FILE)
	printf "export \"PATH=\$$SDK_PATH/bin:\$$SDK_PATH/sbin:\$$PATH\"\n" \
		>> $(ENVIRONMENT_SETUP_FILE)

endef

$(eval $(host-generic-package))
