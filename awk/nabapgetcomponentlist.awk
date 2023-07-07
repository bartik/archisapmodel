#!/usr/bin/awk
BEGIN {
  p = 0
	q = 1
	h[1]="Component"
	h[2]="Release"
  h[3]="Patchlevel"
	h[4]="ComponentType"
	h[5]="Description"
	hostname="localhost"
	if (length(h)>0) {
		hostname=h
	}
	n=0
	if (length(n)>0) {
		instance=n
	}
}

FNR == 3 {
	srand()
	e = srand()
	# print epoch time
	print e
	# print hostname
	print hostname
	print $0 " " instance
	next
}

FNR < 5 {
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
  r=$0
  gsub(/:/,h[q++] ":",r)
	print r
}