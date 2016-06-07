#!/bin/bash

# load several processes (up to a limit) then launch new ones as old ones exit.

function InitPSTracker
	{

	child_count=0
	child_limit=8
	process_tracker_file="${temp_path}/child-process.count"

	echo "${child_count}" > "${process_tracker_file}"

	}

function IncrementFile
	{

	# $1 = pathfile containing an integer to increment

	if [ -z "$1" ] ; then
		return 1
	else
		[ -e "$1" ] && count=$(<"$1") || count=0
		((count++))
		echo "$count" > "$1"
	fi

	}

function DecrementFile
	{

	# $1 = pathfile containing an integer to decrement

	if [ -z "$1" ] ; then
		return 1
	else
		[ -e "$1" ] && count=$(<"$1") || count=0
		((count--))
		echo "$count" > "$1"
	fi

	}

function SingleImageDownloader
	{

	# This function runs as a background process
	# $1 = URL to download
	# $2 = current counter relative to main list

	IncrementFile "${process_tracker_file}"

	echo "- starting download of link# [$2] ..."

	# extract file extension by checking only last 5 characters of URL (to handle .jpeg as worst case)
	ext=$( echo ${1:(-5)} | sed "s/.*\(\.[^\.]*\)$/\1/" )

	[[ "$ext" =~ "." ]] || ext=".jpg"	# if URL did not have a file extension then choose jpg as default

	targetimage_pathfileext="${targetimage_pathfile}($2)${ext}"

	wget --max-redirect 0 --timeout=20 --tries=3 --quiet --output-document "$targetimage_pathfileext" "$1"
	result=$?

	if [ $result -eq 0 ] ; then
		echo "= finished download of link# [$2]: success!"
		IncrementFile "${good_downloads_count_file}"
	else
		# increment failures_count but keep trying to download images
		echo "= finished download of link# [$2]: failed!"
		IncrementFile "${bad_downloads_count_file}"

		# delete temp file if one was created
		[ -e "${targetimage_pathfileext}" ] && rm -f "${targetimage_pathfileext}"
	fi

	DecrementFile "${process_tracker_file}"

	}

link_count=0
max_images=40
bad_count=0
pids=""
user_query="staci silverstone"
image_file="google-image"
current_path="$PWD"
temp_path="/dev/shm"
target_path="${current_path}/${user_query}"
targetimage_pathfile="${target_path}/${image_file}"
good_downloads_count_file="${temp_path}/successful-downloads.count"
bad_downloads_count_file="${temp_path}/failed-downloads.count"
countdown=$max_images		# control how many files are downloaded. Counts down to zero.

[ -e "${good_downloads_count_file}" ] && rm -f "${good_downloads_count_file}"
[ -e "${bad_downloads_count_file}" ] && rm -f "${bad_downloads_count_file}"

InitPSTracker

mkdir -p "${target_path}"

while read msg || [[ -n "$msg" ]] ; do
	while true; do
		child_count=$(<"${process_tracker_file}")

		[ "$child_count" -lt "$child_limit" ] && break

		sleep 0.5
	done

	if [ "$countdown" -gt 0 ] ; then
		((link_count++))

		SingleImageDownloader "$msg" "$link_count" &
		pids[${link_count}]=$!		# record PID for checking later
		((countdown--))
		sleep 0.1			# allow new child process time to spawn and update process counter file
	else
		# wait here while all current downloads finish
		for pid in ${pids[*]}; do
			wait $pid
		done

		# how many were successful?
		[ -e "${good_downloads_count_file}" ] && good_count=$(<"${good_downloads_count_file}") || good_count=0

		if [ "$good_count" -lt "$max_images" ] ; then
			# not enough yet, so go get some more
			# increase countdown again to get remaining files
			countdown=$(($max_images-$good_count))
		else
			echo " *********** requested number of files have been downloaded! ****************"
			break
		fi
	fi

done < "googliser-links.list"

[ -e "${good_downloads_count_file}" ] && good_count=$(<"${good_downloads_count_file}") || good_count=0
[ -e "${bad_downloads_count_file}" ] && bad_count=$(<"${bad_downloads_count_file}") || bad_count=0

echo "all done!"
echo "$good_count images were downloaded OK with $bad_count failure."
