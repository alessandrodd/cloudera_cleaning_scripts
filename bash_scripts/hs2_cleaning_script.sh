#!/bin/bash

JAVA_IO_TMPDIR_DEFAULT=/tmp
TEMPFILE=/tmp/$$.tmp

log() {
    printf "`date`: $1\n"
}

show_help(){
    echo  "HiveServer2 Resources Cleaner Utility"
    echo  " *****************************************************************************"
    echo  " *****************************************************************************"
    echo  " ** "  
    echo  " ** Warning: this script is meant to be used in CDH < 5.12.0 or Hive < 1.3.0 ."
    echo  " ** For CDH 5.12.0 and above (or Hive 1.3.0 and above) this script should not be needed (see HIVE-11878)."
    echo  " ** "  
    echo  " *****************************************************************************"
    echo  " *****************************************************************************"
    echo  "Usage: $0 [days]" 
    echo  "          Search and deletes all hiveserver2 resources folder older than [days] days."

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
    for directory in $(find . -regextype posix-extended -regex './[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}_resources' -user hive -mtime +$1); do 
        echo $directory
        rm -r $directory
        COUNTER=$(($(cat $TEMPFILE) + 1))
        echo $COUNTER > $TEMPFILE
    done
fi
log "Deleted $(cat $TEMPFILE) files."
unlink $TEMPFILE
