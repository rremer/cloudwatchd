#!/bin/bash
#
# Check the free memory available
#
# __date__: 12/11/2012
# __author__: rremer@sunrunhome.com (Royce Remer)

METRIC_UNIT=Bytes
CHECK_CMD=$(expr `free -m | grep Mem | tr -s ' ' | cut -d ' ' -f 4` \* 1000)
echo $CHECK_CMD
