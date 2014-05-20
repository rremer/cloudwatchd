#!/bin/sh
#
# Time a page load
# Version: 02/20/2013

NAMESPACE=default
METRIC_UNIT=Seconds

curl -s -w %{time_total} -o /dev/null localhost
