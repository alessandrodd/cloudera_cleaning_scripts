#!/bin/bash

TEMPFILE=/tmp/$$.tmp

log() {
    printf "`date`: $1\n"
}

show_help(){
    echo  "Hue Templates Cleaner Utility"
    echo  " *****************************************************************************"
    echo  " *****************************************************************************"
    echo  " ** "  
    echo  " ** This script is meant to solve the problem of Hue temp template files created by Hue Server and never deleted."
    echo  " ** "  
    echo  " *****************************************************************************"
    echo  " *****************************************************************************"
    echo  "Usage: $0 [days]" 
    echo  "          Search and deletes all Hue Templates compile files older than [days] days."

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
    for directory in $(find . -regextype posix-extended -regex './tmp[a-zA-Z]{6}' -user hue -mtime +$1); do 
        echo $directory
        rm -r $directory
        COUNTER=$(($(cat $TEMPFILE) + 1))
        echo $COUNTER > $TEMPFILE
    done
fi
log "Deleted $(cat $TEMPFILE) files."
unlink $TEMPFILE
