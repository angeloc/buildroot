################################################################################
#
# kf6-modemmanager-qt
#
################################################################################

KF6_MODEMMANAGER_QT_VERSION = $(KF6_VERSION)
KF6_MODEMMANAGER_QT_SITE = $(KF6_SITE)
KF6_MODEMMANAGER_QT_SOURCE = modemmanager-qt-$(KF6_MODEMMANAGER_QT_VERSION).tar.xz
KF6_MODEMMANAGER_QT_LICENSE = \
	LGPL-2.1 or LGPL-3.0 or LicenseRef-KDE-Accepted-LGPL (library), \
	GPL-2.0 or GPL-3.0 or LicenseRef-KDE-Accepted-GPL (autotests, examples), \
	BSD-3-Clause (cmake), \
	CC0-1.0 (metadata)
KF6_MODEMMANAGER_QT_LICENSE_FILES = \
	LICENSES/BSD-3-Clause.txt \
	LICENSES/CC0-1.0.txt \
	LICENSES/GPL-2.0-only.txt \
	LICENSES/GPL-3.0-only.txt \
	LICENSES/LGPL-2.1-only.txt \
	LICENSES/LGPL-3.0-only.txt \
	LICENSES/LicenseRef-KDE-Accepted-GPL.txt \
	LICENSES/LicenseRef-KDE-Accepted-LGPL.txt

KF6_MODEMMANAGER_QT_DEPENDENCIES = kf6-extra-cmake-modules modem-manager qt6base
KF6_MODEMMANAGER_QT_INSTALL_STAGING = YES
KF6_MODEMMANAGER_QT_CONF_OPTS = \
	-DBUILD_EXAMPLES=OFF \
	-DBUILD_TESTING=OFF

# Uses __atomic_fetch_add_4
ifeq ($(BR2_TOOLCHAIN_HAS_LIBATOMIC),y)
KF6_MODEMMANAGER_QT_CONF_OPTS += -DCMAKE_EXE_LINKER_FLAGS=-latomic
endif

$(eval $(cmake-package))
