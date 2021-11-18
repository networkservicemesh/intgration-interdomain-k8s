#!/bin/bash -x
# shellcheck disable=SC2086

master_ip="$1"
worker_ip="$2"
SSH_OPTS="$3"

function wait_pids() {
  pids="$1"
  message="$2"
  for pid in ${pids}; do
    echo "waiting for PID ${pid}"
    wait ${pid}
    code=$?
    if test $code -ne 0; then
      echo "${message}: process exited with code $code, aborting..."
      return 1
    fi
  done
  return 0
}

SRIOV_DIR=$(dirname "$0")

# Create SR-IOV scripts directory on nodes
ssh ${SSH_OPTS} root@${master_ip} mkdir sriov
ssh ${SSH_OPTS} root@${worker_ip} mkdir sriov

# Enable SR-IOV and wait for the servers to reboot
scp ${SSH_OPTS} ${SRIOV_DIR}/enable-SRIOV.sh root@${master_ip}:sriov/enable-SRIOV.sh || exit 1
scp ${SSH_OPTS} ${SRIOV_DIR}/enable-SRIOV.sh root@${worker_ip}:sriov/enable-SRIOV.sh || exit 2

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./sriov/enable-SRIOV.sh &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./sriov/enable-SRIOV.sh &
pids+=" $!"
wait_pids "${pids}" "SR-IOV setup failed" || exit 3

sleep 5

for ip in ${master_ip} ${worker_ip}; do
  success_attempts=0
  # ~15 minutes to start
  for i in {1..60}; do
    if [[ ${i} == 60 ]]; then
      echo "timeout waiting for the ${ip} to start, aborting..."
      exit 4
    fi

    if ssh ${SSH_OPTS} -o ConnectTimeout=1 -o BatchMode=yes root@${ip} true; then
      ((success_attempts++))
    else
      success_attempts=0
    fi

    if [[ ${success_attempts} == 3 ]]; then
      break
    fi

    sleep 15
  done
done

# Create SR-IOV config
scp ${SSH_OPTS} ${SRIOV_DIR}/config-SRIOV.sh root@${master_ip}:sriov/config-SRIOV.sh || exit 5
scp ${SSH_OPTS} ${SRIOV_DIR}/config-SRIOV.sh root@${worker_ip}:sriov/config-SRIOV.sh || exit 6

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./sriov/config-SRIOV.sh eno4=worker.domain &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./sriov/config-SRIOV.sh eno4=master.domain &
pids+=" $!"
wait_pids "${pids}" "SR-IOV config failed" || exit 7

# Enable VFIO driver
scp ${SSH_OPTS} ${SRIOV_DIR}/enable-VFIO.sh root@${master_ip}:sriov/enable-VFIO.sh || exit 8
scp ${SSH_OPTS} ${SRIOV_DIR}/enable-VFIO.sh root@${worker_ip}:sriov/enable-VFIO.sh || exit 9

pids=""
ssh ${SSH_OPTS} root@${master_ip} ./sriov/enable-VFIO.sh eno4 &
pids+=" $!"
ssh ${SSH_OPTS} root@${worker_ip} ./sriov/enable-VFIO.sh eno4 &
pids+=" $!"
wait_pids "${pids}" "VFIO enabling failed" || exit 10
