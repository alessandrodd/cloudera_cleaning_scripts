#!/bin/bash

# default values
AUDIT_LIMIT_DAYS=90
IMPALAD_AUDIT_LOG_DIR="/var/log/impalad/audit"

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


clean_audit() {
	log "Removing Impala Daemon audit files older than $AUDIT_LIMIT_DAYS days..."
	now=$(date +%s)
	echo 0 > $TEMPFILE
	if cd ${IMPALAD_AUDIT_LOG_DIR}; then
			for file in $(find . -regextype posix-extended -regex './impala_audit_event_log_.+' -mtime +$1); do 
					echo $file
					rm $file
					COUNTER=$(($(cat $TEMPFILE) + 1))
					echo $COUNTER > $TEMPFILE
			done
	fi
	log "Deleted $(cat $TEMPFILE) files."
	unlink $TEMPFILE
	log "Impala Daemon audit cleaning done"
}

die() {
	printf '%s\n' "$1" >&2
	exit 1
}
# Usage info
show_help() {
	echo "Impala Daemon Cleaning utility"
	echo ""
	echo "    Utility to delete old Impalad audit logs, deleting all log files older"
	echo "    than DAYS days (default: $AUDIT_LIMIT_DAYS )"
	echo "Usage: $0 [--days] [--dir AUDIT_LOG_DIR] [-h] [-v]"
	echo ""
	echo "    -h, --help             display this help and exit"
	echo "    -v                     verbose mode; can be used multiple times for increased"
	echo "                           verbosity"
	echo "    --days DAYS            audit logs older than DAYS days will be deleted"
	echo "    --dir AUDIT_LOG_DIR    override default audit log directory (${IMPALAD_AUDIT_LOG_DIR})"
}

if [ $# -eq 0 ]; then
	clean_audit # Start with defaults if no argument is passed
	exit
fi

while :; do
	case $1 in
	--days)
		AUDIT_LIMIT_DAYS="$2"
    shift
		;;
	--dir)
		IMPALAD_AUDIT_LOG_DIR="$2"
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

clean_audit

