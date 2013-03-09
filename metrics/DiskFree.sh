#!/bin/bash
#
# Check the free disk space available
#
# __date__: 02/19/2013
# __author__: rremer@sunrunhome.com (Royce Remer)

METRIC_UNIT=Bytes
DISK_HANDLE=xvda1
TMPFILE=/var/run/cloudwatchd/DiskFree$DISK_HANDLE.txt

DISK_STATS=`df | grep "$DISK_HANDLE"`
if [ -n "$DISK_STATS" ]
	then
		echo "$DISK_STATS" > $TMPFILE
		awk 'END {print $4}' $TMPFILE
fi
