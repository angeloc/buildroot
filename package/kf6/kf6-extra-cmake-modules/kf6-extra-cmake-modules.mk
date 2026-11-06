################################################################################
#
# kf6-extra-cmake-modules
#
################################################################################

KF6_EXTRA_CMAKE_MODULES_VERSION = $(KF6_VERSION)
KF6_EXTRA_CMAKE_MODULES_SITE = $(KF6_SITE)
KF6_EXTRA_CMAKE_MODULES_SOURCE = extra-cmake-modules-$(KF6_EXTRA_CMAKE_MODULES_VERSION).tar.xz
KF6_EXTRA_CMAKE_MODULES_LICENSE = BSD-3-Clause, BSD-2-Clause, MIT, CC0-1.0
KF6_EXTRA_CMAKE_MODULES_LICENSE_FILES = \
	LICENSES/BSD-2-Clause.txt \
	LICENSES/BSD-3-Clause.txt \
	LICENSES/CC0-1.0.txt \
	LICENSES/MIT.txt

KF6_EXTRA_CMAKE_MODULES_DEPENDENCIES = host-pkgconf
KF6_EXTRA_CMAKE_MODULES_INSTALL_STAGING = YES
KF6_EXTRA_CMAKE_MODULES_INSTALL_TARGET = NO

KF6_EXTRA_CMAKE_MODULES_CONF_OPTS = \
	-DBUILD_DOC=OFF \
	-DBUILD_TESTING=OFF

$(eval $(cmake-package))
