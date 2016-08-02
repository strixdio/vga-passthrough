#!/bin/sh

function print_warning ()
{
	clear
	echo "Make sure your boot partion is mounted BEFORE continuing with this script!"
	echo "Press \"Enter\" to continue, or ctrl+c to quit."
	echo
	read
}

function get_cpu_params ()
{

	params="rd.driver.pre=vfio-pci"

        cpu_string=`cat /proc/cpuinfo | grep vendor_id | head -n 1`
        cpu_type=`sed "s/vendor_id : //g" <<< $cpu_string`

        case $cpu_type in
        GenuineIntel)
                params="$params intel_iommu=on"
                ;;
        AuthenticAMD)
                params="$params amd_iommu=on"
                ;;
	*)
		echo "Unknown processor. Please contribute to this script!"
		exit
		;;
        esac

        echo "CPU is \"$cpu_type\". Kernel params will include: \"$params\"."
        echo "Is this correct? (y)es/(n)o/(s)kip"
        read input_cpu

        case $input_cpu in
        y*)
                ;;
        n*)
                echo "Please edit the script for proper params. This script will now exit."
                exit
                ;;
	s*)
		echo "Skipping kernel param modifications"
		params=""
		;;
        *)
                echo "Invalid Input"
                get_cpu_params
                ;;
        esac
}

function get_unsafe_interrupts ()
{
        echo "Allow unsafe interupts? (y)es/(n)o"
        read input_unsafe

        case $input_unsafe in
        y*)
                params="$params vfio_iommu_type1.allow_unsafe_interrupts=1"
                ;;
        n*)
		params="$params vfio_iommu_type1"
                ;;
        *)
                echo "Invalid Input"
                get_unsafe_interrupts
                ;;
        esac
}

function get_iommu ()
{
        echo "iommu=pt? (y)es/(n)o"
        read input_iommu

        case $input_iommu in
        y*)
                params="$params iommu=pt"
                ;;
        n*)
                ;;
        *)
                echo "Invalid Input"
                get_iommu
                ;;
        esac
}

function get_acs_override ()
{
        echo "pcie_acs_override=downstream? (y)es/(n)o"
        read input_acs_override

        case $input_acs_override in
        y*)
                params="$params pcie_acs_override=downstream"
                ;;
        n*)
                ;;
        *)
                echo "Invalid Input"
                get_acs_override
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
	grub="/etc/default/grub"	
        grep -v "GRUB_CMDLINE_LINUX_DEFAULT=" $grub > $grub.tmp
        mv -f $grub.tmp $grub
        echo "GRUB_CMDLINE_LINUX_DEFAULT=\"\"" >> $grub
        sed "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1$params\"/" $grub > $grub.tmp
        mv -f $grub.tmp $grub
}

function update_modprobe ()
{
	if [ ! -e /etc/modprobe.d/local.conf.orig ]
	then
	        cp /etc/modprobe.d/local.conf /etc/modprobe.d/local.conf.orig
	fi
	cp -f ./vfio-pci-override-vga.sh /sbin/
	chmod 775 /sbin/vfio-pci-override-vga.sh
	echo 'install vfio-pci /sbin/vfio-pci-override-vga.sh' > /etc/modprobe.d/local.conf
}

function update_dracut ()
{
	if [ ! -e /etc/dracut.conf.d/local.conf.orig ]
	then
        	cp /etc/dracut.conf.d/local.conf /etc/dracut.conf.d/local.conf.orig
	fi
	echo 'add_drivers+="vfio vfio_iommu_type1 vfio_pci vfio_virqfd"' > /etc/dracut.conf.d/local.conf
	echo 'install_items+="/sbin/vfio-pci-override-vga.sh"' >> /etc/dracut.conf.d/local.conf
	dracut -fv --kver `uname -r`
}

function main ()
{
	print_warning
	backup_grub
	
	# Figure out kernel params
	get_cpu_params
	if [ ! "$params" == "" ]
	then
		get_iommu
		get_acs_override
		get_unsafe_interrupts
		add_params
		echo "Kernel parameters will include: \"$params\"."
	fi

	echo "Press \"Enter\" to continue, or ctrl+c to quit."
	read

	update_modprobe
	grub2-mkconfig -o /boot/grub2/grub.cfg
	update_dracut
	cp -f ./qemu-kvm.vga /usr/bin/qemu-kvm.vga

	echo "Done. To use vga-passthrough with virt-manager, "virsh edit" to modify <emulator> contents to /usr/bin/qemu-kvm.vga"
}

main
