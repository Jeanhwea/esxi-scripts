#!/usr/bin/env sh
HERE=`cd $(dirname $0); pwd`
ESXI_VMS=$(vim-cmd vmsvc/getallvms | sed '1d;s/ .*$//')

echo $HERE
echo $ESXI_VMS
