#!/bin/bash

# default values
LOG_LIMIT_DAYS=30
CONTAINER_LOG_DIR="/var/yarn/container-logs"

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


clean_container_logs() {
	log "Removing files inside the log directories older than $LOG_LIMIT_DAYS days..."
	now=$(date +%s)
	echo 0 > $TEMPFILE
	if cd ${CONTAINER_LOG_DIR}; then
			for directory in $(find . -regextype posix-extended -type d -regex './application_[0-9]{13}_[0-9]+' -mtime +$1); do 
			    for file in $(find ${directory} -type f -mtime +$1)
						echo $file
						rm -r $file
						COUNTER=$(($(cat $TEMPFILE) + 1))
						echo $COUNTER > $TEMPFILE
					done
			done
			log "find and delete empty dirs"
			find . -type d -mtime +$1 -empty -delete 
	fi
	log "Deleted $(cat $TEMPFILE) files."
	unlink $TEMPFILE
	log "Yarn Container Logs cleaning done"
}

die() {
	printf '%s\n' "$1" >&2
	exit 1
}
# Usage info
show_help() {
	echo "Yarn Container Logs cleaning utility"
	echo ""
	echo "    Utility to delete old YARN container logs that were left on the disk due to failed applications"
	echo "Usage: $0 [--days] [--dir CONTAINER_LOG_DIR] [-h] [-v]"
	echo ""
	echo "    -h, --help               display this help and exit"
	echo "    -v                       verbose mode; can be used multiple times for increased"
	echo "                             verbosity"
	echo "    --days DAYS              container logs older than DAYS days will be deleted"
	echo "    --dir CONTAINER_LOG_DIR  override default container log directory (${CONTAINER_LOG_DIR})"
}

if [ $# -eq 0 ]; then
	clean_container_logs # Start with defaults if no argument is passed
	exit
fi

while :; do
	case $1 in
	--days)
		LOG_LIMIT_DAYS="$2"
    shift
		;;
	--dir)
		CONTAINER_LOG_DIR="$2"
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

clean_container_logs

