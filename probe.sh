#!/usr/bin/env sh
################################################################################
#
# 1. Change VM_GATEWAY_IP to your prefer gateway ip as heartbeats
# 2. Set VM_ONOFF_FLAG=y to enable poweroff the virtual machines.
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
VM_ONOFF_FLAG=y
VM_SHUTDOWN_CLIENT=y
VM_SHUTDOWN_HOST=n
VM_PING_RETRY_SECOND=30
#
################################################################################


################################################################################
# helper
################################################################################
vm_local_date() {
  date -d @$(expr 28800000 + $(date +'%s')) "$@"
}

vm_log() {
  vm_local_date +'%Y-%m-%d %H:%M:%S'
}

VM_FILE_TAG=$(vm_local_date +'%Y%m%d')
VM_LOG_FILE="$HERE/log/esxi.$VM_FILE_TAG.log"


################################################################################
# local function
################################################################################
vm_list_vmids() {
  vim-cmd vmsvc/getallvms | sed '1d;s/ .*$//'
}

vm_check_state() {
  vim-cmd vmsvc/power.getstate $1 | grep -i 'Powered on'
}

vm_do_poweroff_client() {
  if [ "$VM_SHUTDOWN_CLIENT" = "y" ]; then
    echo "$(vm_log) vim-cmd vmsvc/power.off $1" >> $VM_LOG_FILE
    vim-cmd vmsvc/power.off $1
  fi
}

vm_do_poweroff_host() {
  if [ "$VM_SHUTDOWN_HOST" = "y" ]; then
    echo "$(vm_log) poweroff host machine" >> $VM_LOG_FILE
    poweroff
  fi
}

vm_ping_gateway() {
  ping -c 3 $VM_GATEWAY_IP >/dev/null 2>&1
  ping_retval=$?
  if [ $ping_retval -eq 0 ]; then
    ping_resp='alive'
  else
    ping_resp='dead'
  fi
  echo "$(vm_log) ping $VM_GATEWAY_IP, $ping_resp" >> $VM_LOG_FILE
  echo $ping_resp
}

vm_double_ping() {
  first_try=$(vm_ping_gateway)
  if [ "$first_try" == "alive" ]; then
    echo 'alive'
  else
    sleep $VM_PING_RETRY_SECOND
    second_try=$(vm_ping_gateway)
    if [ "$second_try" == "alive" ]; then
      echo 'alive'
    else
      echo 'dead'
    fi
  fi
}


################################################################################
# entry
################################################################################
echo "$(vm_log) start $0" >> $VM_LOG_FILE
if [ "$(vm_double_ping)" == "dead" ]; then
  if [ "$VM_ONOFF_FLAG" = "y" ]; then
    # Part 1: poweroff the machines that is on
    for vmid in $(vm_list_vmids); do
      power_state=$(vm_check_state $vmid)
      if [ -n "$power_state" ]; then
        sleep 5
        vm_do_poweroff_client $vmid
      fi
    done

    # Part 2: shutdown host machine if possible
    sleep 200
    vm_do_poweroff_host
  fi
fi
echo "$(vm_log) finish $0" >> $VM_LOG_FILE
echo "" >> $VM_LOG_FILE
