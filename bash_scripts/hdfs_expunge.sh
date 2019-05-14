#!/bin/bash

# Initialize all the option variables.
# This ensures we are not contaminated by variables from the environment.
user=""
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


run_expunge() {
	log "expunging trash for user $1"
	HADOOP_HOME_WARN_SUPPRESS=1 HADOOP_ROOT_LOGGER="ERROR" HADOOP_USER_NAME=$1 hdfs dfs -expunge
	if [ "$verbose" -gt "0" ]; then
		log "Return Code: " "$?"
	fi
}

clean_hdfs() {
	log "Emptying HDFS trash..."
	if "$(check_if_command_exists hdfs)"; then
		if [ -z "$user" ]; then
			# we cannot use the following simpler version because the -C argument was added in CDH 5.8 (see HADOOP-10971)
			# for filename in `hdfs dfs -ls -C /user | awk '{print $NF}' | tr '\n' ' '`
			for filename in $(hdfs dfs -ls /user | sed 1d | perl -wlne'print +(split " ",$_,8)[7]' | awk '{print $NF}' | tr '\n' ' '); do
				username=$(basename $filename)
				run_expunge $username
			done
		else
			for username in $(echo $user | sed "s/,/ /g"); do
				run_expunge $username
			done
		fi
	else
		error "hdfs command not found. Skipping trash expunge..."
	fi
	log "HDFS cleaning done"
}

die() {
	printf '%s\n' "$1" >&2
	exit 1
}
# Usage info
show_help() {
	echo "HDFS expunge cleaning utility"
	echo ""
	echo "    Cleans the HDFS trash by executing an hdfs expunge operation"
	echo "    that removes all checkpoints older than fs.trash.interval parameter."
	echo "    fs.trash.interval parameter"
	echo "Usage: $0 [-h] [-v] [--user=USER1,USER2,...]"
	echo ""
	echo "    -h, --help             display this help and exit"
	echo "    -v                     verbose mode; can be used multiple times for increased"
	echo "                           verbosity"
	echo "    --user=USR1,USR2       execute the operation for the specified user[s]. If not"
	echo "                           specified, then it will be executed for all users"
}

if [ $# -eq 0 ]; then
clean_hdfs # Start expunge with defaults if no argument is passed
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

clean_hdfs