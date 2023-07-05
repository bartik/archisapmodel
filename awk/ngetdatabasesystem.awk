#!/usr/bin/awk
BEGIN {
	FS = ","
	hostname="localhost"
	if (length(h)>0) {
		hostname=h
	}
	c = -1
}

FNR == 3 {
	srand()
	e = srand()
	# print epoch time
	print e
	# print hostname
	print hostname
	print $0
	next
}

FNR < 7 {
	print $0
	next
}

/^\*/ {
	c++
	next
}

/^ / && c > -1 {
	n = $1
	t = $2
	if ($0 ~ /sep=,/) {
		t = t ","
		v = $4
		i = 5
	} else {
		v = $3
		i = 4
	}
	for (j = i; j <= NF; j++) {
		v = v "," $j
	}
	# strip leading and trailing blanks
	n = removeBlanks(n)
	t = removeBlanks(t)
	v = removeBlanks(v)
	# set attributes
  gsub(/[[:blank:]]/, "\\&nbsp;", n)
	if (t ~ /[[:blank:]]+sep=/) {
		# get separator
		w = split(t, u, "=")
		s = "[[:blank:]]"
		if (w > 1) {
			i = index(t, "=")
			s = substr(t, i + 1, 1)
		}
		# split values
		w = split(v, u, s)
		for (j = 1; j <= w; j++) {
			u[j] = removeBlanks(u[j])
			gsub(/[[:blank:]]+$/, "", u[j])
			gsub(/^[[:blank:]]+/, "", u[j])
			if (length(u[j]) > 0) {
        gsub(/[[:blank:]]/, "\\&nbsp;", u[j])
				printf "%s %s_%s: %s\n", c, n, j, u[j]
			}
		}
	} else {
    gsub(/[[:blank:]]/, "\\&nbsp;", v)
		printf "%s %s: %s\n", c, n, v
	}
}


function removeBlanks(l)
{
	gsub(/[[:blank:]]+$/, "", l)
	gsub(/^[[:blank:]]+/, "", l)
	return l
}
