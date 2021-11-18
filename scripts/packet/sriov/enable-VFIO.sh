#!/bin/bash
# shellcheck disable=SC2002,SC2064

device="/sys/class/net/$1/device"

# modprobe VFIO driver
VFIO_DIR="/sys/bus/pci/drivers/vfio-pci"
ls -l "${VFIO_DIR}" || modprobe vfio-pci || exit 1

# Don't forget to remove VFs for the link
trap "echo 0 >'${device}/sriov_numvfs'" err exit

# Add 1 VF for the link
echo 1 > "${device}/sriov_numvfs" || exit 2

# Get VF pci id
pci_id=$(cat "${device}/virtfn0/uevent" | grep "PCI_ID" | sed -E "s/PCI_ID=(.*):(.*)/\1 \2/g")
test $? -eq 0 || exit 3

# Enable VFIO driver for the VF
echo "${pci_id}" > "${VFIO_DIR}/new_id" || exit 4
