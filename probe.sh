#!/usr/bin/env sh
################################################################################
#
# 1. Change HBIP to your prefer
# 2. Enable this script by set ONOFF to 'y'
# 3. Add crontab task
#    vi /etc/rc.local.d/local.sh
# 4. Append this line to /etc/rc.local.d/local.sh
#
#    /bin/echo '*/5  *    *   *   *   /opt/esxi-scripts/probe.sh >/dev/null 2>&1' >> /var/spool/cron/crontabs/root
#
################################################################################
#
HERE=`cd $(dirname $0); pwd`
HBIP=192.168.0.10
ONOFF=n
RETRY_SEC=30
FILETAG=$(date +'%Y%m%d')
LOGFILE="$HERE/log/esxi.$FILETAG.log"

log_prefix() {
  date +'%Y-%m-%d %H:%M:%S'
}

list_vms() {
  vim-cmd vmsvc/getallvms | sed '1d;s/ .*$//'
}

check_vm_state() {
  vim-cmd vmsvc/power.getstate $1 | grep 'Powered on'
}

shutdown_vm() {
  # echo "vim-cmd vmsvc/power.off $1" >> $LOGFILE
  echo "$(log_prefix) vim-cmd vmsvc/power.off $1" >> $LOGFILE
  if [ "$ONOFF" = "y" ]; then
    vim-cmd vmsvc/power.off $1
  fi
}

test_heartbeats() {
  ping -c 3 $HBIP > /dev/null 2>&1
  retval=$?
  echo "$(log_prefix) ping $HBIP" >> $LOGFILE
  echo $retval
}


double_ping() {
  first_try=$(test_heartbeats)
  if [ $first_try -eq 0 ]; then
    echo 'alive'
  else
    sleep $RETRY_SEC
    second_try=$(test_heartbeats)
    if [ $second_try -eq 0 ]; then
      echo 'alive'
    else
      echo 'dead'
    fi
  fi
}


echo "$(log_prefix) start" >> $LOGFILE
if [ "$(double_ping)" == "alive" ]; then
  echo "$(log_prefix) $HBIP is alive" >> $LOGFILE
else
  echo "$(log_prefix) $HBIP is dead" >> $LOGFILE
  # do power off
  for vmid in $(list_vms); do
    power_state=$(check_vm_state $vmid)
    if [ -n "$power_state" ]; then
      shutdown_vm $vmid
      sleep 5
    fi
  done
  sleep 200
  poweroff
fi
echo "$(log_prefix) finish" >> $LOGFILE
