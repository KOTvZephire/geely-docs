@echo off
goto %1

:: -------------------------------
:: Вспомогательные функции
:: -------------------------------
:manage_telnet
    echo Проверка Telnet-клиента...
    dism /online /Get-FeatureInfo /FeatureName:TelnetClient | find "Enabled" >nul
    if %errorlevel% neq 0 (
        echo Telnet-клиент не установлен.
        choice /c YN /m "Установить Telnet-клиент? (Y/N)"
        if errorlevel 2 exit /b 1
        dism /online /Enable-Feature /FeatureName:TelnetClient /NoRestart
        echo Telnet установлен. Перезагрузите систему.
        pause
        exit /b
    )
    goto :eof

:download_plink
    if exist "%PLINK_BIN%" (
        echo plink.exe уже установлен в %BIN_DIR%.
        goto :eof
    )
    if not exist "%PLINK_BIN%" (
        echo plink.exe не найден в %BIN_DIR%.
        choice /c YN /m "Скачать plink.exe? (Y/N)"
        if errorlevel 2 exit /b 1
        powershell -Command "Invoke-WebRequest -Uri '%PLINK_URL%' -OutFile '%PLINK_BIN%'"
    )
    goto :eof

:download_adb
    if exist "%ADB_BIN%" (
        echo ADB уже установлен в %ADB_DIR%.
        goto :eof
    )
    echo Скачивание ADB...
    if not exist "%ADB_DIR%" mkdir "%ADB_DIR%"
    powershell -Command "Invoke-WebRequest -Uri '%ADB_URL%' -OutFile '%BIN_DIR%\platform-tools.zip'"
    powershell -Command "Expand-Archive -Path '%BIN_DIR%\platform-tools.zip' -DestinationPath '%ADB_DIR%'"
    move "%ADB_DIR%\platform-tools\adb.exe" "%ADB_BIN%"
    del "%BIN_DIR%\platform-tools.zip"
    rmdir /s /q "%ADB_DIR%\platform-tools"
    echo ADB успешно установлен.
    goto :eof

:check_android_host
    echo Проверка доступности %ANDROID_HOST%...
    ping -6 %ANDROID_HOST% -n 1 | find "TTL=" >nul
    if %errorlevel% neq 0 (
        echo [ОШИБКА] Устройство недоступно по IPv6.
        pause
        exit /b 1
    )
    goto :eof

:run_adb_commands
    set "SUCCESS=false"
    for /l %%i in (1,1,%MAX_ATTEMPTS%) do (
        echo Попытка подключения %%i/%MAX_ATTEMPTS%...
        "%PLINK_BIN%" -telnet %ANDROID_HOST% -batch -m "%COMMANDS_FILE%"
        if !errorlevel! equ 0 (
            set "SUCCESS=true"
            goto :eof
        )
        timeout /t %DELAY_SEC% /nobreak >nul
    )
    echo [ОШИБКА] Подключение не удалось.
    pause
    exit /b 1

:verify_adb
    echo Проверка ADB...
    "%ADB_BIN%" connect %ANDROID_HOST%:5555 >nul
    "%ADB_BIN%" devices | find "%ANDROID_HOST%" >nul
    if %errorlevel% neq 0 (
        echo [ОШИБКА] ADB не активирован.
        pause
        exit /b 1
    )
    echo ADB успешно подключен!
    goto :eof