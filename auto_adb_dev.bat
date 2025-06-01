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
    echo ��������� ������� (Telnet, ��������� �����������) ����� ���� ����������.
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
:: ������� ����
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
echo 5. �������� ����� (ping)
echo 6. �������� ����� IPv6 (ping -6)
echo 7. �������� Telnet ����������
echo 8. �������� ���������� ADB (����)
echo 9. �������� ADB (USB � ����)
echo 0. �����
echo -----------------------------------------
set /p choice="�������� �������� [0-9]: "

if "%choice%"=="1" goto update_script
if "%choice%"=="2" goto install_deps
if "%choice%"=="3" goto enable_adb
if "%choice%"=="4" goto check_adb
if "%choice%"=="5" goto test_ping
if "%choice%"=="6" goto test_ping_6
if "%choice%"=="7" goto test_telnet
if "%choice%"=="8" goto test_adb_network
if "%choice%"=="9" goto test_adb_all
if "%choice%"=="0" exit
goto menu

:: -------------------------------
:: ������� ��������������
:: -------------------------------
:check_internet
    echo �������� ����������� � ���������...
    ping -n 1 8.8.8.8 | find "TTL=" >nul
    if %errorlevel% neq 0 (
        echo [������] ��� ����������� � ���������.
        pause
        goto menu
    echo �������� ��������
    )

:update_script
    goto check_internet
    
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

:: -------------------------------
:: �������� �������
:: -------------------------------
:manage_telnet
    echo.
    echo ===== �������� TELNET ������� =====
    dism /online /Get-FeatureInfo /FeatureName:TelnetClient | find "Enabled" >nul
    if %errorlevel% equ 0 (
        echo Telnet-������ ���������� � �������.
        goto :eof
    )
    
    echo Telnet-������ �� ����������.
    choice /c YN /m "���������� Telnet-������? (Y/N)"
    if errorlevel 2 (
        echo [������] Telnet ��������� ��� ����������� � ����������.
        echo �������� ��������.
        exit /b 1
    )
    
    echo ��������� Telnet-�������...
    dism /online /Enable-Feature /FeatureName:TelnetClient /NoRestart
    echo.
    echo ===== ����� ===================================
    echo Telnet ����������. ��� ���������� ���������
    echo ��������� ������������ �������.
    echo ����� ������������ ��������� ������ �����.
    echo ===============================================
    pause
    exit /b

:download_plink
    echo.
    echo ===== �������� PLINK =====
    if exist "%PLINK_BIN%" (
        echo plink.exe ������ �: %PLINK_BIN%
        goto :eof
    )
    
    echo plink.exe �� ������.
    choice /c YN /m "������� plink.exe? (Y/N)"
    if errorlevel 2 (
        echo [������] plink ��������� ��� �����������.
        echo �������� ��������.
        exit /b 1
    )
    
    echo ���������� plink.exe...
    if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
    powershell -Command "Invoke-WebRequest -Uri '%PLINK_URL%' -OutFile '%PLINK_BIN%'"
    
    if not exist "%PLINK_BIN%" (
        echo [������] �� ������� ������� plink.exe
        exit /b 1
    )
    
    echo plink ������� ������: %PLINK_BIN%
    goto :eof

:download_adb
    echo.
    echo ===== �������� ADB =====
    if exist "%ADB_BIN%" (
        echo ADB ������ �: %ADB_BIN%
        goto :eof
    )
    
    echo ADB �� ������.
    choice /c YN /m "������� ADB? (Y/N)"
    if errorlevel 2 (
        echo [������] ADB ��������� ��� �����������.
        echo �������� ��������.
        exit /b 1
    )
    
    echo ���������� ADB...
    if not exist "%ADB_DIR%" mkdir "%ADB_DIR%"
    powershell -Command "Invoke-WebRequest -Uri '%ADB_URL%' -OutFile '%BIN_DIR%\platform-tools.zip'"
    
    if not exist "%BIN_DIR%\platform-tools.zip" (
        echo [������] �� ������� ������� ADB
        exit /b 1
    )
    
    powershell -Command "Expand-Archive -Path '%BIN_DIR%\platform-tools.zip' -DestinationPath '%ADB_DIR%'"
    move "%ADB_DIR%\platform-tools\adb.exe" "%ADB_BIN%" >nul
    del "%BIN_DIR%\platform-tools.zip"
    rmdir /s /q "%ADB_DIR%\platform-tools" >nul
    
    echo ADB ������� ����������: %ADB_BIN%
    goto :eof

:check_android_host
    echo.
    echo ===== �������� ���������� =====
    echo �������� ����������� %ANDROID_HOST% �� IPv6...
    
    set "DEVICE_FOUND=false"
    for /l %%i in (1,1,%MAX_ATTEMPTS%) do (
        echo ������� %%i �� %MAX_ATTEMPTS%: ping -6 %ANDROID_HOST%...
        ping -6 %ANDROID_HOST% -n 1 | find "TTL=" >nul
        if !errorlevel! equ 0 (
            set "DEVICE_FOUND=true"
            goto :device_found
        )
        timeout /t %DELAY_SEC% /nobreak >nul
    )
    
    if "%DEVICE_FOUND%"=="false" (
        echo [������] ���������� %ANDROID_HOST% ���������� �� IPv6.
        echo ��������� �������:
        echo 1. �� �� ���������� � Wi-Fi ���� ����������
        echo 2. ���������� �� ���������� �������� android.local
        echo 3. ���������� �� ������������ IPv6
        exit /b 1
    )
    
    :device_found
    echo ���������� %ANDROID_HOST% �������� �� IPv6.
    goto :eof

:run_adb_commands
    echo.
    echo ===== ��������� ADB �� ���������� =====
    set "SUCCESS=false"
    for /l %%i in (1,1,%MAX_ATTEMPTS%) do (
        echo ������� ����������� %%i �� %MAX_ATTEMPTS%...
        echo ������� ��� ����������:
        type "%COMMANDS_FILE%"
        
        "%PLINK_BIN%" -telnet %ANDROID_HOST% -batch -m "%COMMANDS_FILE%"
        
        if !errorlevel! equ 0 (
            echo ������� ������� ���������!
            set "SUCCESS=true"
            goto :commands_success
        )
        
        echo �������� %DELAY_SEC% ���. ����� ��������� ��������...
        timeout /t %DELAY_SEC% /nobreak >nul
    )
    
    if "%SUCCESS%"=="false" (
        echo [������] ����������� � ���������� �� �������.
        echo ��������� �������:
        echo 1. ���������� �� �������� �� Telnet
        echo 2. �������� � ������� ������������
        echo 3. ������������ �������� ��� IP
        exit /b 1
    )
    
    :commands_success
    echo �������� ���������� �������� (10 ���)...
    timeout /t 10 /nobreak >nul
    goto :eof

:verify_adb
    echo.
    echo ===== �������� ����������� ADB =====
    echo ������� ����������� � ���������� ����� ADB...
    
    "%ADB_BIN%" connect %ANDROID_HOST%:5555
    if %errorlevel% neq 0 (
        echo [������] �� ������� ������������ ����� ADB
        goto :adb_failed
    )
    
    "%ADB_BIN%" devices | find "%ANDROID_HOST%"
    if %errorlevel% neq 0 (
        :adb_failed
        echo [������] ADB �� ����������� �� ����������.
        echo ���������:
        echo 1. �������� ���������� "�������" �� ����������
        echo 2. ������� ���: #*32279
        echo 3. ��������� � "���������" -> "����� ADB"
        exit /b 1
    )
    
    echo ���������� ������� ���������� ����� ADB!
    goto :eof

:: -------------------------------
:: ������ ����
:: -------------------------------
:install_deps
    call :download_plink
    call :download_adb
    pause
    goto menu

:enable_adb
    call :manage_telnet
    call :download_plink
    call :check_android_host
    call :run_adb_commands
    call :verify_adb
    pause
    goto menu

:check_adb
    call :download_adb
    call :verify_adb
    pause
    goto menu

:test_ping
    echo.
    echo ===== �������� PING (IPv4) =====
    echo �������� ����� � %ANDROID_HOST%...
    ping %ANDROID_HOST% -n 4
    if %errorlevel% neq 0 (
        echo [������] ���������� ���������� �� IPv4
    ) else (
        echo ���������� �������� �� IPv4
    )
    pause
    goto menu

:test_ping_6
    echo.
    echo ===== �������� PING (IPv6) =====
    echo �������� ����� � %ANDROID_HOST% �� IPv6...
    ping -6 %ANDROID_HOST% -n 4
    if %errorlevel% neq 0 (
        echo [������] ���������� ���������� �� IPv6
    ) else (
        echo ���������� �������� �� IPv6
    )
    pause
    goto menu

:test_telnet
    echo.
    echo ===== �������� TELNET ���������� =====
    echo �������� Telnet �� %ANDROID_HOST% (IPv4 � IPv6)...
    
    :: �������� IPv4
    echo.
    echo [IPv4 ��������]
    call :test_telnet_address %ANDROID_HOST%
    
    :: �������� IPv6
    echo.
    echo [IPv6 ��������]
    call :test_telnet_address %ANDROID_HOST% -6
    
    pause
    goto menu

:test_telnet_address
    set "HOST=%1"
    set "OPTION=%2"
    
    :: �������� ����������� �����
    if "%OPTION%"=="-6" (
        ping -6 %HOST% -n 1 | find "TTL=" >nul
    ) else (
        ping %HOST% -n 1 | find "TTL=" >nul
    )
    
    if errorlevel 1 (
        echo ���� %HOST% ���������� (%OPTION%)
        goto :eof
    )
    
    :: �������� ����� 23
    echo �������� ����� 23...
    if "%OPTION%"=="-6" (
        set "ADDR_FAMILY=IPv6"
        set "PS_OPTION=-AddressFamily IPv6"
    ) else (
        set "ADDR_FAMILY=IPv4"
        set "PS_OPTION="
    )
    
    powershell -Command "$result = Test-NetConnection -ComputerName '%HOST%' -Port 23 %PS_OPT% -WarningAction SilentlyContinue -ErrorAction SilentlyContinue; if ($result.TcpTestSucceeded) { exit 0 } else { exit 1 }"
    
    if %errorlevel% equ 0 (
        echo ���� 23 ������ (%ADDR_FAMILY%)
        echo ������� �����������...
        call :telnet_handshake %HOST% %OPTION%
    ) else (
        echo [������] ���� 23 ������ (%ADDR_FAMILY%)
    )
    goto :eof

:telnet_handshake
    set "HOST=%1"
    set "OPTION=%2"
    
    :: ��� IPv6 ���������� plink
    if "%OPTION%"=="-6" (
        echo ������������� plink ��� IPv6 �����������...
        "%PLINK_BIN%" -telnet %HOST% -batch -m telnet_test
        if %errorlevel% equ 0 (
            echo �������� ����������� � Telnet (IPv6)!
        ) else (
            echo [������] �� ������� ������������ ����� plink
        )
        goto :eof
    )
    
    :: ��� IPv4 ���������� ����������� telnet
    (
        echo open %HOST% 23
        timeout /t 3 >nul
        echo quit
    ) > telnet_commands.txt
    
    telnet < telnet_commands.txt > "%TEMP%\telnet_test.txt" 2>&1
    
    :: ������ �����������
    set "TELNET_SUCCESS=false"
    type "%TEMP%\telnet_test.txt" | find "�������" >nul && set "TELNET_SUCCESS=true"
    type "%TEMP%\telnet_test.txt" | find "Connected" >nul && set "TELNET_SUCCESS=true"
    type "%TEMP%\telnet_test.txt" | find "Escape character" >nul && set "TELNET_SUCCESS=true"
    
    if "%TELNET_SUCCESS%"=="true" (
        echo �������� ����������� � Telnet (IPv4)!
    ) else (
        echo [������] �� ������� ���������� ����������
        echo ������ ������:
        type "%TEMP%\telnet_test.txt"
    )
    
    :: ������� ��������� ������
    del telnet_commands.txt >nul 2>&1
    del "%TEMP%\telnet_test.txt" >nul 2>&1
    goto :eof

:test_adb_network
    echo.
    echo ===== �������� ���������� ADB (����) =====
    echo �������� ����� 5555 �� %ANDROID_HOST%...
    
    echo [IPv4 ��������]
    powershell -Command "$result = Test-NetConnection -ComputerName '%ANDROID_HOST%' -Port 5555; if ($result.TcpTestSucceeded) { echo ���� ������ } else { echo ���� ������ }"
    
    echo.
    echo [IPv6 ��������]
    powershell -Command "$result = Test-NetConnection -ComputerName '%ANDROID_HOST%' -Port 5555 -AddressFamily IPv6; if ($result.TcpTestSucceeded) { echo ���� ������ } else { echo ���� ������ }"
    
    pause
    goto menu

:test_adb_all
    echo.
    echo ===== ������ �������� ADB =====
    
    :: �������� �������� ADB
    echo.
    echo [������� �����������]
    call :verify_adb
    if %errorlevel% equ 0 (
        echo ������� ����������� ADB �������.
    ) else (
        echo ������� ����������� ADB �� �������.
    )
    
    :: �������� USB ADB
    echo.
    echo [USB �����������]
    call :verify_adb_usb
    if %errorlevel% equ 0 (
        echo USB ����������� ADB �������.
    ) else (
        echo USB ����������� ADB �� �������.
    )
    
    pause
    goto menu

:verify_adb_usb
    echo ������ USB ���������:
    "%ADB_BIN%" devices
    
    echo.
    echo �������� ������������ USB ���������...
    for /f "skip=1 tokens=1,2" %%a in ('"%ADB_BIN%" devices') do (
        if "%%b"=="device" (
            echo ������� �������������� ����������: %%a
            exit /b 0
        )
        if "%%b"=="unauthorized" (
            echo ������� ���������������� ����������: %%a
            exit /b 1
        )
    )
    echo USB ��������� �� ����������.
    exit /b 1