#!/usr/bin/awk
# /usr/sap/hostctrl/exe/saphostctrl -function GetCIMObject -enuminstances SAPInstance
# /usr/sap/hostctrl/exe/saphostctrl -function ListDatabaseSystems
# /usr/sap/hostctrl/exe/saphostctrl -function GetCIMObject -enuminstances SAP_ITSAMDatabaseSystem
# _elements.csv
# "ID","Type","Name","Documentation","Specialization"
# _properties.csv
# "ID","Key","Value"
# _relation.csv
# "ID","Type","Name","Documentation","Source","Target","Specialization"
BEGIN {
	# global object counters
	COUNTER_cpu = 0
	COUNTER_networkport = 0
	COUNTER_eid = -1
	# global variable holding the currently processed object
	PROCESSING = "Unknown"
	# field separator
	FS = ","
	# config array key for the ID string template
	# the template itself is defined in the ini file
	# [global]
	# prefix=...
	KEY_global_prefix = "global|prefix"
	# general purpose definitions
	KEY_global_function = "global|function"
	KEY_global_multiply = "global|multiply"
	KEY_global_ignore = "global|ignore"
	KEY_global_fproperties = "global|properties"
	KEY_global_felements = "global|elements"
	KEY_global_frelations = "global|relations"
	KEY_global_merge = "global|merge"
	# format definition
	KEY_format_cim = "format|cim"
	KEY_format_db = "format|db"
	# characters used to separates items in lists
	KEY_separator_propertyname = "separator|property_name"
	KEY_separator_namevalue = "separator|name_value"
	KEY_separator_namewords = "separator|name_words"
	KEY_separator_listitems = "separator|list_items"
	# maps cim attributes to archi properties
	KEY_property_documentation = "property|documentation"
	KEY_property_name = "property|name"
	KEY_property_type = "property|type"
	KEY_property_SID = "property|sid"
	KEY_property_DeviceID = "property|deviceid"
	KEY_property_instance_type = "property|instance_type"
	KEY_property_altName = "property|altname"
	KEY_property_parent = "property|parentid"
	# mapping CreationClassName to Archimate
	KEY_specialization = "specialization|"
	KEY_specialization_default = "specialization|default"
	# mapping of realtionships
	KEY_relation = "relation|"
	# cleanup string before writing to file
	KEY_sanitize = "sanitize|"
	# define cim attributes to split into separate objects
	KEY_splitter = "splitter|"
	# Debug levels
	D_DBUG = 4
	D_INFO = 3
	D_WARN = 2
	D_CRIT = 1
	# Diagnostic levels level2string
	DEBUG_LEVEL[D_CRIT] = "CRIT"
	DEBUG_LEVEL[D_WARN] = "WARN"
	DEBUG_LEVEL[D_INFO] = "INFO"
	DEBUG_LEVEL[D_DBUG] = "DEBUG"
	# Maximum diagnostic level
	DEBUG_MAXLVL = alen(DEBUG_LEVEL)
	# add the reverse string2level
	DEBUG_LEVEL["CRIT"] = D_CRIT
	DEBUG_LEVEL["WARN"] = D_WARN
	DEBUG_LEVEL["INFO"] = D_INFO
	DEBUG_LEVEL["DEBUG"] = D_DBUG
	# Default level
	ARCHI_DEBUG = 0
	# Adjust level from command line with
	# awk -vDEBUG=[01234] ...
	if (DEBUG > 0) {
		ARCHI_DEBUG = DEBUG
	}
	# Define relationship direction
	DIRECTION[0]="FROM"
	DIRECTION[1]="TO"
	# reset configuration array
	split("", CONFIG, FS)
	# reset object array
	split("", OBJECT, FS)
	# reset duplicate check array
	split("", DUPLICATE, FS)
	# reset printed objects
	split("", PRINTED, FS)

	diagMsg(D_DBUG,"PROGRAM START")
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
				CONFIG[section "|" key] = val
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
	diagMsg(D_INFO, sprintf("Prefix raw = \"%s\"", $0))
	CONFIG[KEY_global_prefix] = sprintf("id-%s-", replaceBlankAll($0))
	l_index = 35 - length(CONFIG[KEY_global_prefix])
	if (l_index > 0) {
		CONFIG[KEY_global_prefix] = sprintf("%s%%0%dd", CONFIG[KEY_global_prefix], l_index)
		diagMsg(D_INFO, sprintf("Prefix = \"%s\"", CONFIG[KEY_global_prefix]))
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
	diagMsg(D_INFO, sprintf("Function raw = \"%s\"", $0))
	CONFIG[KEY_global_function] = removeBlankStartAndEnd($0)
	diagMsg(D_INFO, sprintf("Function = \"%s\"", CONFIG[KEY_global_function]))
	# initialize file local variables
	l_previous_type = "N/A"
	l_previous_name = "N/A"
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
/^\*/ && CONFIG[KEY_global_function] ~ CONFIG[KEY_format_cim] {
	diagArray(D_INFO, OBJECT, "OBJECT")
	if (COUNTER_eid > -1) {
		diagMsg(D_INFO, "=============================================================")
		diagMsg(D_INFO, sprintf("Processing class: %s", PROCESSING))
		diagMsg(D_INFO, "=============================================================")
		# do not reset specific objects
		if (PROCESSING !~ CONFIG[KEY_global_merge]) {
			# save object to output
			regObject(OBJECT)
			# save the name of the object if its type is different
			# from it's predecessors type.
			diagMsg(D_INFO, sprintf("before Previous type: %s", l_previous_type))
			diagMsg(D_INFO, sprintf("before Now type: %s", getObjectType(OBJECT)))
			diagMsg(D_INFO, sprintf("before Previous name: %s", l_previous_name))
			if (l_previous_name == getObjectName(OBJECT)) {
				l_previous_name = getObjectProperty(OBJECT, KEY_prevname)
			} else {
				l_previous_name = getObjectName(OBJECT)
			}
			l_previous_type = getObjectType(OBJECT)
			diagMsg(D_INFO, sprintf("after Previous type: %s", l_previous_type))
			diagMsg(D_INFO, sprintf("after Now type: %s", getObjectType(OBJECT)))
			diagMsg(D_INFO, sprintf("after Previous name: %s", l_previous_name))
			diagMsg(D_INFO, ">>> RESET - OBJECT - RESET <<<")
			# reset the object
			split("", OBJECT, FS)
			# restore the saved name of the previous object
			setObjectProperty(OBJECT, KEY_prevname, l_previous_name)
		} else {
			diagMsg(D_INFO, sprintf("Merging %s/%s with upcoming object.", getObjectProperty(OBJECT, KEY_property_type), getObjectName(OBJECT)))
			diagArray(D_INFO, OBJECT, "OBJECT")
		}
		diagMsg(D_INFO, "=============================================================")
	} else {
		COUNTER_eid++
	}
	next
}

! /^[[:blank:]]*$/ && CONFIG[KEY_global_function] ~ CONFIG[KEY_format_cim] {
	diagMsg(D_INFO, sprintf("(processing) %s", $0))
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
	for (j in CONFIG) {
		if (KEY_splitter ~ j) {
			k = substr(j, length(j), 1)
			if ($1 ~ CONFIG[j]) {
				l_propsep = k
				$2 = sprintf("String[] sep=%1s", l_propsep)
				diagMsg(D_INFO, sprintf("(%s/%s) %s --> %s", CONFIG[j], j, $1, $3))
			}
		}
	}
	# special case with tennat databases
	if ($1 ~ /SystemDB DBCredentials/) {
		$1 = "DBCredentials"
		diagMsg(D_INFO, sprintf("(SystemDB DBCredentials) %s --> %s", $1, $3))
	}
	# special case SapVersionInfo
	if ($1 ~ /SapVersionInfo/) {
		v = "version " removeBlankStartAndEnd($3)
		gsub(/[[:blank:]]+/, CONFIG[KEY_separator_namevalue], v)
		diagMsg(D_INFO, sprintf("(SapVersionInfo) %s --> %s", $1, $3))
		$3 = v
	}
	# special case DBCredentials
	if ($1 ~ /DBCredentials/) {
		v = "Name=" removeBlankStartAndEnd($3)
		gsub(/Osuser=/,"",v)
		diagMsg(D_INFO, sprintf("(DBCredentials) %s --> %s", $1, $3))
		$3 = v
	}
	# this is the proper case
	$1 = removeBlankStartAndEnd($1)
	$2 = removeBlankStartAndEnd($2)
	$3 = removeBlankStartAndEnd($3)
	if (length(l_propsep) == 1) {
		if ($1 ~ CONFIG[KEY_global_multiply]) {
			# specialization
			l_parent_type = getObjectSpecialization(OBJECT)
			# check if the object should be skipped
			if (l_parent_type !~ CONFIG[KEY_global_ignore]) {
				# create a new object from attribute
				split("", n_object, FS)
				l_parent_id = getObjectID(OBJECT)
				setObjectProperty(n_object, KEY_property_parent, l_parent_id)
				setObjectProperty(n_object, KEY_property_type, sprintf("SAP_ITSAM%s", $1))
				setObjectPropertyRaw(n_object, "CSCreationClassName", getObjectProperty(OBJECT, KEY_property_type))
				setObjectPropertyRaw(n_object, "CSName", getObjectName(OBJECT))
				parameterSplit(n_object, "", $3, l_propsep)
				diagArray(D_INFO, n_object, "n_object")
				regObject(n_object)
				split("", n_object, FS)
			}
		} else {
			# add as properties only
			parameterSplit(OBJECT, $1 CONFIG[KEY_separator_propertyname], $3, l_propsep)
		}
	} else {
		# do not overwrite existing attributes
		if (length(OBJECT[$1]) < 1) {
			OBJECT[$1] = $3
			diagMsg(D_INFO, sprintf("(adding) %s = %s", $1, $3))
		}
	}
	# every CIM oject must have a CreationClassName
	if ($1 ~ /CreationClassName/) {
		PROCESSING = $3
	}
	next
}

END {
	# flush objects 
	if (CONFIG[KEY_global_function] ~ CONFIG[KEY_format_cim]) {
		diagArray(D_INFO, OBJECT, "OBJECT")
		diagMsg(D_INFO, "=== END =====================================================")
		regObject(OBJECT)
		diagMsg(D_INFO, "=== END =====================================================")
		split("", OBJECT, FS)
	}
	diagArray(D_INFO, CONFIG, "CONFIG")
	diagArray(D_INFO, DUPLICATE, "DUPLICATE")
	diagMsg(D_DBUG,"PROGRAM END")
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
# @brief return object attribute
#
# return one of alternative object names
#
function getObjectAltName(tmpObject, r)
{
	r = getObjectAttribute(tmpObject, CONFIG[KEY_property_altName], CONFIG[KEY_separator_listitems])
	return r
}

##
# @brief return object attribute
#
# Go throug the supplied list of
# attributes and return the
# value of array with that
# attribute as key if found.
# Returns only the value for first
# key match from list.
#
function getObjectAttribute(tmpObject, tmpList, s, k, j, l, r)
{
	r = "Unknown"
	l = split(tmpList, k, s)
	diagMsg(D_INFO, sprintf("List length=%d", l))
	diagMsg(D_INFO, sprintf("List=%s", tmpList))
	diagArray(D_INFO, k, "altName")
	diagArray(D_INFO, tmpObject, "tmpObject")
	for (j = 1; j <= l; j++) {
		diagMsg(D_INFO, sprintf("Attribute[%d]=%s", j, k[j]))
		if (k[j] in tmpObject) {
			r = tmpObject[k[j]]
			diagMsg(D_INFO, sprintf("%s=%s", k[j], r))
			return r
		}
	}
	return r
}

##
# @brief try to find object id
#
#
function getObjectID(tmpObject, k, e, s, n)
{
	if ( length(k) < 1 ) {
		s = getObjectSpecialization(tmpObject)
		n = getObjectName(tmpObject)
		k = sprintf("%s|%s", s, n)
	}
	if (isUnique("", k) == 0) {
		e = DUPLICATE[k]
	} else {
		e = newObjectID()
		DUPLICATE[k] = e
	}
	return e
}

##
# @brief return object name
#
# This function will construct a name for
# the archimate object.
#
function getObjectName(tmpObject, s, n)
{
	s = getObjectSpecialization(tmpObject)
	# determine if the object already has a name
	n = getObjectProperty(tmpObject, KEY_property_name)
	if (length(n) < 1) {
		# Try for alternative names
		n = getObjectAltName(tmpObject)
		if (s ~ /SAPInstance/) {
			n = sprintf("%s %s", tmpObject[CONFIG[KEY_property_SID]], tmpObject[CONFIG[KEY_property_instance_type]])
		} else if (s ~ /SAP_ITSAMProcessor/) {
			if (length(tmpObject[CONFIG[KEY_property_DeviceID]]) > 0) {
				n = sprintf("%s", tmpObject[CONFIG[KEY_property_DeviceID]])
			} else {
				n = sprintf("%d", COUNTER_cpu++)
			}
		} else if (s ~ /SAP_ITSAMNetworkPort/) {
			if (length(tmpObject[CONFIG[KEY_property_DeviceID]]) > 0) {
				n = sprintf("%s", tmpObject[CONFIG[KEY_property_DeviceID]])
			} else {
				n = sprintf("Network port %d", COUNTER_networkport++)
			}
		} else if (s ~ /SAP_ITSAMConnectAddress/) {
			n = sprintf("%s:%s", tmpObject["Host"], tmpObject["Port"])
		}
	} else {
		n = replaceBlankAll(n, CONFIG[KEY_separator_namewords])
	}
	return n
}

##
# @brief get object property
#
#
function getObjectProperty(tmpObject, tmpPropertyKey, s)
{
	s = ""
	if (tmpPropertyKey in CONFIG) {
		if (CONFIG[tmpPropertyKey] in tmpObject) {
			s = tmpObject[CONFIG[tmpPropertyKey]]
		}
	}
	return s
}

##
# @brief return object specialization
#
# This function will return the CreationClassName
#
function getObjectSpecialization(tmpObject, s)
{
	s = getObjectProperty(tmpObject, KEY_property_type)
	return s
}

##
# @brief return object type
#
# This function will return the archimate base type
# for the given cim objectClass.
#
function getObjectType(tmpObject, s, t)
{
	s = getObjectSpecialization(tmpObject)
	t = CONFIG["specialization|" s]
	if (length(t) < 1) {
		t = CONFIG[KEY_specialization_default]
	}
	return t
}

##
# @brief check if key unique
#
function isUnique(tmpObject, k, s, n, r)
{
	r = 1
	if ( length(k) < 1 ) {
		s = getObjectSpecialization(tmpObject)
		n = getObjectName(tmpObject)
		k = sprintf("%s|%s", s, n)
	}
	if (k in DUPLICATE) {
		r = 0
	}
	return r
}

##
# @brief return object id
#
# This function will construct a id for
# the archimate object.
#
function newObjectID(r)
{
	r = sprintf(CONFIG[KEY_global_prefix], COUNTER_eid++)
	diagMsg(D_INFO, sprintf("eID=%s", r))
	return r
}

##
# @brief return separator
#
# $0 ~ / sep=(.)/
# separator = $1
#
function parameterSeparator(tmpLine, i, s)
{
	s = ""
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
#			Is written into the OBJECT array
#			OBJECT["Feature_1"] = MESSAGESERVER
#			OBJECT["Feature_2"] = ENQUE
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
#			Is written into the OBJECT array
#			OBJECT["Feature_1"] = MESSAGESERVER
#			OBJECT["Feature_2"] = ENQUE
#
function parameterSplit(tmpObject, tmpAttribute, tmpLine, s, i, j, c, p, v, t, k)
{
	k = 1
	t = tmpAttribute
	c = split(tmpLine, p, s)
	for (j = 1; j <= c; j++) {
		if (length(p[j]) > 0) {
			i = split(p[j], v, CONFIG[KEY_separator_namevalue])
			if (i > 1) {
				setObjectPropertyRaw(tmpObject, t v[1], v[2])
			} else {
				setObjectPropertyRaw(tmpObject, t k++, p[j])
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
	stdMsg(CONFIG[KEY_global_felements], m)
}

##
# @brief print object
#
function printObject(tmpObject, e, t, n, d, s, k, r, re, pe, rd)
{
	# get the archimate element to which the "CreationClassName" maps (see ini file)
	t = getObjectType(tmpObject)
	# determine the object name
	n = getObjectName(tmpObject)
	# determine documentation
	d = getObjectProperty(tmpObject, KEY_property_documentation)
	if (length(d) < 1) {
		d = n
	}
	# specialization
	s = getObjectSpecialization(tmpObject)
	# print element
	printELEMENT(e, t, n, d, s)
	# print properties
	for (k in tmpObject) {
		printPROPERTY(e, k, tmpObject[k])
	}
	# print relations
	for (r in CONFIG) {
		if ( r ~ KEY_relation ) {
			# 1,CompositionRelationship,SystemCreationClassName,SystemName
			split(CONFIG[r], rd, ",")
			pc = tmpObject[rd[3]]
			pn = tmpObject[rd[4]]
			if (length(pc) > 0 && length(pn) > 0) {
				diagMsg(D_DBUG, sprintf("RELATION %s: \"%s::%s|%s\"", DIRECTION[rd[1]], rd[2], pc, pn))
				k = sprintf("%s|%s", pc, pn)
				# get a new id for the relation
				re = newObjectID()
				if (rd[1] == 0) {
					# parent ID
					pe = getObjectID("", k)
					# this object id
					e = getObjectID(tmpObject)
				} else {
					# parent ID
					e = getObjectID("", k)
					# this object id
					pe = getObjectID(tmpObject)
				}
				printRELATION(re, rd[2], "", "", pe, e, "")
			}
		}
	}
	PRINTED[e]=1
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
	stdMsg(CONFIG[KEY_global_fproperties], m)
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
	stdMsg(CONFIG[KEY_global_frelations], m)
}

##
# @brief register and print object
#
# It is possible to provide a ID
# as a parameter if the ID has to
# be generated beforehand.
#
function regObject(tmpObject, e)
{
	# check if the object should be skipped
	if (toIgnore(tmpObject) == 0) {
		# get objectID if not provided
		if (length(e) < 1) {
			e = getObjectID(tmpObject)
		}
		# print the object
		if ( e in PRINTED == 0 ) {
			printObject(tmpObject, e)
		}
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
	for (j in CONFIG) {
		if (KEY_sanitize ~ j) {
			k = substr(j, length(j), 1)
			gsub(k, CONFIG[j], e)
		}
	}
	return e
}

##
# @brief set object property
#
function setObjectProperty(tmpObject, tmpPropertyKey, tmpValue)
{
	# do not set empty values
	if (length(tmpValue) > 0 && tmpPropertyKey in CONFIG) {
		tmpObject[CONFIG[tmpPropertyKey]] = tmpValue
	}
}

##
# @brief set object property raw
#
function setObjectPropertyRaw(tmpObject, tmpPropertyRaw, tmpValue)
{
	# do not set empty values
	if (length(tmpValue) > 0 && length(tmpPropertyRaw) > 0) {
		tmpObject[tmpPropertyRaw] = tmpValue
	}
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

##
# @brief check if key should be ignored
#
function toIgnore(tmpObject, s, r)
{
	r = 0
	# specialization
	s = getObjectSpecialization(tmpObject)
	# check if the object should be skipped
	if (s ~ CONFIG[KEY_global_ignore]) {
		r = 1
	}
	return r
}
