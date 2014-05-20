#!/bin/bash
#
# Check the free memory available

NAMESPACE=default
METRIC_UNIT=Kilobytes
CHECK_CMD=$(expr `free -m | grep Mem | tr -s ' ' | cut -d ' ' -f 4` \* 1000)
echo $CHECK_CMD
