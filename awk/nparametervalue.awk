#!/usr/bin/awk
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
/^[[:blank:]]*$/ || ! /\075/ {
	next
}

{
	l = $0
	gsub(/^0[[:blank:]]+:[[:blank:]]+/, "", l)
	q = l
	gsub(/^_+/, "", q)
	k = substr(q, 1, 3)
	t = index(q, "=")
	m = index(q, "_")
	n = index(q, "/")
	if (m < t) {
		if (m > 2) {
			k = substr(q, 1, m)
		}
	}
	if (n < t) {
		if (n > 2) {
			k = substr(q, 1, n)
		}
	}
	if (! idx[k]) {
		idx[k] = i++
	}
	gsub(/\075/, ": ", l)
	printf "%d %s\n", idx[k], l
}

