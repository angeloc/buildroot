################################################################################
#
# kf6-networkmanager-qt
#
################################################################################

KF6_NETWORKMANAGER_QT_VERSION = $(KF6_VERSION)
KF6_NETWORKMANAGER_QT_SITE = $(KF6_SITE)
KF6_NETWORKMANAGER_QT_SOURCE = networkmanager-qt-$(KF6_NETWORKMANAGER_QT_VERSION).tar.xz
KF6_NETWORKMANAGER_QT_LICENSE = \
	LGPL-2.1 or LGPL-3.0 or LicenseRef-KDE-Accepted-LGPL (library), \
	GPL-2.0 or GPL-3.0 or LicenseRef-KDE-Accepted-GPL (autotests, examples), \
	CC0-1.0 (metadata)
KF6_NETWORKMANAGER_QT_LICENSE_FILES = \
	LICENSES/CC0-1.0.txt \
	LICENSES/GPL-2.0-only.txt \
	LICENSES/GPL-3.0-only.txt \
	LICENSES/LGPL-2.1-only.txt \
	LICENSES/LGPL-3.0-only.txt \
	LICENSES/LicenseRef-KDE-Accepted-GPL.txt \
	LICENSES/LicenseRef-KDE-Accepted-LGPL.txt

KF6_NETWORKMANAGER_QT_DEPENDENCIES = kf6-extra-cmake-modules host-pkgconf network-manager qt6base qt6declarative
KF6_NETWORKMANAGER_QT_INSTALL_STAGING = YES
# Install the QML modules and Qt plugins where Qt6 looks for them
KF6_NETWORKMANAGER_QT_CONF_OPTS = \
	-DKDE_INSTALL_QMLDIR=lib/qt6/qml \
	-DKDE_INSTALL_QTPLUGINDIR=lib/qt6/plugins \
	-DBUILD_EXAMPLES=OFF \
	-DBUILD_TESTING=OFF

$(eval $(cmake-package))
