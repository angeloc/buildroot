################################################################################
#
# pulseview
#
################################################################################

PULSEVIEW_VERSION = af02198741b4e57c9f9b796bd5e6c0f2ae9f2f2b
PULSEVIEW_SITE = $(call github,sigrokproject,pulseview,$(PULSEVIEW_VERSION))
PULSEVIEW_LICENSE = GPL-3.0+
PULSEVIEW_LICENSE_FILES = COPYING
PULSEVIEW_DEPENDENCIES = boost host-qt6tools libsigrok qt6base qt6svg
# pulseview looks for Qt5 first, make sure Qt6 is used
PULSEVIEW_CONF_OPTS = \
	-DCMAKE_DISABLE_FIND_PACKAGE_Qt5=TRUE \
	-DDISABLE_WERROR=TRUE

ifeq ($(BR2_PACKAGE_BOOST_TEST),y)
PULSEVIEW_CONF_OPTS += -DENABLE_TESTS=TRUE
else
PULSEVIEW_CONF_OPTS += -DENABLE_TESTS=FALSE
endif

ifeq ($(BR2_PACKAGE_LIBSIGROKDECODE),y)
PULSEVIEW_CONF_OPTS += -DENABLE_DECODE=TRUE
PULSEVIEW_DEPENDENCIES += libsigrokdecode
else
PULSEVIEW_CONF_OPTS += -DENABLE_DECODE=FALSE
endif

$(eval $(cmake-package))
