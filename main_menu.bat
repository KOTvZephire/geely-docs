@echo off
chcp 1251 > nul
setlocal enabledelayedexpansion

:: -------------------------------
:: �������� � ������ ���� �������������� � �������
:: -------------------------------
:check_admin
net session >nul 2>&1
if %errorlevel% equ 0 goto :admin_ok

echo [��������] ��������� ������� ������� ���� ��������������.
echo.
choice /c YN /m "��������� ������ � ������� ��������������? (Y/N)"
if errorlevel 2 (
    echo ������ ��������� ������ ��� ���� ��������������.
    echo ��������� ������� ����� ���� ����������.
    timeout /t 3 /nobreak >nul
    goto :admin_ok
)

echo ������ ���� ��������������...
powershell Start-Process -FilePath '%~dpnx0' -Verb RunAs
exit /b

:admin_ok

:: -------------------------------
:: ���������
:: -------------------------------
set "REPO_URL=https://github.com/KOTvZephire/geely-docs/archive/refs/heads/dev-kot.zip"
set "PLINK_URL=https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe"
set "ADB_URL=https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
set "BIN_DIR=%~dp0bin"
set "ADB_DIR=%BIN_DIR%\adb"
set "PLINK_BIN=%BIN_DIR%\plink.exe"
set "ADB_BIN=%ADB_DIR%\adb.exe"
set "COMMANDS_FILE=%BIN_DIR%\adb_commands.txt"
set "ANDROID_HOST=android.local"
set "MAX_ATTEMPTS=5"
set "DELAY_SEC=3"

:: -------------------------------
:: ������� ���� (�������������� �� ������ �����)
:: -------------------------------
:menu
cls
echo -----------------------------------------
echo  ����� ���������� � ������ ��������� ADB
echo -----------------------------------------
echo 1. ��������� ���������� � ����������
echo 2. �������� ������� ������������
echo 3. �������� ADB ����� Telnet
echo 4. ��������� ����������� ADB
echo 0. �����
echo -----------------------------------------
set /p choice="�������� �������� [0-4]: "

if "%choice%"=="1" goto update_script
if "%choice%"=="2" goto install_deps
if "%choice%"=="3" goto enable_adb
if "%choice%"=="4" goto check_adb
if "%choice%"=="0" exit
goto menu

:: -------------------------------
:: ������� ��������������
:: -------------------------------
:update_script
    echo �������� ����������� � ���������...
    ping -n 1 8.8.8.8 | find "TTL=" >nul
    if %errorlevel% neq 0 (
        echo [������] ��� ����������� � ���������.
        pause
        goto menu
    )
    
    echo �������� ��������� ������ �������...
    set "TEMP_ZIP=%TEMP%\geely_update.zip"
    set "TEMP_EXTRACT=%TEMP%\geely_update"
    
    powershell -Command "Invoke-WebRequest -Uri '%REPO_URL%' -OutFile '%TEMP_ZIP%'"
    if not exist "%TEMP_ZIP%" (
        echo ������ �������� ����������.
        pause
        goto menu
    )
    
    if not exist "%TEMP_EXTRACT%" mkdir "%TEMP_EXTRACT%"
    powershell -Command "Expand-Archive -Path '%TEMP_ZIP%' -DestinationPath '%TEMP_EXTRACT%'"
    
    echo ��������� ����������...
    set "SOURCE_DIR=%TEMP_EXTRACT%\geely-docs-main"
    
    if not exist "%SOURCE_DIR%" (
        echo �� ������� ����� ����������.
        pause
        goto menu
    )
    
    xcopy /Y /E /I "%SOURCE_DIR%\*" "%~dp0"
    
    echo ������� ��������� ������...
    del /F /Q "%TEMP_ZIP%" >nul 2>&1
    rmdir /S /Q "%TEMP_EXTRACT%" >nul 2>&1
    
    echo.
    echo ���������� ������� ���������!
    echo ������������� ������ ��� ���������� ���������.
    pause
    exit

:: ��������� ������� ��� ���������
:enable_adb
    call "%BIN_DIR%\..\scripts\utils.bat" :manage_telnet
    call "%BIN_DIR%\..\scripts\utils.bat" :download_plink
    call "%BIN_DIR%\..\scripts\utils.bat" :check_android_host
    call "%BIN_DIR%\..\scripts\utils.bat" :run_adb_commands
    call "%BIN_DIR%\..\scripts\utils.bat" :verify_adb
    pause
    goto menu

:check_adb
    call "%BIN_DIR%\..\scripts\utils.bat" :verify_adb
    pause
    goto menu

:install_deps
    call "%BIN_DIR%\..\scripts\utils.bat" :download_plink
    call "%BIN_DIR%\..\scripts\utils.bat" :download_adb
    pause
    goto menu