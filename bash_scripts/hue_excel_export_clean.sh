#!/bin/bash

TMPDIR_DEFAULT=/tmp
TEMPFILE=/tmp/$$.tmp

log() {
    printf "`date`: $1\n"
}

show_help(){
    echo  "Hue Excel Export Temp Files Cleaner Utility"
    echo  " *****************************************************************************"
    echo  " *****************************************************************************"
    echo  " ** "  
    echo  " ** This script is meant to solve the problem of Hue temp files created when exporting large"
    echo  " ** query results to excel that are never deleted. These files are created by the"  
    echo  " ** NamedTemporaryFile function call in dump_worksheet.py"  
    echo  " ** "  
    echo  " *****************************************************************************"
    echo  " *****************************************************************************"
    echo  "Usage: $0 [days]" 
    echo  "          Search and deletes all Hue Excel Export temp files older than [days] days."

}


if [ ! "$1" ]
then
    show_help
    exit 1
fi
now=$(date +%s)
echo 0 > $TEMPFILE
if cd ${TMPDIR_DEFAULT}; then
    for directory in $(find . -regextype posix-extended -regex './openpyxl\..+' -user hue -mtime +$1); do 
        echo $directory
        rm -r $directory
        COUNTER=$(($(cat $TEMPFILE) + 1))
        echo $COUNTER > $TEMPFILE
    done
fi
log "Deleted $(cat $TEMPFILE) files."
unlink $TEMPFILE
