#!/bin/sh

# NOTES
# Change the pcie assignments to that of your GPU(s) INCLUDING THEIR AUDIO DEVICES

DEVS="0000:02:00.0 0000:02:00.1 0000:03:00.0 0000:03:00.1"

for DEV in $DEVS; do
    echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
done

modprobe -i vfio-pci
