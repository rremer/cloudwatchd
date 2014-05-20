Below is the minimum IAM policy access needed for a user in your AWS account. You can name the user whatever you wish, although 'cloudwatchd' might be the most transparent:
```sh
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
 "Resource": ["*"]}]}
 ```
