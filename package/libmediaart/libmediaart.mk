################################################################################
#
# libmediaart
#
################################################################################

LIBMEDIAART_VERSION_MAJOR = 1.9
LIBMEDIAART_VERSION = $(LIBMEDIAART_VERSION_MAJOR).7
LIBMEDIAART_SOURCE = libmediaart-$(LIBMEDIAART_VERSION).tar.xz
LIBMEDIAART_SITE = \
	https://download.gnome.org/sources/libmediaart/$(LIBMEDIAART_VERSION_MAJOR)
LIBMEDIAART_LICENSE = LGPL-2.1+
LIBMEDIAART_LICENSE_FILES = COPYING.LESSER
LIBMEDIAART_INSTALL_STAGING = YES
LIBMEDIAART_DEPENDENCIES = gdk-pixbuf libglib2 $(TARGET_NLS_DEPENDENCIES)
LIBMEDIAART_CONF_OPTS = -Dimage_library=gdk-pixbuf -Dtests=false
LIBMEDIAART_LDFLAGS = $(TARGET_NLS_LIBS)

ifeq ($(BR2_PACKAGE_GOBJECT_INTROSPECTION),y)
LIBMEDIAART_CONF_OPTS += -Dintrospection=true
LIBMEDIAART_DEPENDENCIES += host-vala gobject-introspection
else
LIBMEDIAART_CONF_OPTS += -Dintrospection=false
endif

$(eval $(meson-package))
