@echo off
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION
cd /d %~dp0

set VER=2.0
set AUTHOR=Cyrille Pontvieux - jrd@enialis.net
set LICENCE=GPL v3+
title Live USB installer v%VER%
goto start

:version
  echo Live USB installer v%VER%
  echo by %AUTHOR%
  echo Licence: %LICENCE%
  goto :EOF

:usage
  echo.install-on-USB.cmd [/?] [/v]
  echo. /? this usage message
  echo. /v the version, author and licence
  echo.
  echo -^> Install syslinux on an USB key using the USB key itself.
  goto :EOF

:install_syslinux
  setlocal
  set DRIVE=%~1
  set BASEDIR=%~2
  set res=n
  echo Warning: syslinux is about to be installed in %DRIVE%
  set /p res=Do you want to continue? [y/N]
  if not "%res%" == "y" (
    endlocal
    exit /b 1
  )
  if not exist %DRIVE%\boot\liveboot (
    echo Error: You need to put the liveboot file from the iso into the boot folder of the usb key %DRIVE%\boot
    endlocal
    exit /b 1
  )
  syslinux.exe -i -m -a %DRIVE%
  if ERRORLEVEL 0 goto syslinuxok
  syslinux.exe -i -m -a -s -f %DRIVE%
  if ERRORLEVEL 1 (
    endlocal
    exit /b 1
  )
:syslinuxok
  endlocal
  goto :EOF

:start
  if "%1" == "/v" goto version
  if "%1" == "/?" goto usage
  if "%1" == "--help" goto usage
  if not "%1" == "" (echo.%1 not recognized & goto usage)
  echo.
  echo. +------------------------------------+
  echo. ^| Installing SaLT system on USB (%~d0) ^|
  echo. +------------------------------------+
  echo.
  echo. Live USB installer version %VER%
  echo. by %AUTHOR%
  echo.
  echo Checking rights...
  whoami /groups > nul
  if ERRORLEVEL 1 goto prevista
  whoami /groups | find "S-1-16-12288" > nul
  if ERRORLEVEL 1 goto elevate
  goto elevated
:elevate
  echo Asking for elevated rights...
  elevate.exe %0 %1 %2 %3 %4 %5 %6 %7 %8 %9
  if ERRORLEVEL 1 echo. & echo. /^^!\ Could not continue, administrator rights are required^^!
  goto :EOF
:prevista
:elevated
  echo. -^> ok
  set DRIVE=%~d0
  set BASEDIR=%~p0
  set BASEDIR=%BASEDIR:\=/%
  echo Installing syslinux...
  call :install_syslinux "%DRIVE%" "%BASEDIR%"
  if ERRORLEVEL 1 goto end
  echo.
  echo *** Live system installed successfully in %DRIVE% ***
:end
  echo.
  pause
