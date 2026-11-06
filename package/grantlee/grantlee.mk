################################################################################
#
# grantlee
#
################################################################################

GRANTLEE_VERSION = 5.3.1
GRANTLEE_SITE = $(call github,steveire,grantlee,v$(GRANTLEE_VERSION))
GRANTLEE_INSTALL_STAGING = YES
GRANTLEE_LICENSE = LGPL-2.1+
GRANTLEE_LICENSE_FILES = COPYING.LIB

GRANTLEE_DEPENDENCIES = qt6base qt6declarative
GRANTLEE_CONF_OPTS = -DGRANTLEE_BUILD_WITH_QT6=ON

$(eval $(cmake-package))
