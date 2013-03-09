#!/bin/bash
#
# Check the resident set size of memory allocated to java
#
# __date__: 03/01/2013
# __author__: rremer@sunrunhome.com (Royce Remer)

METRIC_UNIT=Kilobytes
CHECK_CMD=$(ps h -C java -o rss)
echo $CHECK_CMD
