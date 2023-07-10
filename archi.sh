#!/bin/bash
# ARG_OPTIONAL_SINGLE([datadir],[d],[Directory where raw data is downloaded.])
# ARG_OPTIONAL_SINGLE([procdir],[p],[Directory where processed output is written.])
# ARG_OPTIONAL_SINGLE([ext],[e],[Postfix for files which have to be processed.])
# ARG_OPTIONAL_SINGLE([csv],[c],[Prefix for the generated csv files.])
# ARG_OPTIONAL_SINGLE([awk],[a],[Directory with the transformation skripts.])
# ARG_OPTIONAL_SINGLE([ini],[i],[Configuration files.])
# ARG_OPTIONAL_SINGLE([dir],[r],[Directory with hostagent executables (default /usr/sap/hostctrl/exe).])
# ARG_OPTIONAL_BOOLEAN([debug],[g],[Print debug output.],[])
# ARG_OPTIONAL_BOOLEAN([download],[w],[Download files.],[])
# ARG_OPTIONAL_BOOLEAN([normalize],[n],[Convert raw files to common format.],[])
# ARG_OPTIONAL_BOOLEAN([process],[s],[Transform cim to archimate csv.],[])
# ARG_HELP([This program transforms the cim model into a archi csv format])

# Constants
VERSION=1.0
LC_ALL=C
TEMPFILE=""
AGENTDIR="/usr/sap/hostctrl/exe/"
SCRIPTNAME="${0##*/}"
SCRIPTNAME="${SCRIPTNAME%%.*}"
SCRIPTPATH=$(dirname "$0")
SCRIPTPATH="$(cd "${SCRIPTPATH}" && pwd -P)/"
CURRENTDIR="$(pwd -P)/"
SCRIPTPID=$$
l_RC=0

die()
{
	local _ret="${2:-1}"
	test "${_PRINT_HELP:-no}" = yes && print_help >&2
	echo "$1" >&2
	exit "${_ret}"
}

begins_with_short_option()
{
	local first_option all_short_options='dpecairgwnsh'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_datadir=
_arg_procdir=
_arg_ext=
_arg_csv=
_arg_awk=
_arg_ini=
_arg_dir=
_arg_debug=
_arg_download=
_arg_normalize=
_arg_process=

print_help()
{
	printf '%s\n' "This program transforms the cim model into a archi csv format"
	printf 'Usage: %s [-d|--datadir <arg>] [-p|--procdir <arg>] [-e|--ext <arg>] [-c|--csv <arg>] [-a|--awk <arg>] [-i|--ini <arg>] [-r|--dir <arg>] [-g|--(no-)debug] [-w|--(no-)download] [-n|--(no-)normalize] [-s|--(no-)process] [-h|--help]\n' "$0"
	printf '\t%s\n' "-d, --datadir: Directory where raw data is downloaded. (no default)"
	printf '\t%s\n' "-p, --procdir: Directory where processed output is written. (no default)"
	printf '\t%s\n' "-e, --ext: Postfix for files which have to be processed. (no default)"
	printf '\t%s\n' "-c, --csv: Prefix for the generated csv files. (no default)"
	printf '\t%s\n' "-a, --awk: Directory with the transformation skripts. (no default)"
	printf '\t%s\n' "-i, --ini: Configuration files. (no default)"
	printf '\t%s\n' "-r, --dir: Directory with hostagent executables (default /usr/sap/hostctrl/exe). (no default)"
	printf '\t%s\n' "-g, --debug, --no-debug: Print debug output. (off by default)"
	printf '\t%s\n' "-w, --download, --no-download: Download files. (off by default)"
	printf '\t%s\n' "-n, --normalize, --no-normalize: Convert raw files to common format. (off by default)"
	printf '\t%s\n' "-s, --process, --no-process: Transform cim to archimate csv. (off by default)"
	printf '\t%s\n' "-h, --help: Prints help"
}


parse_commandline()
{
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-d|--datadir)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_datadir="$2"
				shift
				;;
			--datadir=*)
				_arg_datadir="${_key##--datadir=}"
				;;
			-d*)
				_arg_datadir="${_key##-d}"
				;;
			-p|--procdir)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_procdir="$2"
				shift
				;;
			--procdir=*)
				_arg_procdir="${_key##--procdir=}"
				;;
			-p*)
				_arg_procdir="${_key##-p}"
				;;
			-e|--ext)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_ext="$2"
				shift
				;;
			--ext=*)
				_arg_ext="${_key##--ext=}"
				;;
			-e*)
				_arg_ext="${_key##-e}"
				;;
			-c|--csv)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_csv="$2"
				shift
				;;
			--csv=*)
				_arg_csv="${_key##--csv=}"
				;;
			-c*)
				_arg_csv="${_key##-c}"
				;;
			-a|--awk)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_awk="$2"
				shift
				;;
			--awk=*)
				_arg_awk="${_key##--awk=}"
				;;
			-a*)
				_arg_awk="${_key##-a}"
				;;
			-i|--ini)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_ini="$2"
				shift
				;;
			--ini=*)
				_arg_ini="${_key##--ini=}"
				;;
			-i*)
				_arg_ini="${_key##-i}"
				;;
			-r|--dir)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_dir="$2"
				shift
				;;
			--dir=*)
				_arg_dir="${_key##--dir=}"
				;;
			-r*)
				_arg_dir="${_key##-r}"
				;;
			-g|--no-debug|--debug)
				_arg_debug="on"
				test "${1:0:5}" = "--no-" && _arg_debug="off"
				;;
			-g*)
				_arg_debug="on"
				_next="${_key##-g}"
				if test -n "$_next" -a "$_next" != "$_key"
				then
					{ begins_with_short_option "$_next" && shift && set -- "-g" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
				fi
				;;
			-w|--no-download|--download)
				_arg_download="on"
				test "${1:0:5}" = "--no-" && _arg_download="off"
				;;
			-w*)
				_arg_download="on"
				_next="${_key##-w}"
				if test -n "$_next" -a "$_next" != "$_key"
				then
					{ begins_with_short_option "$_next" && shift && set -- "-w" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
				fi
				;;
			-n|--no-normalize|--normalize)
				_arg_normalize="on"
				test "${1:0:5}" = "--no-" && _arg_normalize="off"
				;;
			-n*)
				_arg_normalize="on"
				_next="${_key##-n}"
				if test -n "$_next" -a "$_next" != "$_key"
				then
					{ begins_with_short_option "$_next" && shift && set -- "-n" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
				fi
				;;
			-s|--no-process|--process)
				_arg_process="on"
				test "${1:0:5}" = "--no-" && _arg_process="off"
				;;
			-s*)
				_arg_process="on"
				_next="${_key##-s}"
				if test -n "$_next" -a "$_next" != "$_key"
				then
					{ begins_with_short_option "$_next" && shift && set -- "-s" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
				fi
				;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_PRINT_HELP=yes die "FATAL ERROR: Got an unexpected argument '$1'" 1
				;;
		esac
		shift
	done
}

function print_header() {
  local l_function=${1}
  local l_instance=${2}

	printf '\n'
	"${_arg_date}" +"%Y-%m-%d %H:%M:%S %Z"
	printf '%s\n' "$(hostname)"
	if [[ "${l_instance}" == "" ]]; then
		printf '%s\n' "${l_function}"
	else
		printf '%s %d\n' "${l_function}" "${l_instance}"
        fi
	printf 'OK\n'
}


################################################################################
# Main
parse_commandline "$@"

################################################################################
# Construct the list of binary commands in descending order of importance
# 1) defined by cmd parameter (assumes whole path and extension as parameter)
# 2) defined by cmd parameter + current/run directory
# 3) defined by cmd parameter + script directory
# 4) default + current/run directory
# 5) default + script directory
l_commands=("saphostctrl" "sapgenpse" "sapcontrol" "wget" "SAPCAR")
for ((i = 0; i < ${#l_commands[@]}; i++)); do
	l_cmd=()
	ARGVAR="_arg_${l_commands[$i]}"
	ARGVAL=${!ARGVAR}
	if [[ -n ${ARGVAL} ]]; then
		l_cmd+=("${ARGVAL}")
	fi
	# try if current user has the command in path
	l_tmp="$(which "${l_commands[$i]}" 2>/dev/null)"
	l_cmd+=(
		"${l_tmp}"
		"${_arg_dir}${l_commands[$i]}"
		"${AGENTDIR}${l_commands[$i]}"
		"${SCRIPTPATH}${l_commands[$i]}"
		"${CURRENTDIR}${l_commands[$i]}"
	)
	for ((j = 0; j < ${#l_cmd[@]}; j++)); do
		if [[ -x ${l_cmd[$j]} ]]; then
			declare "$ARGVAR=${l_cmd[$j]}"
			break
		fi
	done
done

################################################################################
# determine ini file name
# Construct the list of l_inifiles in descending order of importance
# 1) defined by ini parameter (assumes whole path and extension as parameter)
# 2) defined by ini parameter (assumes whole path as parameter) + ini extension
# 3) defined by ini parameter + current/run directory + .ini extension
# 4) defined by ini parameter + script directory + .ini extension
# 5) defined by ini parameter + current/run directory
# 6) defined by ini parameter + script directory
# 7) script name + current/run directory + .ini extension
# 8) script name + script directory + .ini extension
# 9) name "default.ini" + current/run directory
# 10) name "default.ini " + script directory
l_inifiles=()
if [[ -n ${_arg_ini} ]]; then
	# remove nonprintable characters from filename workaround for nrpe buffer size
	# ${_arg_ini//[![:print:]]/}
	_arg_ini="$(tr -dc '[:print:]' <<< "${_arg_ini}")"
	l_inifiles+=(
		"${_arg_ini}"
		"${_arg_ini}.ini"
		"${CURRENTDIR}${_arg_ini}.ini"
		"${CURRENTDIR}ini/${_arg_ini}.ini"
		"${SCRIPTPATH}${_arg_ini}.ini"
		"${SCRIPTPATH}ini/${_arg_ini}.ini"
		"${CURRENTDIR}${_arg_ini}"
		"${CURRENTDIR}ini/${_arg_ini}"
		"${SCRIPTPATH}${_arg_ini}"
		"${SCRIPTPATH}ini/${_arg_ini}"
	)
fi
l_inifiles+=(
	"${CURRENTDIR}${SCRIPTNAME}.ini"
	"${CURRENTDIR}ini/${SCRIPTNAME}.ini"
	"${SCRIPTPATH}${SCRIPTNAME}.ini"
	"${SCRIPTPATH}ini/${SCRIPTNAME}.ini"
	"${CURRENTDIR}default.ini"
	"${CURRENTDIR}ini/default.ini"
	"${SCRIPTPATH}default.ini"
	"${SCRIPTPATH}ini/default.ini"
)

################################################################################
# read local ini file if defined
# do not overwrite already existing parameters from command line
_tmp_ini="${_arg_ini}"
_arg_ini="${SCRIPTPATH}local.ini"
if [[ -n ${_arg_ini:-} && -f ${_arg_ini:-} ]]; then
	if [[ -r ${_arg_ini:-} ]]; then
		while IFS='=' read -r INIVAR INIVAL; do
			if [[ ${INIVAR} == [* ]]; then
				INIVAR="${INIVAR#?}"
				INISEC="${INIVAR%%?}"
			elif [[ ${INIVAL:-} ]]; then
				ARGVAR="_${INISEC}_${INIVAR}"
				ARGVAL=${!ARGVAR:-}
				if [[ -z ${ARGVAL} ]]; then
					if [[ ${ARGVAR} == "_arg_parameter" ]]; then
						for _last_positional in ${INIVAL}; do
							_positionals+=("$_last_positional")
							_positionals_count=$((_positionals_count + 1))
						done
					else
						declare "_${INISEC}_${INIVAR}=${INIVAL}"
					fi
				fi
			fi
		done <"${_arg_ini}"
	fi
fi
_arg_ini="${_tmp_ini}"

################################################################################
# find the first existing ini file
# 
for ((i = 0; i < ${#l_inifiles[@]}; i++)); do
	if [[ -f ${l_inifiles[$i]} && -r ${l_inifiles[$i]} ]]; then
		_arg_ini="${l_inifiles[$i]}"
		break
	fi
done

################################################################################
# read ini file if defined
# do not overwrite already existing parameters from command line
if [[ -n ${_arg_ini:-} && -f ${_arg_ini:-} ]]; then
	if [[ -r ${_arg_ini:-} ]]; then
		while IFS='=' read -r INIVAR INIVAL; do
			if [[ ${INIVAR} == [* ]]; then
				INIVAR="${INIVAR#?}"
				INISEC="${INIVAR%%?}"
			elif [[ ${INIVAL:-} ]]; then
				ARGVAR="_${INISEC}_${INIVAR}"
				ARGVAL=${!ARGVAR:-}
				if [[ -z ${ARGVAL} ]]; then
					if [[ ${ARGVAR} == "_arg_parameter" ]]; then
						for _last_positional in ${INIVAL}; do
							_positionals+=("$_last_positional")
							_positionals_count=$((_positionals_count + 1))
						done
					else
						declare "_${INISEC}_${INIVAR}=${INIVAL}"
					fi
				fi
			fi
		done <"${_arg_ini}"
	else
		die "File: ${_arg_ini:-} is not readable." "${ERR_READ_INI}"
	fi
fi

################################################################################
# default values if not already defined
_arg_dir="${_arg_dir:-/usr/sap/hostctrl/exe/}"
_arg_awk="${_arg_awk:-${SCRIPTPATH}awk/}"
_arg_ini="${_arg_ini:-${SCRIPTPATH}ini/}"
_arg_debug="${_arg_debug:-off}"
_arg_datadir="${_arg_datadir:-${SCRIPTPATH}data/$(hostname)/}"
_arg_procdir="${_arg_procdir:-${SCRIPTPATH}data/$(hostname)/}"
_arg_ext="$(hostname)_aix"
_arg_csv="a1"
_arg_download="${_arg_download:-off}"
_arg_normalize="${_arg_normalize:-off}"
_arg_process="${_arg_process:-off}"

if [[ -x /usr/bin/date ]]; then
	_arg_date="/usr/bin/date"
elif [[ -x /bin/date ]]; then
	_arg_date="/bin/date"
else
	_arg_date="date"
fi

if [[ -d ${TMPDIR} ]]; then
	_arg_tmp="${_arg_tmp:-${TMPDIR}/}"
elif [[ -d /tmp ]]; then
	_arg_tmp="${_arg_tmp:-/tmp/}"
else
	_arg_tmp="${_arg_tmp:-${SCRIPTPATH}}"
fi

function print_debug() {
	local l_message=${1}
	
	if [[ ${_arg_debug} == "on" ]]; then
		printf '%s\n' "${l_message}"
	fi
}

export PATH="$PATH:/sbin"

if [[ ${_arg_debug} == "on" ]]; then
	printf 'START %s\n' "${SCRIPTNAME}"
	printf '%s\n' "Command line arguments"
	printf '%s\n' "----------------------"
	typeset -p | awk '$3 ~ /^_arg_/ { print $3}'
	printf '%s\n' "----------------------"
fi

if [[ "${_arg_download}" == "on" ]]; then
	if [[ ! -d ${_arg_datadir} ]]; then
		print_debug "Create directory ${_arg_datadir}"
		mkdir -p "${_arg_datadir}"
	fi
	cd "${_arg_datadir}" && {
		print_debug "Downloading ifconfig"
		print_header "ifconfig" >"${_arg_datadir}ifconfig_${_arg_ext}.raw"
		ifconfig -a >>"${_arg_datadir}ifconfig_${_arg_ext}.raw"
		print_debug "Downloading SAPHostAgent"
		print_header "SAPHostAgent" >"${_arg_datadir}saphostagent_${_arg_ext}.raw"
		"${_arg_dir}saphostctrl" -prot PIPE -function GetCIMObject -enuminstances SAPHostAgent >>"${_arg_datadir}saphostagent_${_arg_ext}.raw"
		print_debug "Downloading GetComputerSystem"
		print_header "GetComputerSystem" >"${_arg_datadir}getcomputersystem_${_arg_ext}.raw"
		"${_arg_dir}saphostctrl" -prot PIPE -function GetComputerSystem -sapitsam -swpackages -swpatches >>"${_arg_datadir}getcomputersystem_${_arg_ext}.raw"
		print_debug "Downloading GetDatabaseSystem"
		print_header "SAP_ITSAMDatabaseSystem" >"${_arg_datadir}getdatabasesystem_${_arg_ext}.raw"
		"${_arg_dir}saphostctrl" -prot PIPE -function GetCIMObject -enuminstances SAP_ITSAMDatabaseSystem >>"${_arg_datadir}getdatabasesystem_${_arg_ext}.raw"
		print_debug "Downloading ListSAP"
		print_header "SAPInstance" >"${_arg_datadir}listsap_${_arg_ext}.raw"
		"${_arg_dir}saphostctrl" -prot PIPE -function GetCIMObject -enuminstances SAPInstance >>"${_arg_datadir}listsap_${_arg_ext}.raw"
		while read -r l_instance; do
			NR="${l_instance: -2}"
			TT="${l_instance:0:1}"
			print_debug "Downloading ${NR} ParameterValue"
			print_header "ParameterValue" "${NR}">"${_arg_datadir}parametervalue_${NR}_${_arg_ext}.raw"
			"${_arg_dir}sapcontrol" -prot PIPE -nr "${NR}" -format script -function ParameterValue|awk 'NR>4' >>"${_arg_datadir}parametervalue_${NR}_${_arg_ext}.raw"
			print_debug "Downloading ${NR} GetVersionInfo"
			print_header "GetVersionInfo" "${NR}">"${_arg_datadir}getversioninfo_${NR}_${_arg_ext}.raw"
			"${_arg_dir}sapcontrol" -prot PIPE -nr "${NR}" -format script -function GetVersionInfo|awk 'NR>4' >>"${_arg_datadir}getversioninfo_${NR}_${_arg_ext}.raw"
			if [[ "${TT}" == "D" ]]; then
				print_debug "Downloading ${NR} ABAPGetComponentList"
				print_header "ABAPGetComponentList" "${NR}">"${_arg_datadir}componentlist_${NR}_${_arg_ext}.raw"
				# "${_arg_dir}sapcontrol" -prot PIPE -nr "${NR}" -format script -function ABAPGetComponentList|awk 'NR>4' >>"${_arg_datadir}componentlist_${NR}_${_arg_ext}.raw"
				"sapcontrol" -prot PIPE -nr "${NR}" -format script -function ABAPGetComponentList|awk 'NR>4' >>"${_arg_datadir}componentlist_${NR}_${_arg_ext}.raw"
			fi
			if [[ "${TT}" == "J" ]]; then
				print_debug "Downloading ${NR} J2EEGetComponentList2"
				print_header "J2EEGetComponentList2" "${NR}">"${_arg_datadir}componentlist_${NR}_${_arg_ext}.raw"
				find /usr/sap/[A-Z][A-Z0-9][A-Z0-9]/J${NR}/j2ee/configtool/ -regex ".*/batchconfig\.[c]*sh$" -type f -exec '{}' -task get.versions.of.deployed.units \; >>"${_arg_datadir}componentlist_${NR}_${_arg_ext}.raw"
			fi
		done < <(awk -F',' '/InstanceName/ { print $NF }' "${_arg_datadir}listsap_${_arg_ext}.raw" | tr -d '[:blank:]')
	}
fi

if [[ "${_arg_normalize}" == "on" ]]; then
	if [[ ! -d ${_arg_procdir} ]]; then
		print_debug "Create directory ${_arg_procdir}"
		mkdir -p "${_arg_procdir}"
	fi
	cd "${_arg_procdir}" && {
		while IFS= read -r l_rawfile; do
			_cmd=$(awk 'NR==5 {print tolower($1)}' "${l_rawfile}")
			l_file="${l_rawfile%.*}"
			l_logfile="${l_file}.log"
			if [[ ! -r "${_arg_awk}n${_cmd}.awk" ]]; then
				_cmd="default"
			fi
			print_debug "Transform ${_cmd} ${l_rawfile}"
			awk "${_arg_awk}n${_cmd}.awk" "${l_rawfile}" >"${l_logfile}"
		done < <(find "${_arg_datadir}" -regex "${_arg_datadir}.*\.raw" 2>/dev/null)
	}
fi
