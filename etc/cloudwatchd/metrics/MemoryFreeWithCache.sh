#!/bin/bash
#
# Check the free memory available include disk cache

NAMESPACE=default
METRIC_UNIT=Kilobytes
MEM_FREE=$(grep MemFree /proc/meminfo | tr -s " " | cut -d " " -f 2)
MEM_BUFFERS=$(grep Buffers /proc/meminfo | tr -s " " | cut -d " " -f 2)
CHECK_CMD=$(expr $MEM_FREE \+ $MEM_BUFFERS)
echo $CHECK_CMD
