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

{
	print $0
}