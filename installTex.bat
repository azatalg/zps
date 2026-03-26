@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"
set "LOG=%~dp0setup_latex.log"

echo ==== START ==== > "%LOG%"
echo Working dir: %cd% >> "%LOG%"

:: --------------------------------------------------
:: Check admin
:: --------------------------------------------------
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Run this script as administrator.
    echo [ERROR] Run this script as administrator. >> "%LOG%"
    pause
    exit /b 1
)

:: --------------------------------------------------
:: Check PowerShell
:: --------------------------------------------------
where powershell >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] PowerShell not available.
    echo [ERROR] PowerShell not available. >> "%LOG%"
    pause
    exit /b 1
)

:: --------------------------------------------------
:: Install Chocolatey if missing
:: --------------------------------------------------
where choco >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [INFO] Installing Chocolatey...
    echo [INFO] Installing Chocolatey... >> "%LOG%"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))" >> "%LOG%" 2>&1
) else (
    echo [INFO] Chocolatey already installed.
    echo [INFO] Chocolatey already installed. >> "%LOG%"
)

set "CHOCOEXE=%ProgramData%\chocolatey\bin\choco.exe"
if not exist "%CHOCOEXE%" (
    echo [ERROR] choco.exe not found in %CHOCOEXE%
    echo [ERROR] choco.exe not found in %CHOCOEXE% >> "%LOG%"
    echo Check log: %LOG%
    pause
    exit /b 1
)

:: --------------------------------------------------
:: Install Strawberry Perl
:: --------------------------------------------------
echo [INFO] Installing Strawberry Perl...
echo [INFO] Installing Strawberry Perl... >> "%LOG%"
"%CHOCOEXE%" install strawberryperl -y --no-progress >> "%LOG%" 2>&1

:: --------------------------------------------------
:: Install MiKTeX
:: --------------------------------------------------
echo [INFO] Installing MiKTeX...
echo [INFO] Installing MiKTeX... >> "%LOG%"
"%CHOCOEXE%" install miktex -y --no-progress >> "%LOG%" 2>&1

:: --------------------------------------------------
:: Detect paths
:: --------------------------------------------------
set "PERL1=C:\Strawberry\perl\bin"
set "PERL2=%LOCALAPPDATA%\Programs\Strawberry Perl\perl\bin"
set "MIKTEX1=C:\Program Files\MiKTeX\miktex\bin\x64"
set "MIKTEX2=%LOCALAPPDATA%\Programs\MiKTeX\miktex\bin\x64"

set "PERLBIN="
if exist "%PERL1%\perl.exe" set "PERLBIN=%PERL1%"
if exist "%PERL2%\perl.exe" set "PERLBIN=%PERL2%"

set "MIKTEXBIN="
if exist "%MIKTEX1%\latexmk.exe" set "MIKTEXBIN=%MIKTEX1%"
if exist "%MIKTEX2%\latexmk.exe" set "MIKTEXBIN=%MIKTEX2%"

echo [INFO] Detected Perl: %PERLBIN%
echo [INFO] Detected Perl: %PERLBIN% >> "%LOG%"
echo [INFO] Detected MiKTeX: %MIKTEXBIN%
echo [INFO] Detected MiKTeX: %MIKTEXBIN% >> "%LOG%"

if "%PERLBIN%"=="" (
    echo [ERROR] perl.exe not found after install.
    echo [ERROR] perl.exe not found after install. >> "%LOG%"
    echo Check log: %LOG%
    pause
    exit /b 1
)

if "%MIKTEXBIN%"=="" (
    echo [ERROR] latexmk.exe not found after install.
    echo [ERROR] latexmk.exe not found after install. >> "%LOG%"
    echo Check log: %LOG%
    pause
    exit /b 1
)

:: --------------------------------------------------
:: Update global PATH without prompt
:: --------------------------------------------------
for /f "tokens=2,*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul ^| find /I "Path"') do set "MACHINEPATH=%%B"

echo !MACHINEPATH! | find /I "%PERLBIN%" >nul
if errorlevel 1 (
    set "MACHINEPATH=!MACHINEPATH!;%PERLBIN%"
)

echo !MACHINEPATH! | find /I "%MIKTEXBIN%" >nul
if errorlevel 1 (
    set "MACHINEPATH=!MACHINEPATH!;%MIKTEXBIN%"
)

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path /t REG_EXPAND_SZ /d "!MACHINEPATH!" /f >> "%LOG%" 2>&1

:: also update current session
set "PATH=%PATH%;%PERLBIN%;%MIKTEXBIN%"

:: --------------------------------------------------
:: MiKTeX update (admin + fallback)
:: --------------------------------------------------
echo [INFO] Updating MiKTeX (admin)...
echo [INFO] Updating MiKTeX (admin)... >> "%LOG%"
"%MIKTEXBIN%\mpm.exe" --admin --update-db >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [WARN] admin update-db failed, trying without admin.
    echo [WARN] admin update-db failed, trying without admin. >> "%LOG%"
    "%MIKTEXBIN%\mpm.exe" --update-db >> "%LOG%" 2>&1
)

echo [INFO] Checking updates...
echo [INFO] Checking updates... >> "%LOG%"
"%MIKTEXBIN%\mpm.exe" --admin --find-updates >> "%LOG%" 2>&1
if errorlevel 1 (
    "%MIKTEXBIN%\mpm.exe" --find-updates >> "%LOG%" 2>&1
)

echo [INFO] Installing updates...
echo [INFO] Installing updates... >> "%LOG%"
"%MIKTEXBIN%\mpm.exe" --admin --update >> "%LOG%" 2>&1
if errorlevel 1 (
    "%MIKTEXBIN%\mpm.exe" --update >> "%LOG%" 2>&1
)

:: --------------------------------------------------
:: Tests
:: --------------------------------------------------
echo.
echo [INFO] Test perl:
where perl
perl -v

echo.
echo [INFO] Test latexmk:
where latexmk
latexmk -v

echo.
echo [INFO] Test mpm:
where mpm
"%MIKTEXBIN%\mpm.exe" --version

echo ==== DONE ==== >> "%LOG%"
echo.
echo DONE.
echo Restart VS Code or terminal.
echo Log file: %LOG%
pause
exit /b 0