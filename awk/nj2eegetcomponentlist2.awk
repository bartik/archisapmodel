#!/usr/bin/awk
BEGIN {
	FS = ":"
	c = -1
}

FNR == 3 {
	srand()
	e = srand()
	# print epoch time
	print e
	# hostname
	hostname = $1
}

FNR == 4 {
	# command
	command = $1
	# Instance
	instance = $2
}

FNR < 6 {
	print $0
	next
}

##
# @brief Skip Webmethod Call result & Operation ID
#
# Skip the header that is written by the ExecuteOperation
# function of saphostctrl.
#
FNR < 12 {
	next
}

##
# @brief Skip the exit code
#
/^exitcode=[0-9]+$/ {
	next
}

##
# @brief blank lines supressed
#
# blank lines are not copied over to the unified file
# except if they are part of the header.
# AIX awk does not like the pattern match /=/
#
/^[[:blank:]]*$/ {
	if (c >= 0) {
		c++
	}
	next
}

/^Listing the versions of SDAs.EARs/ {
	c++
	next
}

c >= 0 {
	d = "Component"
	if ($1 ~ /^[[:blank:]]/) {
		d = "Archive"
	}
	gsub(/^[[:blank:]]+/, "", $1)
	gsub(/[[:blank:]]+$/, "", $1)
	gsub(/^[[:blank:]]+/, "", $2)
	gsub(/[[:blank:]]+$/, "", $2)
	printf "%d %s: %s %s\n", c, d, $1, $2
}

