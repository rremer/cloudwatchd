#!/bin/bash
#
# Check free disk space available on the root volume

NAMESPACE=default
METRIC_UNIT=Bytes
DISK_HANDLE=xvda1
TMPFILE=/var/run/cloudwatchd/DiskFree$DISK_HANDLE.txt

DISK_STATS=`df | grep "$DISK_HANDLE"`
if [ -n "$DISK_STATS" ]
	then
		echo "$DISK_STATS" > $TMPFILE
		awk 'END {print $4}' $TMPFILE
fi
