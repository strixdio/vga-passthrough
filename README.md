# README.md

# vga-passthrough using vfio
# Most of the work is from Alex Williamson, from https://vfio.blogspot.com/2015/05/vfio-gpu-how-to-series-part-1-hardware.html. Please use his material for configuring this script to your use case.
# I only organized it in a way to make vga-passthrough setup easier.
# You are welcome to use it, but I am not responsible for any damages.

# Please make sure your kernel has any relevant vfio options enabled before running anything.
# This script DOES back up grubs config, just in case anything breaks.
# This script assumes that /etc/modprobe.d/local.conf either does not exist, or is not needed in its current configuration.
# This script assumes that /etc/dracut.conf.d/local.conf either does not exist, or is not needed in its current configuration.
# This script assumes that you are using an intel processor. Please modify the relevant boot params to suit your processor.

# Once all edits are made to suit your use case, and all code is audited that it will not cause any harm, simply run: vfio-setup.sh
