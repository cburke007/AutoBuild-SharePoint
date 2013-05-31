@ECHO OFF
SETLOCAL
cls
@TITLE -- RS_AutoBuild --
FOR /F "tokens=2-4 delims=/ " %%i IN ('date /t') DO SET SHORTDATE=%%i-%%j-%%k
FOR /F "tokens=1-3 delims=: " %%i IN ('time /t') DO SET SHORTTIME=%%i-%%j%%k
GOTO START
:START
:: Check for Powershell
IF NOT EXIST "%SYSTEMROOT%\system32\windowspowershell\v1.0\powershell.exe" (
	COLOR 0C
	ECHO - "powershell.exe" not found!
	ECHO - This script requires PowerShell - install v2.0/3.0, then re-run this script.
	COLOR
	pause
	EXIT
	)
:: Check for Powershell v2.0 (minimum)
ECHO - Checking for Powershell 2.0 (minimum)...
"%SYSTEMROOT%\system32\windowspowershell\v1.0\powershell.exe" $host.Version.Major | find "1" >nul
IF %ERRORLEVEL% == 0 (
	COLOR 0C
	ECHO - This script requires a minimum PowerShell version of 2.0!
	ECHO - Please uninstall v1.0, install v2.0/3.0, then re-run this script.
	COLOR
	pause
	EXIT
	)
ECHO - OK.
GOTO LAUNCHSCRIPT
:LAUNCHSCRIPT
ECHO - Starting RS_AutoBuild...
"%SYSTEMROOT%\system32\windowspowershell\v1.0\powershell.exe" -Command Start-Process "$PSHOME\powershell.exe" -Verb RunAs -ArgumentList "'-NoExit -ExecutionPolicy Bypass %~dp0\RS_AutoBuild.ps1'"
GOTO END
:END
ENDLOCAL