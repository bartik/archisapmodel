#!/usr/bin/awk
BEGIN {
	FS = ":"
	c = -1
	k = 0
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
# @brief blank lines supressed
#
# blank lines are not copied over to the unified file
# except if they are part of the header.
# AIX awk does not like the pattern match /=/
#
/^[[:blank:]]*$/ {
	next
}

! /^[[:blank:]]/ {
	flushLine()
	n = "Name"
	v = $1
	v = removeBlanks(v)
	k = 0
	c++
	next
}

/[[:blank:]]+\.[[:blank:]]+:[[:blank:]]*/ {
	flushLine()
	n = $1
	gsub(/\./, "", n)
	n = removeBlanks(n)
	v = $2
	for (j = 3; j <= NF; j++) {
		v = v ":" $j
	}
	v = removeBlanks(v)
	k = 0
	next
}

/^[[:blank:]]+/ {
	k++
	flushLine()
	v = $1
	for (j = 2; j <= NF; j++) {
		v = v ":" $j
	}
	v = removeBlanks(v)
	next
}

END {
	flushLine()
}


function flushLine()
{
	if (c > -1) {
		gsub(/[[:blank:]]/, "\\&nbsp;", v)
		gsub(/[[:blank:]]/, "_", n)
		if (k > 0) {
			printf "%s %s_%d: %s\n", c, n, k, v
		} else {
			printf "%s %s: %s\n", c, n, v
		}
	}
}

function removeBlanks(l)
{
	gsub(/[[:blank:]]+$/, "", l)
	gsub(/^[[:blank:]]+/, "", l)
	return l
}
