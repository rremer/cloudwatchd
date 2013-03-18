Cloudwatchd is a daemon which takes a directory of scripts in various programming languages, runs them at a designated interval, and sends their stdout along with parsed metadata to Amazon's Cloudwatch. To use this daemon, you will need to create an IAM user with at minimum the following policy applied:
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
 "Resource": ["*"]}]}"""

The purpose of this project is to allow you to quickly and easily collect more metrics from an Amazon EC2 instance by:

* Being language-agnostic - running any existing metric collectors your infrastructure might already have
* Being easily extensable - drop in new scripts into the metrics directory and they get picked up and run automatically
* Being robust - errors in individual scripts won't impede posting of other metrics

General project organization:

* Platform-specific configuration scripts are kept in directories named after their package extension
* Docs are kept in manpage format in the "docs" directory

Quick package internalization tip:
The scripts/build_pkg.sh script will pull in the configuration files and sample metrics. If you want to make an internal version of the package, you could edit credentials.conf with your Amazon Cloudwatchd-rw credentials, and put any custom metrics you might like automatically tracked into the metrics directory before running scripts/build_pkg.sh

Precompiled binaries are available in bin:

* https://github.com/rremer/cloudwatchd/raw/master/bin/cloudwatchd.deb
* https://github.com/rremer/cloudwatchd/raw/master/bin/cloudwatchd.rpm
