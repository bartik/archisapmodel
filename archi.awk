#!/usr/bin/awk
# _elements.csv
# "ID","Type","Name","Documentation","Specialization"
# _properties.csv
# "ID","Key","Value"
# _relation.csv
# "ID","Type","Name","Documentation","Source","Target","Specialization"
BEGIN {
	# field separator
	FS = ","
	# config array key for the ID string template
	# the template itself is defined in the ini file
	# [global]
	# prefix=...
	g_key_prefix = "global|prefix"
	g_key_function = "global|function"
	g_key_format_cim = "global|format_cim"
	g_key_format_db = "global|format_db"
	g_key_separator_propertyname = "global|separator_property_name"
	g_key_separator_namevalue = "global|separator_name_value"
	# Diagnostic levels level2string
	DEBUG_LEVEL[1] = "CRIT"
	DEBUG_LEVEL[2] = "WARN"
	DEBUG_LEVEL[3] = "INFO"
	DEBUG_LEVEL[4] = "DEBUG"
	# Maximum diagnostic level
	DEBUG_MAXLVL = alen(DEBUG_LEVEL)
	# add the reverse string2level
	DEBUG_LEVEL["CRIT"] = 1
	DEBUG_LEVEL["WARN"] = 2
	DEBUG_LEVEL["INFO"] = 3
	DEBUG_LEVEL["DEBUG"] = 4
	# Default level
	ARCHI_DEBUG = 0
	# Adjust level from command line with
	# awk -vDEBUG=[01234] ...
	if (DEBUG > 0) {
		ARCHI_DEBUG = DEBUG
	}
	# reset configuration array
	split("", g_config, FS)
	# reset object array
	split("", g_object, FS)
}

##
# @brief Parse configuration
#
# The first file supplied on awk command line must be the ini/configuration
# file. FNR==NR is true for the first file. Store the configuration in the
# config[] array. Empty spaces in the key are deleted. Trailing spaces are 
# removed. Empty lines and lines which begin with # (after trimmed as stated
# before) are not stored in the config[] array. It works only with $0 so the
# the separator FS does not matter.
#
FNR == NR {
	if ($0 !~ /^[[:blank:]]*#/) {
		tmpLine = removeBlankStartAndEnd($0)
		if (length(tmpLine) > 1) {
			len = split(tmpLine, iniLine, "=")
			if (iniLine[1] ~ /^[[:blank:]]*\[/) {
				section = removeBlankStartAndEnd(iniLine[1])
				gsub("^.*\\[", "", section)
				gsub("\\].*$", "", section)
			} else {
				key = removeBlankAll(iniLine[1])
				val = iniLine[2]
				for (j = 3; j <= len; j++) {
					val = val "=" iniLine[j]
				}
				g_config[section "|" key] = val
			}
		}
	}
	next
}

##
# @brief File creation epoch
#
# The 3 line in every processed file except the first (see FNR=NR)
# contains the time of creation in epoch format. This string is 
# used as part of the identifier for the created archimate objects
# 
FNR == 3 {
	diagMsg(DEBUG_LEVEL["INFO"], sprintf("Prefix raw = \"%s\"", $0))
	config[g_key_prefix] = sprintf("id-%s-", removeBlankAll($0))
	l_index = 35 - length(config[g_key_prefix])
	if (l_index > 0) {
		g_config[g_key_prefix] = sprintf("%s%%0%dd", config[g_key_prefix], l_index)
		diagMsg(DEBUG_LEVEL["INFO"], sprintf("Prefix = \"%s\"", g_config[g_key_prefix]))
	}
	next
}

##
# @brief function name
#
# The 5 line in every processed file except the first (see FNR=NR)
# contains the saphostctrl or sapcontrol function name to get the
# data in the file.
# 
FNR == 5 {
	diagMsg(DEBUG_LEVEL["INFO"], sprintf("Function raw = \"%s\"", $0))
	# print the last entry from previous file
	if (g_config[g_key_function] ~ g_config[g_key_format_cim]) {
		diagArray(g_object, "g_object")
		diagMsg(DEBUG_LEVEL["INFO"], "=============================================================")
		split("", g_object, FS)
	}
	g_config[g_key_function] = removeBlankStartAndEnd($0)
	diagMsg(DEBUG_LEVEL["INFO"], sprintf("Function = \"%s\"", g_config[g_key_function]))
	next
}

##
# @brief Process CIM formatted output
#
# *********************************************************
# CreationClassName , String , SAPInstance 
# SID , String , ABC 
# SystemNumber , String , 00 
# InstanceName , String , ASCS00 
# InstanceType , String , Central Services Instance 
# Hostname , String , testserver 
# FullQualifiedHostname , String , TESTSERVER 
# IPAddress , String , 10.20.30.40 
# Features , String[] sep=| , MESSAGESERVER|ENQUE 
# SapVersionInfo , String , 123, patch 456, changelist 7890123
# 
/^\*/ && g_config[g_key_function] ~ g_config[g_key_format_cim] {
	diagArray(g_object, "g_object")
	diagMsg(DEBUG_LEVEL["INFO"], "=============================================================")
	split("", g_object, FS)
	next
}

g_config[g_key_function] ~ g_config[g_key_format_cim] {
	# check for separator
	l_propsep = parameterSeparator($0)
	# special case when the separator is a comman
	if (l_propsep ~ /^,$/) {
	}
	# this is the proper case
	if (NF == 3) {
		$1 = removeBlankStartAndEnd($1)
		$2 = removeBlankStartAndEnd($2)
		$3 = removeBlankStartAndEnd($3)
		if (length(l_propsep) == 1) {
			parameterSplit($1, $3, l_propsep)
		} else {
			g_object[$1] = $3
		}
	}
}

END {
	# flush objects 
	if (g_config[g_key_function] ~ g_config[g_key_format_cim]) {
		diagArray(g_object, "g_object")
		diagMsg(DEBUG_LEVEL["INFO"], "=============================================================")
		split("", g_object, FS)
	}
	# diagArray(g_config,"g_config")
}


##
# @brief Count Array LENghth
#
function alen(a, i, k)
{
	k = 0
	for (i in a) {
		k++
	}
	return k
}

##
# @brief Print array content to INFO
#
# It is possible to specify a pattern for the array
# key to filter output. If nothing specified the
# whole array content will be printed.
#
function diagArray(tmpArray, tmpName, tmpFilter, k)
{
	if (length(tmpFilter) == 0) {
		tmpFilter = ".*"
	}
	for (k in tmpArray) {
		if (k ~ tmpFilter) {
			diagMsg(DEBUG_LEVEL["INFO"], sprintf("%s[\"%s\"] = %s", tmpName, k, tmpArray[k]))
		}
	}
}

##
# @brief Print DIAGnostic MeSaGge
#
function diagMsg(tmpLevel, tmpMessage)
{
	if (tmpLevel < 1) {
		return
	}
	if (tmpLevel > DEBUG_MAXLVL) {
		tmpLevel = DEBUG_MAXLVL
	}
	if (tmpLevel <= ARCHI_DEBUG) {
		printf "ARCHI %s: %s\n", DEBUG_LEVEL[tmpLevel], tmpMessage
	}
}

##
# @brief return separator
#
# $0 ~ / sep=(.)/
# separator = $1
#
function parameterSeparator(tmpLine, i, s)
{
	s = "There is no separator found here."
	if (tmpLine ~ / sep=./) {
		# find the separator
		i = index(tmpLine, "=")
		s = substr(tmpLine, i + 1, 1)
	}
	return s
}

##
# @brief parameterSplit
#
# This function will split the supplied string
#
# Example 1:
# Line(withoud quotes):
#			" Features , String[] sep=| , MESSAGESERVER|ENQUE "
# Parameters:
#			tmpAttribute - the prefix of the property = Features
#			tmpLine - values to split = MESSAGESERVER|ENQUE
#			s - separator = |
#			the rest are local variables.
# Result:
#			Is written into the g_object array
#			g_object["Feature_1"] = MESSAGESERVER
#			g_object["Feature_2"] = ENQUE
#
# Example 2:
# Line(withoud quotes):
#			" SapVersionInfo , String , 123, patch 456, changelist 7890123 "
#			This line has to augumented to be usable with this function
#			" SapVersionInfo , String sep=; , version=123;patch=456;changelist=7890123 "
# Parameters:
#			tmpAttribute - the prefix of the property = SapVersionInfo
#			tmpLine - values to split = version=123;patch=456;changelist=7890123
#			s - separator = ;
#			the rest are local variables. The name/value separator is fixed in the
#			ini file otherwise there would need to be several separators defined by
#			sep=
# Result:
#			Is written into the g_object array
#			g_object["Feature_1"] = MESSAGESERVER
#			g_object["Feature_2"] = ENQUE
#
function parameterSplit(tmpAttribute, tmpLine, s, i, j, c, p, v, t)
{
	t = tmpAttribute g_config[g_key_separator_propertyname]
	c = split(tmpLine, p, s)
	for (j = 1; j <= c; j++) {
		if (length(p[j]) > 0) {
			i = split(p[j], v, g_config[g_key_separator_namevalue])
			if (i > 1) {
				g_object[t v[1]] = v[2]
			} else {
				g_object[t j] = p[j]
			}
		}
	}
}

##
# @brief remove blanks in whole string
#
function removeBlankAll(tmpLine)
{
	gsub(/[[:blank:]]+/, "", tmpLine)
	return tmpLine
}

##
# @brief remove blanks at end
#
function removeBlankEnd(tmpLine)
{
	gsub(/[[:blank:]]+$/, "", tmpLine)
	return tmpLine
}

##
# @brief remove blanks at start
#
function removeBlankStart(tmpLine)
{
	gsub(/^[[:blank:]]+/, "", tmpLine)
	return tmpLine
}

##
# @brief remove blanks at start & end
#
function removeBlankStartAndEnd(tmpLine)
{
	tmpLine = removeBlankStart(tmpLine)
	tmpLine = removeBlankEnd(tmpLine)
	return tmpLine
}

##
# @brief Print STanDard MeSaGge
#
# A central location to do all standard
# output.
#
function stdMsg(tmpFile, tmpMessage)
{
	printf "ARCHI %s: %s", tmpFile, tmpMessage
}
