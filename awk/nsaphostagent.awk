#!/usr/bin/awk
BEGIN {
	FS = ","
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

/^\*/ {
	c++
	next
}

/^[[:blank:]]+/ && c > -1 {
	n = $1
	t = $2
	if ($0 ~ /sep=,/) {
		t = t ","
		v = removeBlanks($4)
		i = 5
	} else {
		v = removeBlanks($3)
		i = 4
	}
	for (j = i; j <= NF; j++) {
		v = v "," removeBlanks($j)
	}
	# special handling for some attributes
	if (n ~ /Version/) {
		t = "String[] sep=,"
		v = "kernel=" removeBlanks(v)
		gsub(/[[:blank:]]+PL/, ",patch=", v)
		gsub(/[[:blank:]]+\[compile[[:blank:]]+time:[[:blank:]]+/, ",compiletime=", v)
		gsub(/\][[:blank:]]+\[CL[[:blank:]]+/, ",changelist=", v)
		gsub(/\]$/, "", v)
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
				if (u[j] ~ /=/) {
					split(u[j], z, "=")
					gsub(/[[:blank:]]/, "\\&nbsp;", z[2])
					printf "%s %s_%s: %s\n", c, n, z[1], z[2]
				} else {
					gsub(/[[:blank:]]/, "\\&nbsp;", u[j])
					printf "%s %s_%s: %s\n", c, n, j, u[j]
				}
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
