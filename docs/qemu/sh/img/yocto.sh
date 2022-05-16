#!/bin/bash
abs_loc=$(dirname "$(realpath "$0")")
yocto_img=${abs_loc}/yocto.ext4
ARCH=x86-64
YOCTO_URL=http://downloads.yoctoproject.org/releases/yocto/yocto-3.1/machines/qemu/qemu${ARCH}/
YOCTO_IMAGE_NAME=core-image-minimal-qemu${ARCH}.ext4
if [[ ! -f ${yocto_img} ]]; then
  wget ${YOCTO_URL}/${YOCTO_IMAGE_NAME} -O "${yocto_img}"
fi
