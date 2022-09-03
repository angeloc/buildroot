#!/bin/sh -e

for upperdir in $(sed -nr 's/.*upperdir=([^,]*).*/\1/p' /etc/fstab); do
	test -d "$upperdir" || \
		{ mkdir -p $upperdir && \
			mkdir -p $(grep "$upperdir" /etc/fstab | sed -nr 's/.*workdir=([^,]*).*/\1/p'); }
		mount $(grep "$upperdir" /etc/fstab | sed -nr "s/overlay[\ \t](.*)[\ \t]overlay.*/\1/p");
done
