@REM BOM
@ECHO OFF
:function_setindirect
SET "_varNam=%~1"
SET "_varVal=%~2"
SET "_varVal=%_varVal:""="%"
SET "%_varNam%=%_varVal%"
EXIT /B
