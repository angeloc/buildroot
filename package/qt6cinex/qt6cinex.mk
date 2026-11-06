################################################################################
#
# qt6cinex
#
################################################################################

QT6CINEX_VERSION = 8542d3f7a3cdc937467f0f08622e3b67b1883293
QT6CINEX_SITE = $(call github,alpqr,qt5-cinematic-experience,$(QT6CINEX_VERSION))
QT6CINEX_LICENSE = CC-BY-3.0
QT6CINEX_LICENSE_FILES = README.md
QT6CINEX_DEPENDENCIES = qt6base qt6declarative qt6shadertools

# The QML files, images and shaders are built in the binary as Qt
# resources, and upstream has no install rule.
define QT6CINEX_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/qt5-cinematic-experience \
		$(TARGET_DIR)/usr/bin/CinematicExperience-demo
endef

$(eval $(cmake-package))
