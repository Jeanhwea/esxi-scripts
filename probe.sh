#!/usr/bin/env sh
HERE=`cd $(dirname $0); pwd`
HBIP=192.168.0.10
FILETAG=$(date +'%Y%m%d')
LOGFILE="$HERE/log/esxi.$FILETAG.log"

function log_prefix() {
  date +'%Y-%m-%d %H:%M:%S'
}

function list_vms() {
  vim-cmd vmsvc/getallvms | sed '1d;s/ .*$//'
}

function check_vm_state() {
  vim-cmd vmsvc/power.getstate $1 | grep 'Powered on'
}

function poweroff_vm() {
  # echo "vim-cmd vmsvc/power.off $1" >> $LOGFILE
  echo "$(log_prefix) vim-cmd vmsvc/power.off $1" >> $LOGFILE
}

function test_heartbeats() {
  ping -c 1 $HBIP > /dev/null
  retval=$?
  echo $retval
}


echo "$(log_prefix) start" >> $LOGFILE
if [ $(test_heartbeats) -eq 0 ]; then
  echo "$(log_prefix) $HBIP is alive" >> $LOGFILE
else
  echo "$(log_prefix) $HBIP is dead" >> $LOGFILE
  # do power off
  for vmid in $(list_vms); do
    power_state=$(check_vm_state $vmid)
    if [ -n "$power_state" ]; then
      poweroff_vm $vmid
      sleep 1
    fi
  done
fi
echo "$(log_prefix) finish" >> $LOGFILE
