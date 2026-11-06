################################################################################
#
# kf6-kcoreaddons
#
################################################################################

KF6_KCOREADDONS_VERSION = $(KF6_VERSION)
KF6_KCOREADDONS_SITE = $(KF6_SITE)
KF6_KCOREADDONS_SOURCE = kcoreaddons-$(KF6_KCOREADDONS_VERSION).tar.xz
KF6_KCOREADDONS_LICENSE = \
	LGPL-2.0+, LGPL-2.0, LGPL-2.1+, LGPL-2.1 or LGPL-3.0 or LicenseRef-KDE-Accepted-LGPL (library), \
	MPL-1.1 or GPL-2.0+ or LGPL-2.1+ (posix_fallocate_mac.h), \
	LGPL-2.1 with Qt-LGPL-exception-1.1 or LicenseRef-Qt-Commercial (kprocesslist), \
	BSD-2-Clause (cmake), \
	CC0-1.0 (metadata)
KF6_KCOREADDONS_LICENSE_FILES = \
	LICENSES/BSD-2-Clause.txt \
	LICENSES/CC0-1.0.txt \
	LICENSES/GPL-2.0-or-later.txt \
	LICENSES/LGPL-2.0-only.txt \
	LICENSES/LGPL-2.0-or-later.txt \
	LICENSES/LGPL-2.1-only.txt \
	LICENSES/LGPL-2.1-or-later.txt \
	LICENSES/LGPL-3.0-only.txt \
	LICENSES/LicenseRef-KDE-Accepted-LGPL.txt \
	LICENSES/LicenseRef-Qt-Commercial.txt \
	LICENSES/MPL-1.1.txt \
	LICENSES/Qt-LGPL-exception-1.1.txt

KF6_KCOREADDONS_DEPENDENCIES = \
	host-qt6tools \
	kf6-extra-cmake-modules \
	qt6base \
	util-linux
KF6_KCOREADDONS_INSTALL_STAGING = YES

# Install the QML modules and Qt plugins where Qt6 looks for them
KF6_KCOREADDONS_CONF_OPTS = \
	-DKDE_INSTALL_QMLDIR=lib/qt6/qml \
	-DKDE_INSTALL_QTPLUGINDIR=lib/qt6/plugins \
	-DBUILD_PYTHON_BINDINGS=OFF \
	-DBUILD_TESTING=OFF \
	-DENABLE_PCH=OFF

ifeq ($(BR2_TOOLCHAIN_HAS_LIBATOMIC),y)
KF6_KCOREADDONS_CONF_OPTS += -DCMAKE_SHARED_LINKER_FLAGS=-latomic
endif

ifeq ($(BR2_PACKAGE_QT6BASE_DBUS),y)
KF6_KCOREADDONS_CONF_OPTS += -DUSE_DBUS=ON
else
KF6_KCOREADDONS_CONF_OPTS += -DUSE_DBUS=OFF
endif

ifeq ($(BR2_PACKAGE_QT6BASE_NETWORK)$(BR2_PACKAGE_QT6DECLARATIVE),yy)
KF6_KCOREADDONS_CONF_OPTS += -DKCOREADDONS_USE_QML=ON
KF6_KCOREADDONS_DEPENDENCIES += qt6declarative
else
KF6_KCOREADDONS_CONF_OPTS += -DKCOREADDONS_USE_QML=OFF
endif

ifeq ($(BR2_PACKAGE_HAS_UDEV),y)
KF6_KCOREADDONS_DEPENDENCIES += udev
else
KF6_KCOREADDONS_CONF_OPTS += -DCMAKE_DISABLE_FIND_PACKAGE_UDev=ON
endif

$(eval $(cmake-package))
