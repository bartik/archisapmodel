@REM BOM
@ECHO OFF
SET "_src=D:\portablegit\home\archisapmodel"
SET "_bin_pfx=D:\monitoring\release\bin\"
SET "_dst_pfx=D:\monitoring\release\"
SET "_tmp_pfx=D:\monitoring\release\tmp\"
SET "_shfmtexe=D:\monitoring\shfmt.exe -i 2 -ci -w "

REM ARCHISAPMODEL001.SAR
SET "_dst_name=archisapmodel"
SET "_dst=%_dst_pfx%ARCHISAPMODEL%~1%"
SET "_tmp=%_tmp_pfx%%_dst_name%"

REM Copy and cleanse files
MD "%_tmp%"
XCOPY "%_src%" "%_tmp%" /S /E /Y /Q
RD /S /Q "%_tmp%\.git"
DEL /Q "%_tmp%\.gitattributes"
DEL /Q "%_tmp%\.gitignore"
CD %_tmp%\data && DEL /Q *.raw *.log *.out *.csv
COPY /Y "%_bin_pfx%awk.exe" "%_tmp%" >NUL

REM Format shell scripts
D:\monitoring\shfmt.exe -i 2 -ci -w "%_tmp%"

REM set proper line endings
CD %_tmp% && dos2unix *.conf 
CD %_tmp% && dos2unix *.sh
CD %_tmp% && unix2dos *.bat

REM Create package
CD "%_tmp_pfx%"
D:\hostagent\SAPCAR.exe -cf %_dst%.SAR %_dst_name%
D:\hostagent\SAPCAR.exe -tf %_dst%.SAR
CD ..
EXIT /B
@ECHO OFF
