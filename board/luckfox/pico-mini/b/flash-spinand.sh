#!/bin/sh
#
# Write the Buildroot images to the SPI NAND of a Luckfox Pico Mini B
# in USB download (maskrom) mode, with rkdeveloptool.
#
# Usage: flash-spinand.sh [OUTPUT_DIR]
#
# OUTPUT_DIR is the Buildroot output directory (default: output).

set -e

OUTPUT_DIR="$(realpath "${1:-output}")"
IMAGES="${OUTPUT_DIR}/images"
RKDEVELOPTOOL="${OUTPUT_DIR}/host/bin/rkdeveloptool"

echo "Waiting for a board in maskrom mode (USB 2207:110c)..."
until "${RKDEVELOPTOOL}" ld 2>/dev/null | grep -q 'Maskrom'; do
	sleep 1
done

"${RKDEVELOPTOOL}" db "${IMAGES}"/rv1106_download_*.bin
"${RKDEVELOPTOOL}" ef

# start sector (512 bytes sectors), image
while read -r start image; do
	echo "Writing ${image}..."
	"${RKDEVELOPTOOL}" wl "${start}" "${IMAGES}/${image}"
done <<EOF
0x200 idbloader.img
0xa00 u-boot.img
0x1200 boot.itb
0x5200 rootfs.ubi
EOF

"${RKDEVELOPTOOL}" rd
