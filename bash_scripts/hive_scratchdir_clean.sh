#!/bin/bash

# Initialize all the option variables.
# This ensures we are not contaminated by variables from the environment.
verbose=0

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

run_cleardanglingscratchdir() {
	log "cleaning Hive dangling scratch directory"
	HADOOP_USER_NAME=hdfs hive --service cleardanglingscratchdir
	if [ "$verbose" -gt "0" ]; then
		log "Return Code: " "$?"
	fi
}

clean_hive() {
	if "$(check_if_command_exists hive)"; then
		run_cleardanglingscratchdir
	else
		error "hive command not found. Skipping..."
	fi
	log "Hive cleaning done"
}

die() {
	printf '%s\n' "$1" >&2
	exit 1
}
# Usage info
show_help() {
	echo "Hive Dangling Scratch Dir cleaning utility"
	echo ""
	echo "    Cleans Hive scratch directory; removes dangling temp files"
	echo "    warning: hive.scratchdir.lock should be set to true to"
	echo "    avoid corrupting running jobs"
	echo "Usage: $0 [-h] [-v]"
	echo ""
	echo "    -h, --help             display this help and exit"
	echo "    -v                     verbose mode; can be used multiple times for increased"
	echo "                           verbosity"
}

if [ $# -eq 0 ]; then
	clean_hive # Start with defaults if no argument is passed
	exit
fi

while :; do
	case $1 in
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

clean_hive
