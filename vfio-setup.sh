#!/bin/sh

# Back up grub

if [ ! -e /etc/default/grub.orig ]
then
	cp /etc/default/grub /etc/default/grub.orig
fi


# Add boot params
# Be sure to modify for your use case. This is for an intel processor.
# Make sure your boot partition is mounted

params='rd.driver.pre=vfio-pci intel_iommu=on vfio_iommu_type1 pcie_acs_override=downstream'
sed "s/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 $params\"/" /etc/default/grub.orig > /etc/default/grub.tmp
mv /etc/default/grub.tmp /etc/default/grub


# Back up /etc/modprobe.d/local.conf if it exists
# Add /etc/modprobe.d/local.conf

if [ ! -e /etc/modprobe.d/local.conf.orig ]
then
	cp /etc/modprobe.d/local.conf /etc/modprobe.d/local.conf.orig
fi
cp -f ./vfio-pci-override-vga.sh /sbin/
chmod 775 /sbin/vfio-pci-override-vga.sh
echo 'install vfio-pci /sbin/vfio-pci-override-vga.sh' > /etc/modprobe.d/local.conf


# Update grub config

grub2-mkconfig -o /boot/grub2/grub.cfg


# Back up /etc/dracut.conf.d/local.conf if it exists
# Update dracut

if [ ! -e /etc/dracut.conf.d/local.conf.orig ]
then
        cp /etc/dracut.conf.d/local.conf /etc/dracut.conf.d/local.conf.orig
fi
echo 'add_drivers+="vfio vfio_iommu_type1 vfio_pci vfio_virqfd"' > /etc/dracut.conf.d/local.conf
echo 'install_items+="/sbin/vfio-pci-override-vga.sh"' >> /etc/dracut.conf.d/local.conf
dracut -fv --kver `uname -r`


# Copy wrapper script

cp -f ./qemu-kvm.vga /usr/bin/qemu-kvm.vga


# To use vga-passthrough with virt-manager, "virsh edit" to modify <emulator> contents to /usr/bin/qemu-kvm.vga
