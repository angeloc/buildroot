################################################################################
#
# kf6
#
################################################################################

KF6_VERSION_MAJOR = 6.31
KF6_VERSION = $(KF6_VERSION_MAJOR).0
KF6_SITE = https://download.kde.org/stable/frameworks/$(KF6_VERSION_MAJOR)

include $(sort $(wildcard package/kf6/*/*.mk))
