#!/usr/bin/env python2

from __future__ import print_function
import os
import sys
import argparse
import logging
from logging.handlers import RotatingFileHandler
import socket
import ConfigParser
import urllib
import tempfile
import shutil
from distutils.version import StrictVersion
from subprocess import Popen, PIPE, STDOUT
from cm_api.api_client import ApiResource

API_VERSION = 10

logging.basicConfig(format='%(asctime)s %(name)-12s %(levelname)-8s %(message)s',
                    datefmt='%m-%d %H:%M:%S')
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

script_path = os.path.dirname(os.path.realpath(__file__))
bash_scripts_path = os.path.join(script_path, "bash_scripts")

kerberized = False
debug_mode = False


def execute_script(script_name, args):
    full_path = os.path.join(bash_scripts_path, script_name)
    cmd = [full_path]
    cmd = cmd + args
    if debug_mode is not None and debug_mode is False:
        logger.debug(" ".join(map(str, cmd)))
        return
    p = Popen(cmd, shell=False, stdin=PIPE, stdout=PIPE,
              stderr=STDOUT, close_fds=True)
    output = p.communicate()[0]
    logger.info(output)


def retrieve_kerberos_ticket(role_type, service_type):
    role_type = role_type.upper()
    service_type = service_type.lower()
    if kerberized:
        logger.info("Retrieving ticket for role {0}, service {1}".format(
            role_type, service_type))
        execute_script("retrieve_kerberos_ticket.sh",
                       [role_type, service_type])


def execute_cleaning(cluster_name, cluster_version, service_type, role_type, is_leader):
    if role_type == "NAMENODE" and service_type == "HDFS":
        if is_leader:
            retrieve_kerberos_ticket(role_type, service_type)
            logger.info("Host is leader, running {0} {1} cleaning.".format(
                service_type, role_type))
            execute_script("cloudera_cleaner_script.sh", ["--hdfs"])
        else:
            logger.info("Not running {0} {1} cleaning because this host is not the leader.".format(
                service_type, role_type))

    if role_type == "HUE_SERVER" and service_type == "HUE":
        logger.info(
            "Running hue templates compile files cleaning script")
        execute_script("hue_cleaning_script.sh", ["1"])

    if role_type == "HIVEMETASTORE" and service_type == "HIVE":
        if is_leader:
            retrieve_kerberos_ticket(role_type, service_type)
            if StrictVersion(cluster_version) < StrictVersion("5.8.4"):
                logger.info(
                    "Running 'naive' hive cleaning script because CDH version is < 5.8.4")
                execute_script("hive_cleaning_script.sh", ["7"])
            else:
                logger.info("Host is leader, running {0} {1} cleaning.".format(
                    service_type, role_type))
                execute_script("cloudera_cleaner_script.sh", ["--hive"])
        else:
            logger.info("Not running {0} {1} cleaning because this host is not the leader.".format(
                service_type, role_type))
    if role_type == "HIVESERVER2" and service_type == "HIVE":
        if StrictVersion(cluster_version) < StrictVersion("5.12.0"):
            logger.info(
                "Running hiveserver2 cleaning script because CDH version is < 5.12.0")
            execute_script("hs2_cleaning_script.sh", ["1"])
    if (role_type == "GATEWAY" and service_type == "HIVE") or (role_type == "NODEMANAGER" and service_type == "YARN"):
        logger.info(
            "Running hive hadoop-unjar cleaning script")
        execute_script("hive_hadoop_unjar_cleaning.sh", ["7"])
    if (role_type == "GATEWAY" and service_type == "SQOOP_CLIENT") or (role_type == "NODEMANAGER" and service_type == "YARN"):
        # Try to clean sqoop even if there is no sqoop gateway but there is a YARN nodemanager role
        # (the Sqoop gateway seems not to be necessary for worker nodes)
        logger.info("Running {0} {1} cleaning.".format(
            service_type, role_type))
        execute_script("cloudera_cleaner_script.sh", ["--sqoop"])
    if role_type == "CATALOGSERVER" and service_type == "IMPALA":
        if StrictVersion(cluster_version) < StrictVersion("5.9.2"):
            logger.info("Running {0} {1} cleaning.".format(
                service_type, role_type))
            execute_script("impala_cleaning_script.sh", ["60"])
    if role_type == "REGIONSERVER" and service_type == "HBASE":
        logger.info("Running Phoenix {0} {1} cleaning.".format(
            service_type, role_type))
        execute_script("phoenix_cleaning_script.sh", ["3"])


def is_role_leader(service, role_type, role_name):
    """Checks if a certain role instance is the leader for that role type.
    Given the complete list of roles for a particular service, the leader
    for a role type is simply the role instance whose role name is the 
    first alfabetically among all roles with the same role type."""
    logger.debug("Role name: {0}".format(role_name))
    for role in service.get_all_roles():
        if role.type and role.type == role_type and role.name < role_name:
            return False
    return True


def clean_host(cm_api):
    # use getfqdn to get complete hostname, i.e. hostname+domain etc.
    my_hostname = socket.getfqdn()
    logger.debug("My Hostname: {0}".format(my_hostname))
    hosts = cm_api.get_all_hosts(view="full")
    for host in hosts:
        if host.hostname == my_hostname:
            role_refs = host.roleRefs
            for ref in role_refs:
                if hasattr(ref, "clusterName") and ref.clusterName is not None:
                    cluster_name = ref.clusterName
                    cluster = cm_api.get_cluster(cluster_name)
                    cluster_version = cluster.fullVersion
                    service = cluster.get_service(ref.serviceName)
                else:
                    # if there is no cluster name, than we are looking at Cloudera MGMT service
                    cluster_name = None
                    cluster_version = None
                    cm = cm_api.get_cloudera_manager()
                    service = cm.get_service()
                service_type = service.type
                role = service.get_role(ref.roleName)
                role_type = role.type
                is_leader = is_role_leader(service, role_type, ref.roleName)
                execute_cleaning(cluster_name, cluster_version, service_type,
                                 role_type, is_leader)
            break


def main():

    parser = argparse.ArgumentParser(
        description='Script that executes the necessary cleaning operations depending on the host roles. Queries the Cloudera Manager host to retrieve role information.\nCommand line arguments overrides values defined in config.ini')
    # Add arguments
    parser.add_argument(
        '--cm-host', type=str, help='Cloudera Manager host (e.g. "127.0.0.1")', required=False)
    parser.add_argument(
        '--cm-port', type=int, help='Cloudera Manager port', required=False)
    parser.add_argument(
        '--cm-user', type=str, help='Cloudera Manager username (e.g. "admin", although you should not use the admin user but a Read-Only user)', required=False)
    parser.add_argument(
        '--cm-pass', type=str, help='Cloudera Manager user\'s password', required=False)
    parser.add_argument(
        '--kerberized', help='Try to download and use the role keytab before executing actions', action='store_true', default='None')
    parser.add_argument(
        '--debug-mode', help='Prints only the shell scripts without actually running them', action='store_true', default='None')
    parser.add_argument(
        '--log-file', type=str, help='Path for the log file', required=False)
    # Array for all arguments passed to script
    args = parser.parse_args()

    # parse the configuration file
    config = ConfigParser.ConfigParser()
    config.read(os.path.join(script_path, "config.ini"))
    cm_host = config.get("Main", "cm_host")
    cm_port = config.get("Main", "cm_port")
    cm_user = config.get("Main", "cm_user")
    cm_pass = config.get("Main", "cm_pass")
    global kerberized
    kerberized = config.getboolean("Main", "kerberized")

    log_file = None
    maxbytes = 20000000

    # Override config values from commandline arguments
    if args.cm_host is not None:
        cm_host = args.cm_host
    if args.cm_port is not None:
        cm_port = args.cm_port
    if args.cm_user is not None:
        cm_user = args.cm_user
    if args.cm_pass is not None:
        cm_pass = args.cm_pass
    if args.kerberized is not None:
        kerberized = args.kerberized
    if args.log_file is not None:
        log_file = args.log_file

    if log_file is not None:
        handler = RotatingFileHandler(
            args.log_file, maxBytes=maxbytes, backupCount=5)
        logger.addHandler(handler)

    global debug_mode
    debug_mode = args.debug_mode

    api = ApiResource(cm_host, cm_port, cm_user, cm_pass, version=API_VERSION)

    clean_host(api)


if __name__ == "__main__":
    main()
