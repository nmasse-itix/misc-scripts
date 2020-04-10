@ECHO OFF
C:
CD \
ECHO. >> C:\auto-enroll.log
ECHO ------------------------------------------------------------------ >> C:\auto-enroll.log
ECHO AUTO ENROLLMENT LOGS >> C:\auto-enroll.log
ECHO ------------------------------------------------------------------ >> C:\auto-enroll.log
ECHO. >> C:\auto-enroll.log

ECHO CURRENT DATE: >> C:\auto-enroll.log
DATE /T >> C:\auto-enroll.log
TIME /T >> C:\auto-enroll.log

ECHO. >> C:\auto-enroll.log
ECHO CURRENT USER: >> C:\auto-enroll.log
WHOAMI >> C:\auto-enroll.log

ECHO. >> C:\auto-enroll.log
CSCRIPT C:\auto-enroll.vbs >> c:\auto-enroll.log
