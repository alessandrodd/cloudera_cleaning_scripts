#!/bin/bash

# Sqoop Cleaning => workaround for SQOOP-3042, fixed in SQOOP 3.0 or CDH 6.1

# Initialize all the option variables.
# This ensures we are not contaminated by variables from the environment.
user=""
verbose=0

# default values
SQOOP_CLEANING_LIMIT_DAYS=1
SQOOP_TMP_DIR="/tmp"

log() {
	printf "$(date): $1\n"
}

error() {
	log "[ERROR] $1" 1>&2
}

warn() {
	log "[WARN] $1" 1>&2
}

check_if_command_exists() {
	if hash "$1" 2>/dev/null; then
		echo true
	else
		echo false
	fi
}

check_if_path_exists() {
    if ls $1 &> /dev/null; then
		echo true
	else
		echo false
	fi
}

run_sqoop_delete() {
	if "$(check_if_path_exists "$SQOOP_TMP_DIR/sqoop-$1")"; then
		echo $(find "$SQOOP_TMP_DIR/sqoop-$1" -type f -mtime +$SQOOP_CLEANING_LIMIT_DAYS -print -delete)
	else
		warn "Sqoop temp directory not found for user $1 (Directory $SQOOP_TMP_DIR/sqoop-$1 not found)"
	fi
}

clean_sqoop() {
	log "Removing Sqoop temp files older than $SQOOP_CLEANING_LIMIT_DAYS days..."
	if [ -z "$user" ]; then
		if "$(check_if_path_exists "$SQOOP_TMP_DIR/sqoop-*")"; then
			for f in $SQOOP_TMP_DIR/sqoop-*; do
                if [[ -d $f ]]; then
				    username=${f#$SQOOP_TMP_DIR/sqoop-}
				    run_sqoop_delete $username
                fi
			done
		else
			warn "Directory $SQOOP_TMP_DIR/sqoop-* not found; does this machine host a Sqoop Gateway?"
		fi
	else
		for username in $(echo $user | sed "s/,/ /g"); do
			run_sqoop_delete $username
		done
	fi
	log "Sqoop cleaning done"
}

die() {
	printf '%s\n' "$1" >&2
	exit 1
}
# Usage info
show_help() {
	echo "Sqoop cleaning utility"
	echo ""
	echo "    Workaround for SQOOP-3042, fixed in SQOOP 3.0 or CDH 6.1"
	echo "    clean sqoop GATEWAY tmp directory, removing all temp files older"
	echo "    than DAYS days (default: $SQOOP_CLEANING_LIMIT_DAYS )"
	echo "Usage: $0 [--days] [--dir SQOOP_TMP_DIR] [-h] [-v] [--user=USER1,USER2,...]"
	echo ""
	echo "    -h, --help             display this help and exit"
	echo "    -v                     verbose mode; can be used multiple times for increased"
	echo "                           verbosity"
	echo "    --days DAYS            temp dirs older than DAYS days will be deleted"
	echo "    --dir SQOOP_TMP_DIR    override default audit log directory (${SQOOP_TMP_DIR})"
	echo "    --user=USR1,USR2       execute the operation for the specified user[s]. If not"
	echo "                           specified, then it will be executed for all users"
}

if [ $# -eq 0 ]; then
	clean_sqoop # Start with defaults if no argument is passed
fi

while :; do
	case $1 in
	--days)
		SQOOP_CLEANING_LIMIT_DAYS="$2"
    shift
		;;
	--dir)
		SQOOP_TMP_DIR="$2"
    shift
		;;
	-h | -\? | --help)
		show_help # Display a usage synopsis.
		exit
		;;
	-v | --verbose)
		verbose=$((verbose + 1)) # Each -v adds 1 to verbosity.
		;;
	--user=?*)
		user=${1#*=} # Delete everything up to "=" and assign the remainder.
		;;
	--user=) # Handle the case of an empty --user=
		die 'ERROR: "--user" requires a non-empty option argument.'
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

clean_sqoop

