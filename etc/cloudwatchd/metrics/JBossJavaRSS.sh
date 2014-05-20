#!/bin/bash
#
# Check the resident set size of memory allocated to the jboss jvm

NAMESPACE=default
METRIC_UNIT=Kilobytes
CHECK_CMD=$(ps h -C java -o rss,user | grep jboss | cut -d ' ' -f 1 | head -n 1)
echo $CHECK_CMD
