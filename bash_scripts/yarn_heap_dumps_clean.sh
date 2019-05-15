#!/bin/bash

# default values
DUMPS_LIMIT_DAYS=7
HEAP_DUMP_DIR="/tmp"

TEMPFILE=/tmp/$$.tmp

log() {
	printf "$(date): $1\n"
}

error() {
	log "[ERROR] $1" 1>&2
}

warn() {
	log "[WARN] $1" 1>&2
}

check_if_path_exists() {
    if ls $1 &> /dev/null; then
		echo true
	else
		echo false
	fi
}


clean_heap_dumps() {
	log "Removing heap dumps older than $DUMPS_LIMIT_DAYS days..."
	now=$(date +%s)
	echo 0 > $TEMPFILE
	if cd ${HEAP_DUMP_DIR}; then
	    # Warning! This will try to find heap dumps RECURSIVELY in the child directories
			for file in $(find . -regextype posix-extended -type f -user yarn -group yarn -regex '.*java_pid[0-9]+\.hprof' -mtime +${DUMPS_LIMIT_DAYS}); do 
					echo $file
					rm -r $file
					COUNTER=$(($(cat $TEMPFILE) + 1))
					echo $COUNTER > $TEMPFILE
			done
	fi
	log "Deleted $(cat $TEMPFILE) files."
	unlink $TEMPFILE
	log "Yarn Heap Dump cleaning done"
}

die() {
	printf '%s\n' "$1" >&2
	exit 1
}
# Usage info
show_help() {
	echo "Yarn Heap Dumps cleaning utility"
	echo ""
	echo "    Utility to delete old Heap Dumps that were left on the disk due to failed applications/yarn containers"
	echo "Usage: $0 [--days] [--dir HEAP_DUMP_DIR] [-h] [-v]"
	echo ""
	echo "    -h, --help               display this help and exit"
	echo "    -v                       verbose mode; can be used multiple times for increased"
	echo "                             verbosity"
	echo "    --days DAYS              heap dumps older than DAYS days will be deleted"
	echo "    --dir HEAP_DUMP_DIR  override default heap dump directory (${HEAP_DUMP_DIR})"
}

if [ $# -eq 0 ]; then
	clean_heap_dumps # Start with defaults if no argument is passed
	exit
fi

while :; do
	case $1 in
	--days)
		DUMPS_LIMIT_DAYS="$2"
    shift
		;;
	--dir)
		HEAP_DUMP_DIR="$2"
    shift
		;;
	-h | -\? | --help)
		show_help # Display a usage synopsis.
		exit
		;;
	-v | --verbose)
		verbose=$((verbose + 1)) # Each -v adds 1 to verbosity.
		;;
	--) # End of all options.
		shift
		break
		;;
	-?*)
		printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
		;;
	*) # Default case: No more options, so break out of the loop.
		break
		;;
	esac

	shift
done

clean_heap_dumps

