#!/usr/bin/awk
BEGIN {
	hostname = "localhost"
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

$2 ~ /VersionInfo:/ {
	f = 0
	k = "ProductVersion"
	v = ""
	for (j = 3; j < NF; j++) {
		if (($j ~ /,$/ && f == 0) || $j ~ /\),$/) {
			v = v " " $j
			if (f > 0 || k == "") {
				v = k " " v
				k = "SpecialBuildDescription"
			}
			gsub(",", "", v)
			gsub(/^[[:blank:]]+/, "", v)
			gsub(/[[:blank:]]+/, "\\&nbsp;", v)
			print $1 " " k ": " v
			f = 0
			k = ""
			v = ""
		} else if ($j ~ /^\(/) {
			v = v " " $j
			f = 1
		} else if (f > 0) {
			v = v " " $j
		} else {
			k = k $j
		}
	}
	print $1 " Platform: " $NF
	next
}

$2 ~ /Time:/ {
	v = ""
	for (j = 3; j < NF; j++) {
		v = v $j "&nbsp;"
	}
	v = v $NF
	print $1 " " $2 " " v
	next
}

$2 ~ /Filename:/ {
	# Add creation class name
	print $1 " CreationClassName: SAP_ITSAMSAPSoftwarePackage"
	# split filename to extract variables
	s = "\\"
	if ($0 ~ "/") {
		s = "/"
	}
	l = split($3, p, s)
	n = p[l]
	sid = p[4]
	ina = p[5]
	syn = ina
	gsub(/[[:alpha:]]/, "", syn)
	print $1 " Filename: " n
	print $1 " SID: " sid
	print $1 " SystemNumber: " syn
	print $1 " InstanceName: " ina
	# Add creation description
	print $1 " Caption: " $3
	next
}

{
	print $0
}

