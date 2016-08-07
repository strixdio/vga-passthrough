#!/bin/sh

function print_warning ()
{
	clear
	echo -e "Make sure your boot partion is mounted BEFORE continuing with this script!\nPress \"Enter\" to continue, or ctrl+c to quit.\n"
	read
}

function tidy_string()
{
        echo $(sed -e 's/  / /g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< $@ | tr '\n' ' ')
}

function backup_grub ()
{
        if [ ! -e /etc/default/grub.orig ]
        then
                cp -f /etc/default/grub /etc/default/grub.orig
        fi
}

function update_modprobe ()
{
        if [ ! -e /etc/modprobe.d/vfio.conf.orig ]
        then
                cp -f /etc/modprobe.d/vfio.conf /etc/modprobe.d/vfio.conf.orig
        fi
        echo "Creating /sbin/vfio-pci-override-vga.sh ..."
        cp -f ./vfio-pci-override-vga.sh.gen /sbin/vfio-pci-override-vga.sh
        chmod 775 /sbin/vfio-pci-override-vga.sh
        echo 'install vfio-pci /sbin/vfio-pci-override-vga.sh' > /etc/modprobe.d/vfio.conf
}

function update_dracut ()
{
        if [ ! -e /etc/dracut.conf.d/vfio.conf.orig ]
        then
                cp -f /etc/dracut.conf.d/vfio.conf /etc/dracut.conf.d/vfio.conf.orig
        fi
        echo 'add_drivers+="vfio vfio_iommu_type1 vfio_pci vfio_virqfd"' > /etc/dracut.conf.d/vfio.conf
        echo 'install_items+="/sbin/vfio-pci-override-vga.sh"' >> /etc/dracut.conf.d/vfio.conf
        dracut -fv --kver `uname -r`
}

function get_gpulist()
{
        gpulist=$(lspci -m | grep VGA | awk -F' ' '{ print $1 }')
}

function print_gpulist()
{
        echo "GPU's and their audio devices (if applicable) found:"
        echo
        for i in $gpulist
        do
                find=$(awk -F'.' '{ print $1 }' <<< $i)
                echo "$(lspci -m | grep $find)"
        done
}

function select_gpus()
{
        echo -e "\nSelect GPU(s) you wish to use for vga-passthrough. 'd' for done."
        select gpu in $gpulist
        do
                case $gpu in
                "$QUIT")
                        break
                ;;
                *)
                        if [[ ! $gpu_uselist == *$gpu* ]]
                        then
                                gpu_uselist="$gpu_uselist $gpu"
                        else
                                gpu_uselist=`sed "s/$gpu//g" <<< $gpu_uselist`
                        fi
                        gpu_uselist=$(tidy_string $gpu_uselist)
                        echo "Selected: $gpu_uselist"
                ;;
                esac
        done
        print_gpu_uselist
}

function print_gpu_uselist()
{
	echo -e "\nUsing:"
        for i in $gpu_uselist
        do
                find=$(awk -F'.' '{ print $1 }' <<< $i)
                echo "$(lspci -m | grep $find)"
        done
}

function gen_wrapper()
{
        cmd_list=""
        cmd_sed=" | sed 's|aAaA|aAaA,x-vga=on|g'"
        for i in $gpu_uselist
        do
                cmd_replace=$(sed "s/aAaA/$i/g" <<< $cmd_sed)
                cmd_list="$cmd_list $cmd_replace"
        done
	if [[ -e /usr/bin/qemu-kvm ]]
	then
        	cmd="exec /usr/bin/qemu-kvm \`echo \"\$@\"$cmd_list\`"
	else
		cmd="exec /usr/bin/qemu-system-x86_64 \`echo \"\$@\"$cmd_list\`"
	fi
	echo -e "#!/bin/bash\n\n$cmd" > ./qemu-kvm.vga.gen
}

function gen_override()
{
        for i in $gpu_uselist
        do
                find=$(awk -F'.' '{ print $1 }' <<< $i)
                cmd_devs=$(tidy_string "$cmd_devs $(lspci -m | grep $find | awk -F' ' '{ print $1}')")
        done
	for i in $cmd_devs
	do
		tmp=$(tidy_string "$tmp 0000:$i")
	done
	cmd_devs=$tmp

	echo -e "#!/bin/sh\n\nDEVS=\"aAaA\"\nfor DEV in \$DEVS; do\n	echo \"vfio-pci\" > /sys/bus/pci/devices/\$DEV/driver_override\ndone\nmodprobe -i vfio-pci" | sed "s/aAaA/$cmd_devs/g" > ./vfio-pci-override-vga.sh.gen

	#echo -e "#!/bin/sh\n" > ./$file
        #echo "DEVS=\"aAaA\"" | sed "s/aAaA/$cmd_devs/g" >> ./$file
        #echo -e "for DEV in \$DEVS; do\n        echo \"vfio-pci\" > /sys/bus/pci/devices/\$DEV/driver_override\ndone\nmodprobe -i vfio-pci" >> ./$file
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

function select_params()
{
	echo -e "\nSelect additional kernel params you wish to use. 'd' for done.\nPlease make sure you research each option, and only use those that are required for your setup.\n"
	param_list="iommu=pt vfio_iommu_type1.allow_unsafe_interrupts=1 pcie_acs_override=downstream"
	select param in $param_list
	do
		case $param in
                "$QUIT")
                        break
                ;;
                *)
                        if [[ ! $param_uselist == *$param* ]]
                        then
                                param_uselist="$param_uselist $param"
                        else
                                param_uselist=`sed "s/$param//g" <<< $param_uselist`
                        fi
                        param_uselist=$(tidy_string $param_uselist)
                        echo "Additional kernel params: $param_uselist"
                ;;
                esac
	done
	params=$(tidy_string "$params $param_uselist")
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

function main ()
{
	print_warning
	backup_grub	
        get_gpulist
        print_gpulist
        select_gpus
        gen_wrapper
        gen_override
	echo
	get_cpu_params
	if [ ! "$params" == "" ]
	then
		select_params
		add_params
		echo "Kernel parameters will include: \"$params\"."
	fi
	echo "Press \"Enter\" to continue, or ctrl+c to quit."
	read
	update_modprobe
	grub2-mkconfig -o /boot/grub2/grub.cfg
	update_dracut
	echo "Creating /usr/bin/qemu-kvm.vga ..."
	cp -f ./qemu-kvm.vga.gen /usr/bin/qemu-kvm.vga
	rm -rf ./qemu-kvm.vga.gen vfio-pci-override-vga.sh.gen
	echo "Done. To use vga-passthrough with virt-manager, "virsh edit" to modify <emulator> contents to /usr/bin/qemu-kvm.vga"
}


# Run the main loop
main
