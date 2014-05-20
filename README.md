cloudwatchd
===========

Cloudwatchd is a daemon which takes a directory of scripts in various programming languages, runs them at a designated interval, and sends their stdout along with parsed metadata to Amazon's Cloudwatch.

The purpose of this project is to allow you to quickly and easily collect more metrics from an Amazon EC2 instance by:

* Being language-agnostic - running any existing metric collectors your infrastructure might already have
* Being easily extensable - drop in new scripts into the metrics directory and they get picked up and run automatically
* Being robust - errors in individual scripts won't impede posting of other metrics, stable daemonized service runner

### Installation
1. clone this repo and cd to it
2. create an IAM user in your aws account with the below policy
3. edit etc/cloudwatchd/prd-credentials.conf with the access key/secret of the IAM user you created
4. add any metrics you want to etc/metrics/ (see requirements below)
5. ```dpkg-buildpackage -rfakeroot -D -us -uc```
6. add package to your internal apt repo or scp to instances you desire
7. either apt-get install or dpkg -i the package locally
8. see the metrics stream to the region your ec2 instance with the installed package is in

### Minimum required user IAM policy
```
{"Statement": [{
    "Sid": "Stmt1363630451413",
    "Action": [
        "ec2:DescribeTags"],
        "Effect": "Allow",
    "Resource": ["*"]},
{"Sid": "Stmt1363630480443",
    "Action": [
        "cloudwatch:PutMetricData"],
        "Effect": "Allow",
    "Resource": ["*"]},
{"Sid": "Stmt1363630601639",
    "Action": [
        "ec2:DescribeInstances"],
        "Effect": "Allow",
    "Resource": ["*"]}
]}
```

### Requirements for metrics
* return a value to stdout
* have 'NAMESPACE=' with a string - this will be used to list the metric under the 'Custom Metrics' dropdown in the cloudwatch console
* have 'METRIC_UNIT=' with one of the following types used for graphing:
    - Seconds
    - Microseconds
    - Milliseconds
    - Bytes
    - Kilobytes
    - Megabytes
    - Gigabytes
    - Terabytes
    - Bits
    - Kilobits
    - Megabits
    - Gigabits
    - Terabits
    - Percent
    - Count
    - Bytes/Second
    - Kilobytes/Second
    - Megabytes/Second
    - Gigabytes/Second
    - Terabytes/Second
    - Bits/Second
    - Kilobits/Second
    - Megabits/Second
    - Gigabits/Second
    - Terabits/Second
    - Count/Second
    - None
