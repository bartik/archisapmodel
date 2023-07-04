@REM This is BOM
@ECHO OFF
REM
REM Constants
REM
SET "SCRIPTPATH=%~dp0"
SET "_filename=%TEMP%\%~n0%RANDOM%"
REM
REM Parameters
REM
SET "_sapsystem=%~1"
REM
REM Get a list of _service_type Services
REM
wmic service where "pathname like '%%J%_sapsystem%%%'" get /format:list >"%_filename%.utf"
REM
REM wmic outputs utf format for reads ascii only so convert
REM
TYPE "%_filename%.utf" >"%_filename%.tmp"
REM 
REM Loop through the discovered services
REM
FOR /F "usebackq tokens=1,2* delims==" %%G IN ("%_filename%.tmp") DO (
	SET _dblq=%%H
	SET _dblq=!_dblq:"=""!
	CALL "%SCRIPTPATH%setindirect.bat" "svc_%%G" "!_dblq!"
	IF "%%G"=="WaitHint" (
		CALL :function_sapj2ee_checkcomponent
	)
)
DEL /Q "%_filename%.tmp" "%_filename%.utf"
GOTO :eof

REM Find root install directory
:function_sapj2ee_rootpath
SET "sapj2ee_dir=%~dp1"
SET "sapj2ee_dir=%sapj2ee_dir:exe\=%"
EXIT /B

:function_sapj2ee_checkcomponent
CALL :function_sapj2ee_rootpath %svc_PathName%
SET "_batchconfig=%sapj2ee_dir%\j2ee\configtool\batchconfig.bat"
IF EXIST "%_batchconfig%" (
		CALL "%_batchconfig%" -task get.versions.of.deployed.units
)
EXIT /B
