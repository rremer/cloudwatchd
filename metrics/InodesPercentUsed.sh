#!/bin/bash
#
# Check inode percentage in use
#
# __date__: 10/22/2013
# __author__: royce@sunrun.com (Royce Remer)

METRIC_UNIT=Bytes
DISK_HANDLE=ubuntu-root
#DISK_HANDLE=xvda1
TMPFILE=/tmp/InodesPercentUsed-$DISK_HANDLE.txt
#TMPFILE=/var/run/cloudwatchd/DiskFree$DISK_HANDLE.txt

DISK_STATS=`df -i | grep "$DISK_HANDLE"`
if [ -n "$DISK_STATS" ]; then
    echo "$DISK_STATS" > $TMPFILE
    awk 'END {print $5}' $TMPFILE | awk -F\% '{print $(NF-1)}'
fi
