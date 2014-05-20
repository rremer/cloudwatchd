#!/bin/bash
#
# Check swap usage

NAMESPACE=default
METRIC_UNIT=Kilobytes
CHECK_CMD=$(swapon -s | cut -f 3)
if [ -z $CHECK_CMD ]
    then CHECK_CMD=0
fi
echo $CHECK_CMD
