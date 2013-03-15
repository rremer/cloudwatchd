#!/usr/bin/python
"""A daemon for running scripts and posting output to Amazon's Cloudwatch."""

"""
This file is part of cloudwatchd.

Cloudwatchd is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Cloudwatchd is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with cloudwatchd. If not, see <http://www.gnu.org/licenses/>.
"""

__author__ = 'Royce Remer (rremer@sunrunhome.com)'
__version__ = "1.0"


import boto
import logging
import re
from logging import handlers as logging_handlers
from optparse import OptionParser
from os import listdir, popen, uname
from sys import argv, stdout
from time import sleep


def init_option_parser(args):
    """Setup command line argument parser.
    
    Args:
        args: List of strings, command-line arguments to be parsed.
    Returns:
        options: OptionParser options object.
    """

    parser = OptionParser()
    parser.add_option("-c", "--conf", "--config",
        dest="conf_filename",
        action="store",
        type="string",
        default="/etc/cloudwatchd/cloudwatchd.conf",
        help="Cloudwatch configuration file to source; default: %default")
    parser.add_option("-i", "--interval",
        dest="interval",
        action="store",
        type="int",
        default="5",
        help="Frequency interval to run metric scripts at (in seconds); "
            "default: %default")
    parser.add_option("-l", "--log",
        dest="log_filepath",
        action="store",
        type="string",
        default="/var/log/cloudwatchd/cloudwatchd.log",
        help="Log activities to this location, filepath or 'stdout'")
    options = parser.parse_args(args)
    return options
    

def parse_conf(filepath):
    """Take a path to a configuration file and parse its options into a dict.

    Args:
        filepath: String, full system path to a file to parse.
    Returns:
        options: Dict, option pairs contained in the config file provided.
    """

    options = {}
    with open(filepath,'r') as conf:
        for line in conf:
            if line[0] is not "#" and line.find("=") is not -1:
                try:
                    key, value = line.split("=", 1)
                    value = value.strip()
                    options[key] = value
                except ValueError:
                    pass # We found an "=" sign that is missing a key or a value
    return options


def get_connection(credentials, logger):
    """Take Cloudwatch credentials and connect to local endpoint.

    Args:
        credentials: Dict of Amazon Cloudwatch read/write API credentials.
        logger: Logging object.
    Returns:
        connection: boto.cloudwatch connection object.
        instance_metadata: Dict of metadata about running EC2 instance.
    """

    required_iam_policy = """
        {"Statement": [{
             "Action": [
                 "cloudwatch:*",
                 "sns:*",
                 "autoscaling:Describe*"],
             "Effect": "Allow",
             "Resource": "*"}]}"""

    connection = boto.connect_ec2(
        aws_access_key_id=credentials.get('AWSAccessKeyId'),
        aws_secret_access_key=credentials.get('AWSSecretKey'))

    # You can get instance metadata with any IAM policies
    instance_metadata = boto.utils.get_instance_metadata()
    reservation_id_index = None
    reservation_id_reg = re.compile(instance_metadata['reservation-id'])
    try:
        for index, item in enumerate(connection.get_all_instances()):
            if bool(re.search(reservation_id_reg, repr(item))):
                reservation_id_index = index
        instance_tags = (connection.get_all_instances()[reservation_id_index]
            .instances[0].tags)
        instance_metadata['tags'] = instance_tags
    # You can't enumerate IAM policy without a policy allowing you to
    # So attempt ec2 connection, then fall back to cloudwatch connection
    except boto.exception.EC2ResponseError:
        logger.warn("IAM user with access key %s will need the following "
            """policy additions to post data from EC2 instance tags:
            %s""" % (credentials.get('AWSAccessKeyId'),required_iam_policy))
    connection = boto.connect_cloudwatch(
        aws_access_key_id=credentials.get('AWSAccessKeyId'),
        aws_secret_access_key=credentials.get('AWSSecretKey'))

    # Get a list of region objects and find which one to connect to
    instance_region_str = ((instance_metadata.get('placement')
        .get('availability-zone'))[:-1])
    instance_region_reg = re.compile(instance_region_str)
    cloudwatch_region_index = None
    cloudwatch_region_list = boto.ec2.cloudwatch.regions()
    for index, item in enumerate(cloudwatch_region_list):
        if bool(re.search(instance_region_reg, repr(item))):
            cloudwatch_region_index = index
    if cloudwatch_region_index == None:
        logger.info("Local region '%s' not one of listed endpoints %s" %(
            instance_region_str, cloudwatch_region_list))

    # Reconnect to the correct region endpoint
    try:
        region = cloudwatch_region_list[cloudwatch_region_index]
        logger.info("Connecting to %s" %region)
        connection = boto.connect_cloudwatch(
            aws_access_key_id=credentials.get('AWSAccessKeyId'),
            aws_secret_access_key=credentials.get('AWSSecretKey'),
            region=region)
    except boto.exception.BotoServerError as error:
        logger.info("Error connecting to cloudwatch with credentials %s: %s" %(
            credentials,error.error_message))
        
    return connection, instance_metadata


def put_metrics(connection, metadata, metrics_dir, options, logger):
    """Runs scripts out of a directory and sends the output to Cloudwatch.

    Args:
        connection: boto.cloudwatch connection object.
        metadata: Dict of metadata about running EC2 instance.
        metrics_dir: String, full path to a directory of executable scripts.
        options: OptionParser options object.
        logger: Logging object.
    """

    # Determine if detailed monitoring is enabled
    # This will change with https://github.com/boto/boto/pull/1383
    instance_dynamic = boto.utils._get_instance_metadata(
        'http://169.254.169.254/latest/dynamic/').keys()
    try:
        instance_dynamic.index('fws')
        cloudwatch_detailed = True
    except ValueError:
        cloudwatch_detailed = False

    cloudwatch_shared_dict = ({'dimensions':
        {'instanceid':metadata.get('instance-id')}})
    try:
        for tag in metadata['tags'].keys():
            cloudwatch_shared_dict['dimensions'][tag] = (
                metadata['tags'].get(tag))
    except KeyError:
        logger.info("No tags could be found for this instance.")
    logger.info("Shared instance metrics are: %s" % repr(
        cloudwatch_shared_dict))

    metrics_dir_list = listdir(metrics_dir)
    logger.info("Metric scripts found: %s" % repr(metrics_dir_list))
    known_extension_dict = {'py':'python', 'pl':'perl', 'sh':'sh'}

    # Continuously loop through the metrics dir (sleep at the end)
    while True:
        metrics_dir_updated_list = listdir(metrics_dir)
        if metrics_dir_list != metrics_dir_updated_list:
            metrics_dir_list = metrics_dir_updated_list
            logger.info("Metrics dir contents have changed, found: %s"
                %repr(metrics_dir_list))
        for script in metrics_dir_list:
            cloudwatch_metric_dict = cloudwatch_shared_dict
            script_path = "%s/%s" % (metrics_dir, script)
            if script.find(".") is not -1:
                metric_name, script_extension = script.split(".", 1)
            else:
                metric_name = script
                script_extension = None
            # If we don't know how to run the script, warn and continue
            if script_extension not in known_extension_dict.keys():
                logger.warn("Skipping %s, '%s' is not an extension in %s" %(
                  script_path,script_extension,
                  repr(known_extension_dict.keys())))
            else:
                cloudwatch_metric_dict['namespace'] = (parse_conf(script_path)
                    .get('NAMESPACE'))
                if cloudwatch_metric_dict['namespace'] == None:
                    logger.info("%s had no NAMESPACE key set, "
                    "putting in 'default'" %script_path)
                    cloudwatch_metric_dict['namespace'] = "default"
                cloudwatch_metric_dict['name'] = metric_name
                cloudwatch_metric_dict['unit'] = (parse_conf(script_path)
                    .get('METRIC_UNIT'))
                logger.info(("Running %s %s") %(known_extension_dict.get(
                    script_extension),script_path))
                # Run the script found, assume stdout is a float
                try:
                    cloudwatch_metric_dict['value'] = float(popen("%s %s" %(
                        known_extension_dict.get(script_extension),
                        script_path)).readline().strip())
                except ValueError:
                    cloudwatch_metric_dict['value'] = None
                # Strip uneccesary precision for this metric
                if str(cloudwatch_metric_dict.get('value'))[-2:] == '.0':
                    cloudwatch_metric_dict['value'] = (
                        int(cloudwatch_metric_dict.get('value')))
                # If the output of the script was not usable, warn and continue
                if isinstance(cloudwatch_metric_dict.get('value'),
                    (int,long,float)):
                    logger.info(("Sending %s to %s") %(
                        cloudwatch_metric_dict,connection.region))
                    connection.put_metric_data(**cloudwatch_metric_dict)
                else:
                    logger.warn("Last run of %s produced no value, "
                        "nothing to send to cloudwatch" %script_path)
        if cloudwatch_detailed == False:
            logger.warn("You must enable detailed monitoring in Amazon's "
                "Cloudwatch for sent metrics to appear in the panel.")
        logger.info(("Sleeping %s seconds") %options.interval)
        sleep(options.interval)


def init_logger(options):
    """Setup logging facility.

    Args:
        options: OptionParser options object.
    Returns:
        logger: Logging object.
    """

    logger = logging.getLogger('logger')
    logger.setLevel(logging.DEBUG)
    if options.log_filepath == 'stdout':
        handler = logging.StreamHandler(stdout)
    else:
        handler = logging_handlers.RotatingFileHandler(
            options.log_filepath, mode='a', maxBytes=20000, backupCount=5)

    handler.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    return logger

if __name__ == "__main__":
    (cli_options, cli_args) = init_option_parser(args=argv)
    Logger = init_logger(cli_options)
    Logger.info("Using %s as configuration file" %cli_options.conf_filename)
    cloudwatch_conf = parse_conf(cli_options.conf_filename)
    aws_creds = parse_conf(cloudwatch_conf.get('AWS_CREDENTIAL_FILE'))
    Logger.info(("Using %s as credentials file") %(cloudwatch_conf.get(
        'AWS_CREDENTIAL_FILE')))
    CloudwatchCon,EC2MetaData = get_connection(credentials=aws_creds,
        logger=Logger)
    put_metrics(
        connection=CloudwatchCon,
        metadata=EC2MetaData,
        metrics_dir=cloudwatch_conf.get('CLOUDWATCH_METRICS_DIR'),
        options=cli_options,
        logger=Logger)
