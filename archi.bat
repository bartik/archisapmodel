@ECHO OFF
SETLOCAL EnableExtensions EnableDelayedExpansion
PROMPT $L$D$B$T$B$P$G$_

REM Set the script name
SET "SCRIPTNAME=%~n0"
SET "SCRIPTPATH=%~dp0"
SET "SCRIPTFULL=%~f0"

REM Add the directory from which we run
SET "PATH=%PATH%;!SCRIPTPATH!"

REM Process log files to model
awk -vDEBUG=4 -f %SCRIPTPATH%awk\archi.awk %SCRIPTPATH%ini\archi.ini %SCRIPTPATH%data\getcomputersystem_%~1.log %SCRIPTPATH%data\listdatabasesystems_%~1.log %SCRIPTPATH%data\sapinstance_%~1.log > %SCRIPTPATH%data\archi.out

REM Generate csv output
echo "ID","Type","Name","Documentation","Specialization"> %SCRIPTPATH%data\%~2_elements.csv
grep "ARCHI ELEMENTS:" %SCRIPTPATH%data\archi.out|sed -e "s/ARCHI ELEMENTS: //g" >> %SCRIPTPATH%data\%~2_elements.csv
echo "ID","Key","Value"> %SCRIPTPATH%data\%~2_properties.csv
grep "ARCHI PROPERTIES:" %SCRIPTPATH%data\archi.out|sed -e "s/ARCHI PROPERTIES: //g" >> %SCRIPTPATH%data\%~2_properties.csv
echo "ID","Type","Name","Documentation","Source","Target","Specialization"> %SCRIPTPATH%data\%~2_relations.csv
grep "ARCHI RELATIONS:" %SCRIPTPATH%data\archi.out|sed -e "s/ARCHI RELATIONS: //g" >> %SCRIPTPATH%data\%~2_relations.csv
@ECHO ON