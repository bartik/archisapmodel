@ECHO OFF
SETLOCAL EnableExtensions EnableDelayedExpansion
PROMPT $L$D$B$T$B$P$G$_

REM Set the script name
SET "SCRIPTNAME=%~n0"
SET "SCRIPTPATH=%~dp0"
SET "SCRIPTFULL=%~f0"
SET "EXT=%COMPUTERNAME%_win"
SET "CSV=a1"

REM Add the directory from which we run
SET "PATH=%PATH%;!SCRIPTPATH!"

REM Download system configuration
SET "HA=C:\Program Files\SAP\hostctrl\exe\"

ECHO GetComputerSystem
CALL :fake_header GetComputerSystem>"%SCRIPTPATH%data\getcomputersystem_%EXT%.raw"
REM "%HA%saphostctrl.exe" -function GetComputerSystem -sapitsam -swpackages -swpatches>>"%SCRIPTPATH%data\getcomputersystem_%EXT%.raw"
"%HA%saphostctrl.exe" -function GetComputerSystem -sapitsam>>"%SCRIPTPATH%data\getcomputersystem_%EXT%.raw"

ECHO GetDatabaseSystem
CALL :fake_header SAP_ITSAMDatabaseSystem>"%SCRIPTPATH%data\getdatabasesystem_%EXT%.raw"
"%HA%saphostctrl.exe" -function GetCIMObject -enuminstances SAP_ITSAMDatabaseSystem>>"%SCRIPTPATH%data\getdatabasesystem_%EXT%.raw"

ECHO ListSAP
CALL :fake_header SAPInstance>"%SCRIPTPATH%data\listsap_%EXT%.raw"
"%HA%saphostctrl.exe" -function GetCIMObject -enuminstances SAPInstance>>"%SCRIPTPATH%data\listsap_%EXT%.raw"

FOR /F "tokens=5" %%A IN ('FINDSTR /C:InstanceName "%SCRIPTPATH%data\listsap_%EXT%.raw"') DO (
	SET "NR=%%A"
	SET "TT=!NR:~0,1!"
	SET "NR=!NR:~-2!"
	2>NUL CALL :GetComponentList!TT! !NR!
	2>NUL CALL :GetVersionInfo !NR!
	2>NUL CALL :ParameterValue !NR!
)
EXIT /B 0

REM Process log files to model
awk -f %SCRIPTPATH%awk\ngetcomputersystem.awk %SCRIPTPATH%data\getcomputersystem_%EXT%.raw > %SCRIPTPATH%data\getcomputersystem_%EXT%.log
awk -f %SCRIPTPATH%awk\ngetdatabasesystem.awk %SCRIPTPATH%data\getdatabasesystem_%EXT%.raw > %SCRIPTPATH%data\getdatabasesystem_%EXT%.log
awk -f %SCRIPTPATH%awk\nlistsap.awk %SCRIPTPATH%data\listsap_%EXT%.raw > %SCRIPTPATH%data\listsap_%EXT%.log
awk -f %SCRIPTPATH%awk\ngetversioninfo.awk %SCRIPTPATH%data\getversioninfo_12_%EXT%.raw > %SCRIPTPATH%data\getversioninfo_12_%EXT%.log
awk -vDEBUG=4 -f %SCRIPTPATH%awk\archi.awk %SCRIPTPATH%ini\archi.ini %SCRIPTPATH%data\getcomputersystem_%EXT%.log %SCRIPTPATH%data\getdatabasesystem_%EXT%.log %SCRIPTPATH%data\getversioninfo_12_%EXT%.log %SCRIPTPATH%data\listsap_%EXT%.log > %SCRIPTPATH%data\archi.out

REM Generate csv output
echo "ID","Type","Name","Documentation","Specialization"> %SCRIPTPATH%data\%CSV%_elements.csv
grep "ARCHI ELEMENTS:" %SCRIPTPATH%data\archi.out|sed -e "s/ARCHI ELEMENTS: //g" >> %SCRIPTPATH%data\%CSV%_elements.csv
echo "ID","Key","Value"> %SCRIPTPATH%data\%CSV%_properties.csv
grep "ARCHI PROPERTIES:" %SCRIPTPATH%data\archi.out|sed -e "s/ARCHI PROPERTIES: //g" >> %SCRIPTPATH%data\%CSV%_properties.csv
echo "ID","Type","Name","Documentation","Source","Target","Specialization"> %SCRIPTPATH%data\%CSV%_relations.csv
grep "ARCHI RELATIONS:" %SCRIPTPATH%data\archi.out|sed -e "s/ARCHI RELATIONS: //g" >> %SCRIPTPATH%data\%CSV%_relations.csv
@ECHO ON
@EXIT 0

:ParameterValue
ECHO ParameterValue
sapcontrol.exe -prot PIPE -nr %~1 -format script -function ParameterValue>"%SCRIPTPATH%data\parametervalue_%~1_%EXT%.raw"
EXIT /B 0

:GetVersionInfo
ECHO GetVersionInfo
sapcontrol.exe -prot PIPE -nr %~1 -format script -function GetVersionInfo>"%SCRIPTPATH%data\getversioninfo_%~1_%EXT%.raw"
EXIT /B 0

:GetComponentListD
ECHO ABAPGetComponentList
sapcontrol.exe -prot PIPE -nr %~1 -format script -function ABAPGetComponentList>"%SCRIPTPATH%data\componentlist_%~1_%EXT%.raw"
EXIT /B 0

:GetComponentListJ
ECHO J2EEGetComponentList
CALL :fake_header J2EEGetComponentList2>"%SCRIPTPATH%data\componentlist_%~1_%EXT%.raw"
CALL %SCRIPTPATH%J2EEGetComponentList2.bat %~1>>"%SCRIPTPATH%data\componentlist_%~1_%EXT%.raw"
EXIT /B 0

:fake_header
ECHO(
ECHO 2023-06-18 19:55:16
ECHO %~1
ECHO OK
EXIT /B 0
