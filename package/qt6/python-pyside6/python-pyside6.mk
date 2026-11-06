################################################################################
#
# python-pyside6
#
################################################################################

# Qt for Python must have the same version as Qt6
PYTHON_PYSIDE6_VERSION = $(QT6_VERSION)
PYTHON_PYSIDE6_SITE = https://download.qt.io/official_releases/QtForPython/pyside6/PySide6-$(PYTHON_PYSIDE6_VERSION)-src
PYTHON_PYSIDE6_SOURCE = pyside-setup-everywhere-src-$(PYTHON_PYSIDE6_VERSION).tar.xz
PYTHON_PYSIDE6_DL_SUBDIR = python-shiboken6
PYTHON_PYSIDE6_SUBDIR = sources/pyside6
PYTHON_PYSIDE6_LICENSE = \
	LGPL-3.0 or GPL-2.0 or GPL-3.0 (bindings), \
	GPL-3.0 with Qt-GPL-exception-1.0 (tools), \
	BSD-3-Clause (examples, cmake)
PYTHON_PYSIDE6_LICENSE_FILES = \
	LICENSES/BSD-3-Clause.txt \
	LICENSES/GPL-2.0-only.txt \
	LICENSES/GPL-3.0-only.txt \
	LICENSES/LGPL-3.0-only.txt \
	LICENSES/Qt-GPL-exception-1.0.txt
PYTHON_PYSIDE6_CPE_ID_VENDOR = qt
PYTHON_PYSIDE6_CPE_ID_PRODUCT = pyside
PYTHON_PYSIDE6_SUPPORTS_IN_SOURCE_BUILD = NO
PYTHON_PYSIDE6_INSTALL_STAGING = YES

PYTHON_PYSIDE6_DEPENDENCIES = \
	host-python-shiboken6 \
	python-shiboken6 \
	qt6base

# The modules are built in this order, a module needing the ones before
# it: keep the order of ALL_ESSENTIAL_MODULES and ALL_OPTIONAL_MODULES in
# sources/pyside6/cmake/PySideHelpers.cmake
PYTHON_PYSIDE6_MODULES = \
	Core \
	Gui \
	Widgets \
	$(if $(BR2_PACKAGE_QT6BASE_PRINTSUPPORT),PrintSupport) \
	$(if $(BR2_PACKAGE_QT6BASE_SQL),Sql) \
	$(if $(BR2_PACKAGE_QT6BASE_NETWORK),Network) \
	$(if $(BR2_PACKAGE_QT6BASE_TEST),Test) \
	$(if $(BR2_PACKAGE_QT6BASE_CONCURRENT),Concurrent) \
	$(if $(BR2_PACKAGE_QT6BASE_DBUS),DBus) \
	$(if $(BR2_PACKAGE_QT6BASE_XML),Xml) \
	OpenGL \
	OpenGLWidgets

ifeq ($(BR2_PACKAGE_QT6DECLARATIVE),y)
PYTHON_PYSIDE6_DEPENDENCIES += qt6declarative
PYTHON_PYSIDE6_MODULES += Qml
ifeq ($(BR2_PACKAGE_QT6DECLARATIVE_QUICK),y)
PYTHON_PYSIDE6_MODULES += \
	Quick \
	QuickControls2 \
	$(if $(BR2_PACKAGE_QT6BASE_TEST),QuickTest) \
	QuickWidgets
endif
endif

ifeq ($(BR2_PACKAGE_QT6SERIALPORT),y)
PYTHON_PYSIDE6_DEPENDENCIES += qt6serialport
PYTHON_PYSIDE6_MODULES += SerialPort
ifeq ($(BR2_PACKAGE_QT6SERIALBUS),y)
PYTHON_PYSIDE6_DEPENDENCIES += qt6serialbus
PYTHON_PYSIDE6_MODULES += SerialBus
endif
endif

ifeq ($(BR2_PACKAGE_QT6SVG),y)
PYTHON_PYSIDE6_DEPENDENCIES += qt6svg
PYTHON_PYSIDE6_MODULES += Svg SvgWidgets
endif

# The Qt headers are in the sysroot, so shiboken considers them as
# system headers and doesn't process them without
# PYSIDE_TREAT_QT_INCLUDE_DIRS_AS_NON_SYSTEM.
PYTHON_PYSIDE6_CONF_OPTS = \
	-DBUILD_TESTS=OFF \
	-DMODULES="$(subst $(space),;,$(strip $(PYTHON_PYSIDE6_MODULES)))" \
	-DPYSIDE_TREAT_QT_INCLUDE_DIRS_AS_NON_SYSTEM=ON \
	-DQFP_SHIBOKEN_HOST_PATH=$(HOST_DIR) \
	-DQFP_PYTHON_HOST_PATH=$(HOST_DIR)/bin/python3

$(eval $(cmake-package))
