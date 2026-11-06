################################################################################
#
# quazip
#
################################################################################

QUAZIP_VERSION = 1.7.2
QUAZIP_SITE = $(call github,stachenov,quazip,v$(QUAZIP_VERSION))
QUAZIP_INSTALL_STAGING = YES
QUAZIP_DEPENDENCIES = qt6base qt6core5compat zlib
QUAZIP_CONF_OPTS = -DQUAZIP_QT_MAJOR_VERSION=6

ifeq ($(BR2_PACKAGE_QUAZIP_INSTALL_TESTS),y)
QUAZIP_CONF_OPTS += -DQUAZIP_ENABLE_TESTS=ON

define QUAZIP_INSTALL_TESTS
	$(INSTALL) -D -m 0755 $(@D)/qztest/qztest $(TARGET_DIR)/usr/bin/qztest
endef

QUAZIP_POST_INSTALL_TARGET_HOOKS += QUAZIP_INSTALL_TESTS
else
QUAZIP_CONF_OPTS += -DQUAZIP_ENABLE_TESTS=OFF
endif

QUAZIP_LICENSE = LGPL-2.1
QUAZIP_LICENSE_FILES = COPYING
QUAZIP_CPE_ID_VALID = YES

$(eval $(cmake-package))
