#!/bin/sh

BOARD_DIR="$(dirname "$0")"

# FIT image with the kernel and devicetree, for the "boot" SPI NAND
# partition
"${HOST_DIR}/bin/mkimage" -D "-i ${BINARIES_DIR}" \
	-f "${BOARD_DIR}/boot.its" "${BINARIES_DIR}/boot.itb"
