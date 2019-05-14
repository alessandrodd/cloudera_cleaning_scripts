#!/bin/bash

JAVA_IO_TMPDIR_DEFAULT=/tmp
TEMPFILE=/tmp/$$.tmp

log() {
    printf "`date`: $1\n"
}

show_help(){
    echo  "Hadoop Unjar Cleaner Utility"
    echo  " *****************************************************************************"
    echo  " *****************************************************************************"
    echo  " ** "  
    echo  " ** This script is meant to solve the problem of orphan unjar folders caused by failed MapredLocalTask"
    echo  " ** See https://my.cloudera.com/knowledge/Hive-Client-System--Temporary-quotunjarredquot-Files-Remain?id=70157"
    echo  " ** "  
    echo  " *****************************************************************************"
    echo  " *****************************************************************************"
    echo  "Usage: $0 [days]" 
    echo  "          Search and deletes all hadoop-unjar folder older than [days] days."

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
    for directory in $(find . -regextype posix-extended -regex './hadoop-unjar[0-9]+' -mtime +$1); do 
        echo $directory
        # dirty check if foder is in use
        if [[ $(lsof $directory) ]]; then
            echo "some file here is currently in use"
        else
            rm -r $directory
            COUNTER=$(($(cat $TEMPFILE) + 1))
            echo $COUNTER > $TEMPFILE
        fi
    done
fi
log "Deleted $(cat $TEMPFILE) files."
unlink $TEMPFILE
