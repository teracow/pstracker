#!/bin/bash

# load several processes (up to a limit) then launch new ones as old ones exit.

function InitPSTracker
	{

	child_count=0
	child_limit=4
	process_tracker_file="process.count"

	echo "$child_count" > "${process_tracker_file}"

	}

function IncrementPSTracker
	{

	local count=$(<"${process_tracker_file}")
	((count++))
	echo "$count" > "${process_tracker_file}"

	}

function DecrementPSTracker
	{

	local count=$(<"${process_tracker_file}")
	((count--))
	echo "$count" > "${process_tracker_file}"

	}

function Worker
	{

	IncrementPSTracker

	echo "- <In child process with msg: [$1] - now working on something for 5 seconds ...>"

	# actual work to be done would be placed here
	sleep 5

	DecrementPSTracker

	}

InitPSTracker

while read msg || [[ -n "$msg" ]] ; do
	echo "- Loaded new \$msg: [$msg]"

	while true; do
		echo -n "? Checking child process counter: "
		child_count=$(<"${process_tracker_file}")
		echo "[$child_count]"

		echo -n "? Is counter below limit? "
		[ "$child_count" -lt $child_limit ] && echo "Yes! OK to launch new child process." && break
		echo "No! So, I'm waiting for 0.5 seconds:"
		sleep 0.5
	done

	echo "- Launching new child with \$msg: [$msg]: "
	Worker "$msg" &
	sleep 0.1		# need to allow child process time to spawn and update process counter file
	echo "= Done! msg: [$msg] launched!"
	echo "-------------------------"
done < "messages.txt"
