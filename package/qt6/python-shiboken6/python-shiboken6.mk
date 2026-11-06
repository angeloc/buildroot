################################################################################
#
# python-shiboken6
#
################################################################################

# Qt for Python must have the same version as Qt6
PYTHON_SHIBOKEN6_VERSION = $(QT6_VERSION)
PYTHON_SHIBOKEN6_SITE = https://download.qt.io/official_releases/QtForPython/pyside6/PySide6-$(PYTHON_SHIBOKEN6_VERSION)-src
PYTHON_SHIBOKEN6_SOURCE = pyside-setup-everywhere-src-$(PYTHON_SHIBOKEN6_VERSION).tar.xz
PYTHON_SHIBOKEN6_LICENSE = \
	LGPL-3.0 or GPL-2.0 or GPL-3.0 (library, module), \
	GPL-3.0 with Qt-GPL-exception-1.0 (generator), \
	BSD-3-Clause (cmake)
PYTHON_SHIBOKEN6_LICENSE_FILES = \
	LICENSES/BSD-3-Clause.txt \
	LICENSES/GPL-2.0-only.txt \
	LICENSES/GPL-3.0-only.txt \
	LICENSES/LGPL-3.0-only.txt \
	LICENSES/Qt-GPL-exception-1.0.txt
PYTHON_SHIBOKEN6_CPE_ID_VENDOR = qt
PYTHON_SHIBOKEN6_CPE_ID_PRODUCT = shiboken
PYTHON_SHIBOKEN6_SUPPORTS_IN_SOURCE_BUILD = NO
PYTHON_SHIBOKEN6_INSTALL_STAGING = YES

# The target package builds the shiboken6 library and Python module,
# the host package builds the shiboken6 binding generator, used to
# build this module and the PySide6 bindings.
PYTHON_SHIBOKEN6_SUBDIR = sources/shiboken6
HOST_PYTHON_SHIBOKEN6_SUBDIR = sources/shiboken6_generator

PYTHON_SHIBOKEN6_DEPENDENCIES = \
	host-python-shiboken6 \
	python3 \
	qt6base

PYTHON_SHIBOKEN6_CONF_OPTS = \
	-DBUILD_TESTS=OFF \
	-DQFP_SHIBOKEN_HOST_PATH=$(HOST_DIR) \
	-DQFP_PYTHON_HOST_PATH=$(HOST_DIR)/bin/python3

HOST_PYTHON_SHIBOKEN6_DEPENDENCIES = \
	host-clang \
	host-llvm \
	host-python3 \
	host-qt6base

HOST_PYTHON_SHIBOKEN6_CONF_ENV = \
	LLVM_INSTALL_DIR=$(HOST_DIR)

# libxslt is only needed to extract the documentation
HOST_PYTHON_SHIBOKEN6_CONF_OPTS = \
	-DBUILD_TESTS=OFF \
	-DCMAKE_DISABLE_FIND_PACKAGE_LibXslt=ON

$(eval $(cmake-package))
$(eval $(host-cmake-package))
