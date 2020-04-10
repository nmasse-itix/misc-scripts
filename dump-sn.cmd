@ECHO OFF

setlocal enableDelayedExpansion
set SN="c:\Program Files\Microsoft SDKs\Windows\v6.0A\Bin\sn.exe"

echo. > sn_dump.txt
for /F %%x in ('dir /B/D *.DLL') do (
   echo. >> sn_dump.txt
   echo ==================================================================== >> sn_dump.txt
   echo. >> sn_dump.txt
   echo Working on %%x >> sn_dump.txt
   echo. >> sn_dump.txt
   %SN% -Tp %%x >> sn_dump.txt
)

