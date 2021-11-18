#!/bin/bash

sed -Ei "s/(GRUB_CMDLINE_LINUX=.*)'/\1 intel_iommu=on'/" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

nohup bash -c "sleep 5; reboot" >/dev/null 2>&1 &
