#!/bin/sh
# BR2_ROOTFS_OVERLAYFS_ETC pre-init
#
# Mount an overlayfs on /etc, with its upper layer on a persistent
# device, before starting the init system, which already needs /etc.
#
# Adapted from overlayfs-etc-preinit.sh.in from openembedded-core.

PATH=/sbin:/bin:/usr/sbin:/usr/bin

MOUNT_POINT="@MOUNT_POINT@"
OVERLAY_DIR="${MOUNT_POINT}/overlay-etc"

echo "overlayfs-etc: mounting @DEVICE@ on ${MOUNT_POINT}"

mount -t proc proc /proc
mount -t sysfs sysfs /sys

if mount -n -t "@FSTYPE@" -o "@MOUNT_OPTIONS@" "@DEVICE@" "${MOUNT_POINT}"; then
	mkdir -p "${OVERLAY_DIR}/upper" "${OVERLAY_DIR}/work"

	if @EXPOSE_LOWER@; then
		# Read-only access to the original /etc content
		mkdir -p "${OVERLAY_DIR}/lower"
		mount -n -o bind,ro /etc "${OVERLAY_DIR}/lower"
	fi

	mount -n -t overlay \
		-o "lowerdir=/etc,upperdir=${OVERLAY_DIR}/upper,workdir=${OVERLAY_DIR}/work,index=off,xino=off,redirect_dir=off,metacopy=off" \
		overlay-etc /etc ||
		echo "overlayfs-etc: mounting the /etc overlay failed"
else
	echo "overlayfs-etc: mounting @DEVICE@ failed, /etc is not writable"
fi

umount /sys
umount /proc

exec @INIT@ "$@"
