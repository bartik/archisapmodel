#!/usr/bin/awk
BEGIN {
	p = 0
	q = 1
	w[1] = "Component"
	w[2] = "Release"
	w[3] = "Patchlevel"
	w[4] = "ComponentType"
	w[5] = "Description"
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

/^[[:blank:]]*$/ {
	next
}

$1 > p {
	q = 1
	p = $1
}

{
	r = $0
	gsub(/:/, w[q++] ":", r)
	print r
}

