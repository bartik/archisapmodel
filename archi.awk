#!/usr/bin/awk
# _elements.csv
# "ID","Type","Name","Documentation","Specialization"
# _properties.csv
# "ID","Key","Value"
# _relation.csv
# "ID","Type","Name","Documentation","Source","Target","Specialization"
BEGIN {
	# global object counters
	g_counter_cpu = 0
	g_counter_networkport = 0
	g_counter_eid = -1
	# global variable holding the currently processed object
	g_processing = "Unknown"
	# field separator
	FS = ","
	# config array key for the ID string template
	# the template itself is defined in the ini file
	# [global]
	# prefix=...
	g_key_prefix = "global|prefix"
	g_key_function = "global|function"
	g_key_multiply = "global|multiply"
	g_key_ignore = "global|ignore"
	g_key_fproperties = "global|properties"
	g_key_felements = "global|elements"
	g_key_frelations = "global|relations"
	g_key_merge = "global|merge"
	g_key_format_cim = "format|cim"
	g_key_format_db = "format|db"
	g_key_separator_propertyname = "separator|property_name"
	g_key_separator_namevalue = "separator|name_value"
	g_key_separator_namewords = "separator|name_words"
	g_key_property_documentation = "property|documentation"
	g_key_property_name = "property|name"
	g_key_property_type = "property|type"
	g_key_property_SID = "property|sid"
	g_key_property_DeviceID = "property|deviceid"
	g_key_property_instance_type = "property|instance_type"
	g_key_specialization_default = "specialization|default"
	g_key_sanitize = "sanitize|"
	g_key_splitter = "splitter|"
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
	# reset duplicate check array
	split("", g_duplicate, FS)
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
				key = replaceBlankAll(iniLine[1])
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
	g_config[g_key_prefix] = sprintf("id-%s-", replaceBlankAll($0))
	l_index = 35 - length(g_config[g_key_prefix])
	if (l_index > 0) {
		g_config[g_key_prefix] = sprintf("%s%%0%dd", g_config[g_key_prefix], l_index)
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
		diagArray(DEBUG_LEVEL["INFO"], g_object, "g_object")
		diagMsg(DEBUG_LEVEL["INFO"], "=============================================================")
		split("", g_object, FS)
	}
	g_config[g_key_function] = removeBlankStartAndEnd($0)
	diagMsg(DEBUG_LEVEL["INFO"], sprintf("Function = \"%s\"", g_config[g_key_function]))
	next
}

##
# @brief Skip header
#
FNR < 7 {
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
	diagArray(DEBUG_LEVEL["INFO"], g_object, "g_object")
	# do not reset specific objects
	if (g_counter_eid > -1) {
		diagMsg(DEBUG_LEVEL["INFO"], "=============================================================")
		diagMsg(DEBUG_LEVEL["INFO"], g_processing)
		diagMsg(DEBUG_LEVEL["INFO"], "=============================================================")
		if (g_processing !~ g_config[g_key_merge]) {
			regObject(g_object)
			diagMsg(DEBUG_LEVEL["INFO"], ">>> RESET - g_object - RESET <<<")
			split("", g_object, FS)
		} else {
			diagMsg(DEBUG_LEVEL["INFO"], sprintf("Merging %s/%s with upcoming object.", g_object[g_config[g_key_property_type]], objectName(g_object)))
			diagArray(DEBUG_LEVEL["INFO"], g_object, "g_object")
		}
		diagMsg(DEBUG_LEVEL["INFO"], "=============================================================")
	} else {
		g_counter_eid++
	}
	next
}

g_config[g_key_function] ~ g_config[g_key_format_cim] {
	diagMsg(DEBUG_LEVEL["INFO"], sprintf("(processing) %s", $0))
	# check for separator
	l_propsep = parameterSeparator($0)
	if (length(l_propsep) == 1) {
		$2 = sprintf("String[] sep=%1s", l_propsep)
	}
	# special case when comma is also the properties separator
	if (NF > 3) {
		v = $3
		for (j = 4; j <= NF; j++) {
			v = v "," $j
		}
		gsub(/[[:blank:]]+,/, ",", v)
		gsub(/,[[:blank:]]+/, ",", v)
		$3 = v
	}
	# special case with a omitted delimiter
	for (j in g_config) {
		if (g_key_splitter ~ j) {
			k = substr(j, length(j), 1)
			if ($1 ~ g_config[j]) {
				l_propsep = k
				$2 = sprintf("String[] sep=%1s", l_propsep)
				diagMsg(DEBUG_LEVEL["INFO"], sprintf("(%s/%s) %s --> %s", g_config[j], j, $1, $3))
			}
		}
	}
	# special case with tennat databases
	if ($1 ~ /SystemDB DBCredentials/) {
		$1 = "DBCredentials"
		diagMsg(DEBUG_LEVEL["INFO"], sprintf("(SystemDB DBCredentials) %s --> %s", $1, $3))
	}
	# special case SapVersionInfo
	if ($1 ~ /SapVersionInfo/) {
		v = "version " removeBlankStartAndEnd($3)
		gsub(/[[:blank:]]+/, g_config[g_key_separator_namevalue], v)
		diagMsg(DEBUG_LEVEL["INFO"], sprintf("(SapVersionInfo) %s --> %s", $1, $3))
		$3 = v
	}
	# special case DBCredentials
	if ($1 ~ /DBCredentials/) {
		v = "Name=" removeBlankStartAndEnd($3)
		diagMsg(DEBUG_LEVEL["INFO"], sprintf("(DBCredentials) %s --> %s", $1, $3))
		$3 = v
	}
	# this is the proper case
	$1 = removeBlankStartAndEnd($1)
	$2 = removeBlankStartAndEnd($2)
	$3 = removeBlankStartAndEnd($3)
	if (length(l_propsep) == 1) {
		if ($1 ~ g_config[g_key_multiply]) {
			# create a new object from attribute
			split("", n_object, FS)
			n_object["CreationClassName"] = sprintf("SAP_ITSAM%s", $1)
			n_object["CSCreationClassName"] = g_object["CreationClassName"]
			n_object["CSName"] = g_object["Name"]
			parameterSplit(n_object, "", $3, l_propsep)
			if (length(n_object["Name"]) < 1) {
				n_object["Name"] = objectName(n_object)
			}
			regObject(n_object)
			split("", n_object, FS)
		} else {
			# add as properties only
			parameterSplit(g_object, $1 g_config[g_key_separator_propertyname], $3, l_propsep)
		}
	} else {
		# do not overwrite existing attributes
		if (length(g_object[$1]) < 1) {
			g_object[$1] = $3
			diagMsg(DEBUG_LEVEL["INFO"], sprintf("(adding) %s = %s", $1, $3))
		}
	}
	# every CIM oject muss have a CreationClassName
	if ($1 ~ /CreationClassName/) {
		g_processing = $3
	}
	next
}

END {
	# flush objects 
	if (g_config[g_key_function] ~ g_config[g_key_format_cim]) {
		diagArray(DEBUG_LEVEL["INFO"], g_object, "g_object")
		diagMsg(DEBUG_LEVEL["INFO"], "=== END =====================================================")
		regObject(g_object)
		diagMsg(DEBUG_LEVEL["INFO"], "=== END =====================================================")
		split("", g_object, FS)
	}
	diagArray(DEBUG_LEVEL["INFO"], g_config, "g_config")
}


##
# @brief Count Array LENght
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
function diagArray(tmpLevel, tmpArray, tmpName, tmpFilter, k)
{
	if (length(tmpFilter) == 0) {
		tmpFilter = ".*"
	}
	for (k in tmpArray) {
		if (k ~ tmpFilter) {
			diagMsg(tmpLevel, sprintf("%s[\"%s\"] = %s", tmpName, k, tmpArray[k]))
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
		stdMsg(DEBUG_LEVEL[tmpLevel], tmpMessage "\n")
	}
}

##
# @brief check if key unique
#
function isUnique(tmpObject, s, n, t, k)
{
	t = 1
	s = objectSpecialization(tmpObject)
	n = objectName(tmpObject)
	k = sprintf("%s|%s", s, n)
	if (k in g_duplicate) {
		t = 0
	}
	return t
}

##
# @brief return object id
#
# This function will construct a id for
# the archimate object.
#
function objectID(e)
{
	e = sprintf(g_config[g_key_prefix], g_counter_eid++)
	diagMsg(DEBUG_LEVEL["INFO"], sprintf("eID=%s", e))
	return e
}

##
# @brief return object name
#
# This function will construct a name for
# the archimate object.
#
function objectName(tmpObject, s, n)
{
	s = objectSpecialization(tmpObject)
	n = tmpObject[g_config[g_key_property_name]]
	if (length(n) < 1) {
		# build a name for SAPInstance
		n = "Unknown"
		if (s ~ /SAPInstance/) {
			n = sprintf("SAP %s %s", tmpObject[g_config[g_key_property_SID]], tmpObject[g_config[g_key_property_instance_type]])
		} else if (s ~ /SAP_ITSAMProcessor/) {
			if (length(tmpObject[g_config[g_key_property_DeviceID]]) > 0) {
				n = sprintf("CPU %d", tmpObject[g_config[g_key_property_DeviceID]])
			} else {
				n = sprintf("CPU %d", g_counter_cpu++)
			}
		} else if (s ~ /SAP_ITSAMNetworkPort/) {
			if (length(tmpObject[g_config[g_key_property_DeviceID]]) > 0) {
				n = sprintf("%s", tmpObject[g_config[g_key_property_DeviceID]])
			} else {
				n = sprintf("Network port %d", g_counter_networkport++)
			}
		} else if (s ~ /SAP_ITSAMConnectAddress/) {
			n = sprintf("%s:%s", tmpObject["Host"], tmpObject["Port"])
		}
		# Save the name in the object to print as parameter
		# if it does not exist
		tmpObject[g_config[g_key_property_name]] = n
	} else {
		n = replaceBlankAll(n, g_config[g_key_separator_namewords])
	}
	return n
}

##
# @brief return object specialization
#
# This function will return the CreationClassName
#
function objectSpecialization(tmpObject, s)
{
	s = tmpObject[g_config[g_key_property_type]]
	return s
}

##
# @brief return object type
#
# This function will return the archimate base type
# for the given cim objectClass.
#
function objectType(tmpObject, s, t)
{
	s = objectSpecialization(tmpObject)
	t = g_config["specialization|" s]
	if (length(t) < 1) {
		t = g_config[g_key_specialization_default]
	}
	return t
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
function parameterSplit(tmpObject, tmpAttribute, tmpLine, s, i, j, c, p, v, t, k)
{
	k = 1
	t = tmpAttribute
	c = split(tmpLine, p, s)
	for (j = 1; j <= c; j++) {
		if (length(p[j]) > 0) {
			i = split(p[j], v, g_config[g_key_separator_namevalue])
			if (i > 1) {
				tmpObject[t v[1]] = v[2]
			} else {
				tmpObject[t k++] = p[j]
			}
		}
	}
}

##
# @brief print element entry
#
# _elements.csv
# "ID","Type","Name","Documentation","Specialization"
#
function printELEMENT(eID, eType, eName, eDocumentation, eSpecialization, m)
{
	eName = sanitize(eName)
	eDocumentation = sanitize(eDocumentation)
	eSpecialization = sanitize(eSpecialization)
	m = sprintf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n", eID, eType, eName, eDocumentation, eSpecialization)
	stdMsg(g_config[g_key_felements], m)
}

##
# @brief print object
#
function printObject(tmpObject, e, t, n, d, s, k)
{
	# get the archimate element to which the "CreationClassName" maps (see ini file)
	t = objectType(tmpObject)
	# determine the object name based on woodoo
	n = objectName(tmpObject)
	# determine documentation based on woodoo
	d = tmpObject[g_config[g_key_property_documentation]]
	if (length(d) < 1) {
		d = n
	}
	# specialization
	s = objectSpecialization(tmpObject)
	if (s !~ g_config[g_key_ignore]) {
		# print element
		printELEMENT(e, t, n, d, s)
		# print properties
		for (k in tmpObject) {
			printPROPERTY(e, k, tmpObject[k])
		}
	}
}

##
# @brief print property entry
#
# _properties.csv
# "ID","Key","Value"
#
function printPROPERTY(eID, eKey, eValue, m)
{
	eKey = sanitize(eKey)
	eValue = sanitize(eValue)
	m = sprintf("\"%s\",\"%s\",\"%s\"\n", eID, eKey, eValue)
	stdMsg(g_config[g_key_fproperties], m)
}

##
# @brief print relation entry
#
# _relation.csv
# "ID","Type","Name","Documentation","Source","Target","Specialization"
#
function printRELATION(eID, eType, eName, eDocumentation, eSource, eTarget, eSpecialization, m)
{
	eName = sanitize(eName)
	eDocumentation = sanitize(eDocumentation)
	eSource = sanitize(eSource)
	eTarget = sanitize(eTarget)
	eSpecialization = sanitize(eSpecialization)
	m = sprintf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n", eID, eType, eName, eDocumentation, eSource, eTarget, eSpecialization)
	stdMsg(g_config[g_key_frelations], m)
}

##
# @brief register and print object
#
# It is possible to provide a ID
# as a parameter if the ID has to
# be generated beforehand.
#
function regObject(tmpObject, e, k, s, n)
{
	# check if it is unique
	if (isUnique(tmpObject)) {
		s = objectSpecialization(tmpObject)
		n = objectName(tmpObject)
		# generate object id
		if (length(e) < 1) {
			e = objectID()
		}
		# print the object
		printObject(tmpObject, e)
		# register the object with its id
		k = sprintf("%s|%s", s, n)
		g_duplicate[k] = e
		return 1
	} else {
		# do not register if not unique
		return 0
	}
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
# @brief replace blanks in whole string
#
# If r is not defined blanks will be removed
# If r is defined, consecutive blanks are
# replaced by one r, consecutive r's are 
# replaced by single r.
#
function replaceBlankAll(tmpLine, r)
{
	if (length(r) == 0) {
		gsub(/[[:blank:]]+/, "", tmpLine)
	} else {
		r = substr(r, 1, 1)
		gsub(/[[:blank:]]+/, r, tmpLine)
		gsub("/" r "+/", r, tmpLine)
	}
	return tmpLine
}

##
# @brief sanitize csv strings
#
function sanitize(e, j, k)
{
	for (j in g_config) {
		if (g_key_sanitize ~ j) {
			k = substr(j, length(j), 1)
			gsub(k, g_config[j], e)
		}
	}
	return e
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
