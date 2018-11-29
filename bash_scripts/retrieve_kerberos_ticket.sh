#!/bin/bash

BASE_PROCESS_DIR="/var/run/cloudera-scm-agent/process/"

log() {
    printf "`date`: $1\n"
}

show_help(){
    echo  "Cloudera Kerberos Ticket Retrieving Utility"
    echo  " *****************************************************************************"
    echo  " *****************************************************************************"
    echo  " ** "  
    echo  " ** This script is meant to obtain a role's specific Kerberos tickets by "
    echo  " ** retrieving the role's keytab present on the host"
    echo  " ** "  
    echo  " *****************************************************************************"
    echo  " *****************************************************************************"
    echo  "Usage: $0 ROLE_TYPE [SERVICE_TYPE]" 
    echo  "          Get a Kerberos Ticket using the ROLE_TYPE's keytab (e.g. NODEMANAGER keytab)."
    echo  "          You can also specify the SERVICE_TYPE to avoid ambiguity between role types with the same name."

}


if [ ! "$1" ]
then
    echo "ERROR: not enough arguments"
    show_help
    exit 1
fi
now=$(date +%s)
KEYTAB_PATH=""
PRINCIPAL=""
if [ ! "$2" ]
then
    ROLE_PROCESS_DIR=$(ls -td "${BASE_PROCESS_DIR}"*"-${1}" | head -1)
    KEYTAB_PATH=$(ls -t "${ROLE_PROCESS_DIR}/"*".keytab" | head -1)
    FILENAME=$(basename -- "${KEYTAB_PATH}")
    FILENAME="${FILENAME%.*}"
    PRINCIPAL=$(klist -kt "${KEYTAB_PATH}" | awk '{print $NF}' | grep -e "^${FILENAME}/")
else
    ROLE_PROCESS_DIR=$(ls -td "${BASE_PROCESS_DIR}"*"-${2}-${1}" | head -1)
    KEYTAB_PATH=$(ls -t "${ROLE_PROCESS_DIR}/${2}.keytab")
    PRINCIPAL=$(klist -kt "${KEYTAB_PATH}" | awk '{print $NF}' | grep -e "^${2}/")
fi

kinit "${PRINCIPAL}" -kt "${KEYTAB_PATH}"
retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Unexpected return code from kinit; error getting a ticket"
fi
exit $retVal