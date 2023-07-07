#!/usr/bin/awk
BEGIN {
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
	l=$0
	q=l
	gsub(/^_+/,"",q)
	k=substr(q,1,3)
	t=index(q,"=")
	m=index(q,"_")
	n=index(q,"/")
	if (m<t) {
		if (m>2) k=substr(q,1,m)
	}
	if (n<t){
		if (n>2) k=substr(q,1,n)
	}
	if (! idx[k]) {
		idx[k]=i++
	}
	gsub(/\075/,": ",l)
	printf "%d %s\n", idx[k], l
}