################################################################################
#
# setools
#
################################################################################

SETOOLS_VERSION = 4.5.1
SETOOLS_SITE = $(call github,SELinuxProject,setools,$(SETOOLS_VERSION))
SETOOLS_DEPENDENCIES = libselinux libsepol python-setuptools host-bison host-flex host-python-cython host-swig
SETOOLS_INSTALL_STAGING = YES
SETOOLS_LICENSE = GPL-2.0+, LGPL-2.1+
SETOOLS_LICENSE_FILES = COPYING COPYING.GPL COPYING.LGPL
SETOOLS_CPE_ID_VENDOR = selinuxproject
SETOOLS_SETUP_TYPE = setuptools
HOST_SETOOLS_DEPENDENCIES = host-python-cython host-libselinux host-libsepol host-python-networkx

define SETOOLS_FIX_SETUP
	# By default, setup.py will look for libsepol.a in the host machines
	# /usr/lib directory. This needs to be changed to the staging directory.
	$(SED) "s@lib_dirs =.*@lib_dirs = ['$(STAGING_DIR)/usr/lib']@g" \
		$(@D)/setup.py
endef
SETOOLS_POST_PATCH_HOOKS += SETOOLS_FIX_SETUP

define HOST_SETOOLS_FIX_SETUP
	# By default, setup.py will look for libsepol.a in the host machines
	# /usr/lib directory. This needs to be changed to the host directory.
	$(SED) "s@lib_dirs =.*@lib_dirs = ['$(HOST_DIR)/lib']@g" \
		$(@D)/setup.py
endef
HOST_SETOOLS_POST_PATCH_HOOKS += HOST_SETOOLS_FIX_SETUP

# apol requires PyQt6, which is not available in Buildroot. However, the
# setools installation process installs apol anyway, so remove it.
define SETOOLS_REMOVE_QT_SCRIPTS
	$(RM) $(TARGET_DIR)/usr/bin/apol
	$(RM) -r $(TARGET_DIR)/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages/setoolsgui/
endef
SETOOLS_POST_INSTALL_TARGET_HOOKS += SETOOLS_REMOVE_QT_SCRIPTS

define HOST_SETOOLS_REMOVE_BROKEN_SCRIPTS
	$(RM) $(HOST_DIR)/bin/apol
endef
HOST_SETOOLS_POST_INSTALL_HOOKS += HOST_SETOOLS_REMOVE_BROKEN_SCRIPTS

$(eval $(python-package))
$(eval $(host-python-package))
