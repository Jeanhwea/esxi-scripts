#!/usr/bin/env sh
################################################################################
#
# 1. Change VM_GATEWAY_IP to your prefer gateway ip as heartbeats
# 2. Enable set VM_ONOFF_FLAG to 'y', poweroff the virtual machines.
# 3. Enable set VM_SHUTDOWN_HOST to 'y', also poweroff the host.  (optional)
# 4. Add crontab task
#    vi /etc/rc.local.d/local.sh
# 5. Append this line to /etc/rc.local.d/local.sh
#
#    /bin/echo '*/5  *    *   *   *   /vmfs/volumes/datastore200/esxi-scripts/probe.sh >/dev/null 2>&1' >> /var/spool/cron/crontabs/root
#
################################################################################
#
HERE=`cd $(dirname $0); pwd`
VM_GATEWAY_IP=192.168.0.10
VM_ONOFF_FLAG=n
VM_SHUTDOWN_HOST=n
VM_RETRY_SEC=30
VM_FILE_TAG=$(date +'%Y%m%d')
VM_LOG_FILE="$HERE/log/esxi.$VM_FILE_TAG.log"

################################################################################
# local function
################################################################################
log_prefix() {
  date +'%Y-%m-%d %H:%M:%S'
}

vm_list_vmids() {
  vim-cmd vmsvc/getallvms | sed '1d;s/ .*$//'
}

vm_check_state() {
  vim-cmd vmsvc/power.getstate $1 | grep 'Powered on'
}

vm_do_poweroff() {
  echo "$(log_prefix) vim-cmd vmsvc/power.off $1" >> $VM_LOG_FILE
  if [ "$VM_ONOFF_FLAG" = "y" ]; then
    vim-cmd vmsvc/power.off $1
  fi
}

vm_ping_gateway() {
  ping -c 3 $VM_GATEWAY_IP >/dev/null 2>&1
  retval=$?
  echo "$(log_prefix) ping $VM_GATEWAY_IP" >> $VM_LOG_FILE
  echo $retval
}

vm_double_ping() {
  first_try=$(vm_ping_gateway)
  if [ $first_try -eq 0 ]; then
    echo 'alive'
  else
    sleep $VM_RETRY_SEC
    second_try=$(vm_ping_gateway)
    if [ $second_try -eq 0 ]; then
      echo 'alive'
    else
      echo 'dead'
    fi
  fi
}

################################################################################
# entry
################################################################################
echo "$(log_prefix) start" >> $VM_LOG_FILE
if [ "$(vm_double_ping)" == "alive" ]; then
  echo "$(log_prefix) $VM_GATEWAY_IP is alive" >> $VM_LOG_FILE
else
  echo "$(log_prefix) $VM_GATEWAY_IP is dead" >> $VM_LOG_FILE

  # poweroff the machines that is on
  for vmid in $(vm_list_vmids); do
    power_state=$(vm_check_state $vmid)
    if [ -n "$power_state" ]; then
      vm_do_poweroff $vmid
      sleep 5
    fi
  done

  # shutdown host machine if possible
  if [ "$VM_SHUTDOWN_HOST" = "y" ]; then
    sleep 200
    poweroff
  fi
fi
echo "$(log_prefix) finish" >> $VM_LOG_FILE
