################################################################################
#
# qt6
#
################################################################################

QT6_VERSION_MAJOR = 6.4
QT6_VERSION = $(QT6_VERSION_MAJOR).0
QT6_SOURCE_TARBALL_PREFIX = everywhere-src
QT6_SITE = https://download.qt.io/archive/qt/$(QT6_VERSION_MAJOR)/$(QT6_VERSION)/submodules

include $(sort $(wildcard package/qt6/*/*.mk))

# The file "qt.conf" can be used to override the hard-coded paths that are
# compiled into the Qt library. We need it to make "qmake" relocatable due
# to the host/target build and tweak the per-package install pathes
define QT6_INSTALL_QT_CONF
	rm -f $(HOST_DIR)/bin/qt.conf
	sed -e "s|@@HOST_DIR@@|$(HOST_DIR)|" -e "s|@@STAGING_DIR@@|$(STAGING_DIR)|" \
		$(QT6BASE_PKGDIR)/qt.conf.in > $(HOST_DIR)/bin/qt.conf
endef

# Variable for other Qt applications to use
QT6_QMAKE = $(HOST_DIR)/bin/qmake -spec devices/linux-buildroot-g++
