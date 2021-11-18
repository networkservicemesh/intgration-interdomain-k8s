#!/bin/bash
# shellcheck disable=SC2064,SC2129

CONFIG_DIRECTORY="/var/lib/networkservicemesh"
CONFIG_FILE="${CONFIG_DIRECTORY}/sriov.config"

function softlink_target() {
  softlink="$1"

  raw_target="$(stat -c %N "${softlink}")"
  test $? -eq 0 || return 1

  target=$(echo "${raw_target}" | sed -E "s/(.*\/)(.*)'/\2/g")
  test $? -eq 0 || return 2

  echo "${target}"
  return 0
}

function config_link() {
  device="/sys/class/net/$1/device"
  IFS=","; read -ra domains <<< "$2"; unset IFS

  pci_addr="$(softlink_target "${device}")"
  test $? -eq 0 || return 1

  pf_kernel_driver="$(softlink_target "${device}/driver")"
  test $? -eq 0 || return 1

  trap "echo 0 > '${device}/sriov_numvfs'" err exit
  echo 1 > "${device}/sriov_numvfs" || return 1
  vf_kernel_driver="$(softlink_target "${device}/virtfn0/driver")"
  test $? -eq 0 || return 1

  echo "  ${pci_addr}:" >> "${CONFIG_FILE}"
  echo "    pfKernelDriver: ${pf_kernel_driver}" >> "${CONFIG_FILE}"
  echo "    vfKernelDriver: ${vf_kernel_driver}" >> "${CONFIG_FILE}"
  echo "    capabilities:" >> "${CONFIG_FILE}"
  echo "      - intel" >> "${CONFIG_FILE}"
  echo "      - 10G" >> "${CONFIG_FILE}"
  echo "    serviceDomains:" >> "${CONFIG_FILE}"
  for domain in "${domains[@]}"; do
    echo "      - ${domain}" >> "${CONFIG_FILE}"
  done

  return 0
}

mkdir -p "${CONFIG_DIRECTORY}"

echo "---" > "${CONFIG_FILE}"
echo "physicalFunctions:" >> "${CONFIG_FILE}"

for link_domains in "$@"; do
  IFS="="; read -ra args <<< "${link_domains}"; unset IFS
  config_link "${args[0]}" "${args[1]}"
  test $? -eq 0 || exit 1
done
