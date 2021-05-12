#!/bin/bash
set -eux

DEBUG_QEMU=false
DEBUG_KERNEL=false
RUN_GDB=false
while getopts "dsg" opt; do
	case $opt in
	d) DEBUG_QEMU=true ;;
	s) DEBUG_KERNEL=true ;;
  g) RUN_GDB=true;;
	*) exit 0 ;;
	esac
done

sure() {
	read -r -p "$1 " yn
	case $yn in
	[Yy]*) return ;;
	[Nn]*) exit ;;
	*) echo "Please answer yes or no." ;;
	esac
}

abs_loc=/home/maritns3/core/vn/hack/qemu/x64-e1000
iso=${abs_loc}/alpine-standard-3.13.5-x86_64.iso
disk_img=${abs_loc}/alpine.qcow2
kernel=/home/maritns3/core/ubuntu-linux/arch/x86/boot/bzImage
qemu=/home/maritns3/core/kvmqemu/build/qemu-system-x86_64

if [ ! -f "$iso" ]; then
	echo "${iso} not found!"
	exit 0
fi

if [ ! -f "${disk_img}" ]; then
	sure "create image"
	qemu-img create -f qcow2 ${disk_img} 1T
	qemu-system-x86_64 \
		-cdrom "$iso" \
		-hda ${disk_img} \
		-enable-kvm \
		-m 2G \
		-smp 2 \
		;
	exit 0
fi

if [ $DEBUG_QEMU = true ]; then
	gdb --args ${qemu} \
		-drive "file=${disk_img},format=qcow2" \
		-m 8G \
		-enable-kvm \
		-kernel ${kernel} \
		-append "root=/dev/sda3" \
		-smp 8 \
		-vga virtio \

	exit 0
fi

if [ $DEBUG_KERNEL = true ]; then
	${qemu} \
		-drive "file=${disk_img},format=qcow2" \
		-m 8G \
		-enable-kvm \
		-kernel ${kernel} \
		-append "root=/dev/sda3 nokaslr console=ttyS0" \
		-smp 1 \
		-vga virtio \
		-cpu host \
		-S -s

	exit 0
fi

if [ $RUN_GDB = true ];then
  cd /home/maritns3/core/ubuntu-linux/
  gdb vmlinux -ex "target remote :1234" -ex "hbreak start_kernel" -ex "continue"
  exit 0
fi

${qemu} \
	-drive "file=${disk_img},format=qcow2" \
	-m 8G \
	-enable-kvm \
	-kernel ${kernel} \
	-append "root=/dev/sda3 nokaslr console=ttyS0" \
	-smp 1 \
	-vga virtio \
	-cpu host \
  -monitor stdio