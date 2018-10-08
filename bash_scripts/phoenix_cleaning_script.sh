#!/bin/bash

# See https://issues.apache.org/jira/browse/PHOENIX-4910 and https://issues.apache.org/jira/browse/PHOENIX-2850 
# on why this is necessary 

JAVA_IO_TMPDIR_DEFAULT=/tmp
TEMPFILE=/tmp/$$.tmp

log() {
    printf "`date`: $1\n"
}

show_help(){
    echo  "Apache Phoenix Cleaner Utility"
    echo  " *****************************************************************************"
    echo  " *****************************************************************************"
    echo  "Usage: $0 [days]" 
    echo  "          Search and deletes Apache Phoenix temp files older than [days] days."
    echo  "          See PHOENIX-4910 and PHOENIX-2850 to understand why is this necessary."    
    echo  "                                                                           "  
    echo  "          Temp directory is defined by _JAVA_OPTIONS environment variable,"  
    echo  "          e.g. export _JAVA_OPTIONS=\"\$_JAVA_OPTIONS -Djava.io.tmpdir=/tmp\""
    echo  "          (default /tmp)                                                     "  

}


if [ ! "$1" ]
then
    show_help
    exit 1
fi
now=$(date +%s)
echo 0 > $TEMPFILE
# check if we are using a global custom java.io.tmpdir dir
JAVA_IO_TMPDIR="$(echo $_JAVA_OPTIONS | grep -Po 'java.io.tmpdir=\K[^ ]+' | tail -1)"
if [[ -z "${JAVA_IO_TMPDIR// }" ]]; then
    JAVA_IO_TMPDIR=$JAVA_IO_TMPDIR_DEFAULT
fi
if cd ${JAVA_IO_TMPDIR}; then
    for file in $(find . -regextype posix-extended -regex './[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{31}\.tmp' -user hbase -mmin +$1); do 
        echo $file
        rm $file
        COUNTER=$(($(cat $TEMPFILE) + 1))
        echo $COUNTER > $TEMPFILE
    done
fi
log "Deleted $(cat $TEMPFILE) files."
unlink $TEMPFILE
