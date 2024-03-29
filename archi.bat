@ECHO OFF
SETLOCAL EnableExtensions EnableDelayedExpansion
PROMPT $L$D$B$T$B$P$G$_

REM Set the script name
SET "SCRIPTNAME=%~n0"
SET "SCRIPTPATH=%~dp0"
SET "SCRIPTFULL=%~f0"

REM Add the directory from which we run
SET "PATH=%PATH%;!SCRIPTPATH!"

REM Reset the command line values at the script start
SET "_arg_download="
SET "_arg_normalize="
SET "_arg_process="
SET "_arg_datadir="
SET "_arg_procdir="
SET "_arg_debug="
SET "_arg_ext="
SET "_arg_csv="
SET "_arg_dir="
SET "_arg_awk="
SET "_arg_ini="

REM Set command line arguments definition
SET options=-debug: -download: -process: -normalize: -datadir:"" -procdir:"" -ext:"" -csv:"" -awk:"" -ini:"" -dir:""
FOR %%O IN (%options%) DO FOR /F "tokens=1,* delims=:" %%A IN ("%%O") DO SET "%%A=%%~B"
:s_loop
IF NOT "%~1"=="" (
	SET "test=!options:*%~1:=! "
	IF "!test!"=="!options! " (
		SET "param=%~1"
		IF "!param:~0,1!"=="-" (
			SET "_text=UNKNOWN - Unknown parameter !param!"
			ECHO !_text!
			GOTO :s_exit
		)
		SET "_arg_parameter=!_arg_parameter!%~1 "
	) ELSE IF "!test:~0,1!"==" " (
		SET "param=%~1"
		SET "name=!param:-=_arg_!"
		SET "!name!=on"
	) ELSE (
		SET "param=%~1"
		SET "value=%~2"
		SET "name=!param:-=_arg_!"
		SET "!name!=!value!"
		SHIFT
	)
	SHIFT
	GOTO :s_loop
)
REM Construct the list of l_inifiles in descending order of importance
REM 1) defined by ini parameter (assumes whole path and extension as parameter)
REM 2) defined by ini parameter (assumes whole path as parameter) + ini extension
REM 3) defined by ini parameter + current/run directory + .ini extension
REM 4) defined by ini parameter + script directory + .ini extension
REM 5) defined by ini parameter + current/run directory
REM 6) defined by ini parameter + script directory
REM 7) script name + current/run directory + .ini extension
REM 8) script name + script directory + .ini extension
REM 9) name "default.ini" + current/run directory
REM 10) name "default.ini " + script directory
IF "!_arg_ini!"=="" (
	SET "l_inifiles="
) ELSE (
	SET _arg_ini=!_arg_ini:"=!
	SET l_inifiles="!_arg_ini!"
	SET l_inifiles=!l_inifiles!;"!_arg_ini!.ini"
	SET l_inifiles=!l_inifiles!;"%CD%\!_arg_ini!.ini"
	SET l_inifiles=!l_inifiles!;"%CD%\ini\!_arg_ini!.ini"
	SET l_inifiles=!l_inifiles!;"!SCRIPTPATH!!_arg_ini!.ini"
	SET l_inifiles=!l_inifiles!;"!SCRIPTPATH!ini\!_arg_ini!.ini"
	SET l_inifiles=!l_inifiles!;"%CD%\!_arg_ini!"
	SET l_inifiles=!l_inifiles!;"%CD%\ini\!_arg_ini!"
	SET l_inifiles=!l_inifiles!;"!SCRIPTPATH!!_arg_ini!"
	SET l_inifiles=!l_inifiles!;"!SCRIPTPATH!ini\!_arg_ini!";
)
SET l_inifiles=!l_inifiles!"%CD%\!SCRIPTNAME!.ini"
SET l_inifiles=!l_inifiles!;"%CD%\ini\!SCRIPTNAME!.ini"
SET l_inifiles=!l_inifiles!;"!SCRIPTPATH!!SCRIPTNAME!.ini"
SET l_inifiles=!l_inifiles!;"!SCRIPTPATH!ini\!SCRIPTNAME!.ini"
SET l_inifiles=!l_inifiles!;"%CD%\default.ini"
SET l_inifiles=!l_inifiles!;"%CD%\ini\default.ini"
SET l_inifiles=!l_inifiles!;"!SCRIPTPATH!default.ini"
SET l_inifiles=!l_inifiles!;"!SCRIPTPATH!ini\default.ini"
FOR %%A IN (!l_inifiles!) DO (
	SET l_file=%%A
	IF EXIST !l_file! (
		SET _arg_ini=!l_file:"=!
		GOTO :s_inifiles
	)
)
:s_inifiles

REM Read local settings
IF EXIST "!SCRIPTPATH!local.ini" (
	CALL :function_readINI "!SCRIPTPATH!local.ini"
)
REM Read inifile
IF EXIST "!_arg_ini!" (
	CALL :function_readINI "!_arg_ini!"
)
REM Set the default values if not supplied
CALL :function_setindirect "_arg_datadir" "%SCRIPTPATH%data\%COMPUTERNAME%\"
CALL :function_setindirect "_arg_procdir" "%SCRIPTPATH%data\%COMPUTERNAME%\"
CALL :function_setindirect "_arg_debug" "off"
CALL :function_setindirect "_arg_download" "off"
CALL :function_setindirect "_arg_process" "off"
CALL :function_setindirect "_arg_normalize" "off"
CALL :function_setindirect "_arg_dir" "C:\Program Files\SAP\hostctrl\exe\"
CALL :function_setindirect "_arg_ext" "%COMPUTERNAME%_win"
CALL :function_setindirect "_arg_awk" "%SCRIPTPATH%awk\"
CALL :function_setindirect "_arg_csv" "a1"
IF "!_arg_debug!"=="on" (
	ECHO START %SCRIPTNAME%
	ECHO Command line arguments
	ECHO ----------------------
	SET _arg_
	ECHO ----------------------
)

IF "!_arg_download!"=="off" GOTO :skip_download
IF NOT EXIST "!_arg_datadir!" (
	IF "!_arg_debug!"=="on" ECHO Create directory "!_arg_datadir!"
	MKDIR "!_arg_datadir!"
)
CD "!_arg_datadir!" || GOTO :skip_download
IF "!_arg_debug!"=="on" ECHO Downloading ifConfig
CALL :function_header ipconfig >"!_arg_datadir!ifconfig_!_arg_ext!.raw"
ipconfig /all>>"!_arg_datadir!ifconfig_!_arg_ext!.raw"
IF "!_arg_debug!"=="on" ECHO Downloading SAPHostAgent
CALL :function_header SAPHostAgent >"!_arg_datadir!saphostagent_!_arg_ext!.raw"
"!_arg_dir!saphostctrl.exe" -prot PIPE -function GetCIMObject -enuminstances SAPHostAgent >>"!_arg_datadir!saphostagent_!_arg_ext!.raw"
IF "!_arg_debug!"=="on" ECHO Downloading GetComputerSystem
CALL :function_header GetComputerSystem >"!_arg_datadir!getcomputersystem_!_arg_ext!.raw"
"!_arg_dir!saphostctrl.exe" -prot PIPE -function GetComputerSystem -sapitsam -swpackages -swpatches >>"!_arg_datadir!getcomputersystem_!_arg_ext!.raw"
IF "!_arg_debug!"=="on" ECHO Downloading GetDatabaseSystem
CALL :function_header SAP_ITSAMDatabaseSystem >"!_arg_datadir!getdatabasesystem_!_arg_ext!.raw"
"!_arg_dir!saphostctrl.exe" -prot PIPE -function GetCIMObject -enuminstances SAP_ITSAMDatabaseSystem >>"!_arg_datadir!getdatabasesystem_!_arg_ext!.raw"
IF "!_arg_debug!"=="on" ECHO Downloading ListSAP
CALL :function_header SAPInstance >"!_arg_datadir!listsap_!_arg_ext!.raw"
"!_arg_dir!saphostctrl.exe" -prot PIPE -function GetCIMObject -enuminstances SAPInstance >>"!_arg_datadir!listsap_!_arg_ext!.raw"

FOR /F "tokens=5" %%A IN ('FINDSTR /C:InstanceName "!_arg_datadir!listsap_!_arg_ext!.raw"') DO (
	SET "NR=%%A"
	SET "TT=!NR:~0,1!"
	SET "NR=!NR:~-2!"
	2>NUL CALL :function_GetComponentList!TT! !NR! "!_arg_datadir!componentlist_!NR!_!_arg_ext!.raw"
	2>NUL CALL :function_GetVersionInfo !NR! "!_arg_datadir!getversioninfo_!NR!_!_arg_ext!.raw"
	2>NUL CALL :function_ParameterValue !NR! "!_arg_datadir!parametervalue_!NR!_!_arg_ext!.raw"
)
:skip_download

IF "!_arg_normalize!"=="off" GOTO :skip_normalize
CD "!_arg_datadir!" || GOTO :skip_normalize
IF NOT EXIST "!_arg_procdir!" (
	IF "!_arg_debug!"=="on" ECHO Create directory "!_arg_procdir!"
	MKDIR "!_arg_procdir!"
)
CD "!_arg_procdir!" || GOTO :skip_normalize
REM Normalize raw files
IF "!_arg_debug!"=="on" ECHO Normalize raw files
FOR /F "usebackq" %%i IN (`DIR /B /S "!_arg_datadir!*" ^| FINDSTR "!_arg_ext!\.raw$"`) DO (
	SET "l_rawfile=%%i"
	SET "l_file=!l_rawfile:.raw=!"
	SET "l_logfile=!l_file!.log"
	IF EXIST "!l_rawfile!" (
		REM Get function name
		SET "_break="
		FOR /F "usebackq skip=3 tokens=1,2" %%j IN ("!l_rawfile!") DO (
			IF NOT DEFINED _break (
				SET "l_function=%%j"
				SET "_break=true"
			)
		)
		REM create new uni file
		DEL /Q "!l_logfile!" >NUL 2>&1
		IF NOT EXIST "!_arg_awk!n!l_function!.awk" SET "l_function=default"
		IF "!_arg_debug!"=="on" ECHO Transform !l_function! !l_rawfile!
		awk -f "!_arg_awk!n!l_function!.awk" "!l_rawfile!" >"!l_logfile!"
		SET _RC=!ERRORLEVEL!
		REM DEL /Q "!l_rawfile!" >NUL 2>&1
	) ELSE (
		SET /A _RC=1
	)
)
:skip_normalize

IF "!_arg_process!"=="off" GOTO :skip_processing
CD "!_arg_datadir!" || GOTO :skip_processing
IF NOT EXIST "!_arg_procdir!" (
	IF "!_arg_debug!"=="on" ECHO Create directory "!_arg_procdir!"
	MKDIR "!_arg_procdir!"
)
CD "!_arg_procdir!" || GOTO :skip_processing
REM Process log files to model
awk -vDEBUG=4 -f "!_arg_awk!archi.awk" "%SCRIPTPATH%\archi.cfg" ^
!_arg_procdir!getcomputersystem_!_arg_ext!.log ^
!_arg_procdir!getdatabasesystem_*.log ^
!_arg_procdir!parametervalue_*.log ^
!_arg_procdir!listsap_*.log ^
!_arg_procdir!getversioninfo_*.log ^
!_arg_procdir!getcomponentlist_*.log > !_arg_procdir!archi.out
REM Generate csv output
REM Elements
IF "!_arg_debug!"=="on" ECHO Generating elements
echo "ID","Type","Name","Documentation","Specialization" >"!_arg_procdir!!_arg_csv!_elements.csv"
CALL :function_printcsv elements 16 "ARCHI ELEMENTS"
REM Properties
IF "!_arg_debug!"=="on" ECHO Generating properties
echo "ID","Key","Value" >"!_arg_procdir!!_arg_csv!_properties.csv"
CALL :function_printcsv properties 18 "ARCHI PROPERTIES"
REM Relations
IF "!_arg_debug!"=="on" ECHO Generating relations
echo "ID","Type","Name","Documentation","Source","Target","Specialization" >"!_arg_procdir!!_arg_csv!_relations.csv"
CALL :function_printcsv relations 17 "ARCHI RELATIONS"
:skip_processing

IF "!_arg_debug!"=="on" ECHO END %SCRIPTNAME%
@ECHO ON
@EXIT 0

:function_ParameterValue
IF "!_arg_debug!"=="on" ECHO Downloading %~1 ParameterValue
CALL :function_header ParameterValue "%~1">%2
(FOR /F "usebackq skip=4 delims=" %%i IN (`sapcontrol.exe -prot PIPE -nr %~1 -format script -function ParameterValue`) DO	ECHO(%%i)>>%2
EXIT /B 0

:function_GetVersionInfo
IF "!_arg_debug!"=="on" ECHO Downloading %~1 GetVersionInfo
CALL :function_header GetVersionInfo "%~1">%2
(FOR /F "usebackq skip=4 delims=" %%i IN (`sapcontrol.exe -prot PIPE -nr %~1 -format script -function GetVersionInfo`) DO ECHO(%%i)>>%2
EXIT /B 0

:function_GetComponentListD
IF "!_arg_debug!"=="on" ECHO Downloading %~1 ABAPGetComponentList
CALL :function_header ABAPGetComponentList "%~1">%2
(FOR /F "usebackq skip=4 delims=" %%i IN (`sapcontrol.exe -prot PIPE -nr %~1 -format script -function ABAPGetComponentList`) DO ECHO(%%i)>>%2
EXIT /B 0

:function_GetComponentListJ
IF "!_arg_debug!"=="on" ECHO Downloading %~1 J2EEGetComponentList2
CALL :function_header J2EEGetComponentList2 "%~1">%2
CALL %SCRIPTPATH%J2EEGetComponentList2.bat %~1>>%2
EXIT /B 0

:function_header
REM Determine date
REM Day  Hour  Minute  Month  Second  Year
REM 6    21    18      7      14      2099
FOR /F "skip=1 delims=" %%F IN ('wmic PATH Win32_LocalTime GET Day^,Month^,Year^,Hour^,Minute^,Second /FORMAT:TABLE') DO (
	FOR /F "tokens=1-6" %%L in ("%%F") do (
		SET _cdd=0%%L
		SET _cHH=0%%M
		SET _cMM=0%%N
		SET _cmm=0%%O
		SET _cSS=0%%P
		SET _cyy=%%Q
	)
)
SET _cdd=%_cdd:~-2%
SET _cmm=%_cmm:~-2%
SET _cHH=%_cHH:~-2%
SET _cMM=%_cMM:~-2%
SET _cSS=%_cSS:~-2%
ECHO(
ECHO %_cdd%.%_cmm%.%_cyy% %_cHH%:%_cMM%:%_cSS%
ECHO %COMPUTERNAME%
IF "%~2"=="" (
	ECHO %~1
) ELSE (
	ECHO %~1 %~2
)
ECHO OK
EXIT /B 0

:function_readINI
SET "l_file=%~1"
SET "l_curr="
FOR /F "delims=" %%A IN (!l_file!) DO (
	SET "l_ln=%%A"
	IF "x!l_ln:~0,1!"=="x[" (
		FOR /F "tokens=1 delims=[]" %%B IN ("!l_ln!") DO SET l_curr=%%B
	) ELSE IF "x!l_ln:~0,1!"=="x#" (
		REM DUMMY
		SET "value="
	) ELSE (
		FOR /F "tokens=1,2* delims==" %%B IN ("!l_ln!") DO (
			SET "param=_!l_curr!_%%B"
			SET "value=%%C"
			CALL :function_setindirect "!param!" "!value!"
		)
	)
)
EXIT /B 0

:function_setindirect
SET _varNam=%~1
SET _newVal=%~2
SET _oldVal=!%_varNam%!
IF "%_oldVal%"=="" SET %_varNam%=%_newVal%
EXIT /B 0

:function_printcsv
FOR /F "tokens=*" %%A IN ('FINDSTR /B /C:"%~3: " "!_arg_procdir!archi.out"') DO (
	SET "LOUT=%%A"
	SET "LOUT=!OUT:~%2,-1!"
	ECHO !LOUT!>>"!_arg_procdir!!_arg_csv!_%1.csv"
)
EXIT /B 0
