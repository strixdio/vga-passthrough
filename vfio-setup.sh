#!/bin/sh

function print_warning ()
{
	clear
	echo "Make sure your boot partion is mounted BEFORE continuing with this script!"
	echo "Press \"Enter\" to continue, or ctrl+c to quit."
	echo
	read
}

function get_params1 ()
{
        cpu_string=`cat /proc/cpuinfo | grep vendor_id | head -n 1`
        cpu_type=`sed "s/vendor_id : //g" <<< $cpu_string`

        case $cpu_type in
        GenuineIntel)
                params='rd.driver.pre=vfio-pci intel_iommu=on vfio_iommu_type1 pcie_acs_override=downstream'
                ;;
        AuthenticAMD)
                params='rd.driver.pre=vfio-pci amd_iommu=on vfio_iommu_type1 pcie_acs_override=downstream iommu=pt iommu=1'
                ;;
	*)
		echo "Unknown processor. Please contribute to this script!"
		exit
		;;
        esac

        echo "CPU is \"$cpu_type\". Boot params will include: \"$params\"."
        echo "Is this correct? y/n"
        read input_cpu

        case $input_cpu in
        y*)
                ;;
        n*)
                echo "Please edit the script for proper params. This script will now exit."
                exit
                ;;
        *)
                echo "Invalid Input"
                get_params1
                ;;
        esac
}

function get_params2 ()
{
        echo "Allow unsafe interupts? y/n"
        read input_unsafe

        case $input_unsafe in
        y*)
                params="$params allow_unsafe_interrupts=1"
                echo "Boot parameters will include: \"$params\"."
                ;;
        n*)
                echo "Boot parameters will include: \"$params\"."
                ;;
        *)
                echo "Invalid Input"
                get_params2
                ;;
        esac
}

function backup_grub ()
{
	if [ ! -e /etc/default/grub.orig ]
	then
		cp /etc/default/grub /etc/default/grub.orig
	fi
}

function add_params ()
{
	sed "s/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 $params\"/" /etc/default/grub.orig > /etc/default/grub.tmp
	mv /etc/default/grub.tmp /etc/default/grub
}

print_warning
get_params1
get_params2
backup_grub
add_params

echo "Press \"Enter\" to continue, or ctrl+c to quit."
read

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
