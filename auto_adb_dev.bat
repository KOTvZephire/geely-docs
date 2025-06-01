 @echo off
chcp 1251 > nul
setlocal enabledelayedexpansion

:: -------------------------------
:: Проверка и запрос прав администратора с выбором
:: -------------------------------
:check_admin
net session >nul 2>&1
if %errorlevel% equ 0 goto :admin_ok

echo [ВНИМАНИЕ] Некоторые функции требуют прав администратора.
echo.
choice /c YN /m "Запустить скрипт с правами администратора? (Y/N)"
if errorlevel 2 (
    echo Скрипт продолжит работу без прав администратора.
    echo Некоторые функции (Telnet, установка компонентов) могут быть недоступны.
    timeout /t 3 /nobreak >nul
    goto :admin_ok
)

echo Запрос прав администратора...
powershell Start-Process -FilePath '%~dpnx0' -Verb RunAs
exit /b

:admin_ok

:: -------------------------------
:: Настройки
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
:: Главное меню
:: -------------------------------
:menu
cls
echo -----------------------------------------
echo  Добро пожаловать в скрипт активации ADB
echo -----------------------------------------
echo 1. Проверить обновления и установить
echo 2. Проверка наличия зависимостей
echo 3. Включить ADB через Telnet
echo 4. Проверить подключение ADB
echo 5. Проверка связи (ping)
echo 6. Проверка связи IPv6 (ping -6)
echo 7. Проверка Telnet соединения
echo 8. Проверка активности ADB (сеть)
echo 9. Проверка ADB (USB и сеть)
echo 0. Выход
echo -----------------------------------------
set /p choice="Выберите действие [0-9]: "

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
:: Функция автообновления
:: -------------------------------
:check_internet
    echo Проверка подключения к интернету...
    ping -n 1 8.8.8.8 | find "TTL=" >nul
    if %errorlevel% neq 0 (
        echo [ОШИБКА] Нет подключения к интернету.
        pause
        goto menu
    echo Интернет доступен
    )

:update_script
    goto check_internet
    
    echo Загрузка последней версии скрипта...
    set "TEMP_ZIP=%TEMP%\geely_update.zip"
    set "TEMP_EXTRACT=%TEMP%\geely_update"
    
    powershell -Command "Invoke-WebRequest -Uri '%REPO_URL%' -OutFile '%TEMP_ZIP%'"
    if not exist "%TEMP_ZIP%" (
        echo Ошибка загрузки обновлений.
        pause
        goto menu
    )
    
    if not exist "%TEMP_EXTRACT%" mkdir "%TEMP_EXTRACT%"
    powershell -Command "Expand-Archive -Path '%TEMP_ZIP%' -DestinationPath '%TEMP_EXTRACT%'"
    
    echo Установка обновлений...
    set "SOURCE_DIR=%TEMP_EXTRACT%\geely-docs-main"
    
    if not exist "%SOURCE_DIR%" (
        echo Не найдены файлы обновления.
        pause
        goto menu
    )
    
    xcopy /Y /E /I "%SOURCE_DIR%\*" "%~dp0"
    
    echo Очистка временных файлов...
    del /F /Q "%TEMP_ZIP%" >nul 2>&1
    rmdir /S /Q "%TEMP_EXTRACT%" >nul 2>&1
    
    echo.
    echo Обновление успешно завершено!
    echo Перезапустите скрипт для применения изменений.
    pause
    exit

:: -------------------------------
:: Основные функции
:: -------------------------------
:manage_telnet
    echo.
    echo ===== ПРОВЕРКА TELNET КЛИЕНТА =====
    dism /online /Get-FeatureInfo /FeatureName:TelnetClient | find "Enabled" >nul
    if %errorlevel% equ 0 (
        echo Telnet-клиент установлен и активен.
        goto :eof
    )
    
    echo Telnet-клиент не установлен.
    choice /c YN /m "Установить Telnet-клиент? (Y/N)"
    if errorlevel 2 (
        echo [ОШИБКА] Telnet необходим для подключения к устройству.
        echo Операция прервана.
        exit /b 1
    )
    
    echo Установка Telnet-клиента...
    dism /online /Enable-Feature /FeatureName:TelnetClient /NoRestart
    echo.
    echo ===== ВАЖНО ===================================
    echo Telnet установлен. Для применения изменений
    echo требуется перезагрузка системы.
    echo После перезагрузки запустите скрипт снова.
    echo ===============================================
    pause
    exit /b

:download_plink
    echo.
    echo ===== ПРОВЕРКА PLINK =====
    if exist "%PLINK_BIN%" (
        echo plink.exe найден в: %PLINK_BIN%
        goto :eof
    )
    
    echo plink.exe не найден.
    choice /c YN /m "Скачать plink.exe? (Y/N)"
    if errorlevel 2 (
        echo [ОШИБКА] plink необходим для подключения.
        echo Операция прервана.
        exit /b 1
    )
    
    echo Скачивание plink.exe...
    if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
    powershell -Command "Invoke-WebRequest -Uri '%PLINK_URL%' -OutFile '%PLINK_BIN%'"
    
    if not exist "%PLINK_BIN%" (
        echo [ОШИБКА] Не удалось скачать plink.exe
        exit /b 1
    )
    
    echo plink успешно скачан: %PLINK_BIN%
    goto :eof

:download_adb
    echo.
    echo ===== ПРОВЕРКА ADB =====
    if exist "%ADB_BIN%" (
        echo ADB найден в: %ADB_BIN%
        goto :eof
    )
    
    echo ADB не найден.
    choice /c YN /m "Скачать ADB? (Y/N)"
    if errorlevel 2 (
        echo [ОШИБКА] ADB необходим для подключения.
        echo Операция прервана.
        exit /b 1
    )
    
    echo Скачивание ADB...
    if not exist "%ADB_DIR%" mkdir "%ADB_DIR%"
    powershell -Command "Invoke-WebRequest -Uri '%ADB_URL%' -OutFile '%BIN_DIR%\platform-tools.zip'"
    
    if not exist "%BIN_DIR%\platform-tools.zip" (
        echo [ОШИБКА] Не удалось скачать ADB
        exit /b 1
    )
    
    powershell -Command "Expand-Archive -Path '%BIN_DIR%\platform-tools.zip' -DestinationPath '%ADB_DIR%'"
    move "%ADB_DIR%\platform-tools\adb.exe" "%ADB_BIN%" >nul
    del "%BIN_DIR%\platform-tools.zip"
    rmdir /s /q "%ADB_DIR%\platform-tools" >nul
    
    echo ADB успешно установлен: %ADB_BIN%
    goto :eof

:check_android_host
    echo.
    echo ===== ПРОВЕРКА УСТРОЙСТВА =====
    echo Проверка доступности %ANDROID_HOST% по IPv6...
    
    set "DEVICE_FOUND=false"
    for /l %%i in (1,1,%MAX_ATTEMPTS%) do (
        echo Попытка %%i из %MAX_ATTEMPTS%: ping -6 %ANDROID_HOST%...
        ping -6 %ANDROID_HOST% -n 1 | find "TTL=" >nul
        if !errorlevel! equ 0 (
            set "DEVICE_FOUND=true"
            goto :device_found
        )
        timeout /t %DELAY_SEC% /nobreak >nul
    )
    
    if "%DEVICE_FOUND%"=="false" (
        echo [ОШИБКА] Устройство %ANDROID_HOST% недоступно по IPv6.
        echo Возможные причины:
        echo 1. Вы не подключены к Wi-Fi сети устройства
        echo 2. Устройство не использует хостнейм android.local
        echo 3. Устройство не поддерживает IPv6
        exit /b 1
    )
    
    :device_found
    echo Устройство %ANDROID_HOST% доступно по IPv6.
    goto :eof

:run_adb_commands
    echo.
    echo ===== ВКЛЮЧЕНИЕ ADB НА УСТРОЙСТВЕ =====
    set "SUCCESS=false"
    for /l %%i in (1,1,%MAX_ATTEMPTS%) do (
        echo Попытка подключения %%i из %MAX_ATTEMPTS%...
        echo Команды для выполнения:
        type "%COMMANDS_FILE%"
        
        "%PLINK_BIN%" -telnet %ANDROID_HOST% -batch -m "%COMMANDS_FILE%"
        
        if !errorlevel! equ 0 (
            echo Команды успешно выполнены!
            set "SUCCESS=true"
            goto :commands_success
        )
        
        echo Ожидание %DELAY_SEC% сек. перед повторной попыткой...
        timeout /t %DELAY_SEC% /nobreak >nul
    )
    
    if "%SUCCESS%"=="false" (
        echo [ОШИБКА] Подключение к устройству не удалось.
        echo Возможные причины:
        echo 1. Устройство не отвечает на Telnet
        echo 2. Проблемы с сетевым подключением
        echo 3. Неправильный хостнейм или IP
        exit /b 1
    )
    
    :commands_success
    echo Ожидание применения настроек (10 сек)...
    timeout /t 10 /nobreak >nul
    goto :eof

:verify_adb
    echo.
    echo ===== ПРОВЕРКА ПОДКЛЮЧЕНИЯ ADB =====
    echo Попытка подключения к устройству через ADB...
    
    "%ADB_BIN%" connect %ANDROID_HOST%:5555
    if %errorlevel% neq 0 (
        echo [ОШИБКА] Не удалось подключиться через ADB
        goto :adb_failed
    )
    
    "%ADB_BIN%" devices | find "%ANDROID_HOST%"
    if %errorlevel% neq 0 (
        :adb_failed
        echo [ОШИБКА] ADB не активирован на устройстве.
        echo Требуется:
        echo 1. Откройте приложение "Телефон" на устройстве
        echo 2. Введите код: #*32279
        echo 3. Перейдите в "Настройка" -> "Режим ADB"
        exit /b 1
    )
    
    echo Устройство успешно подключено через ADB!
    goto :eof

:: -------------------------------
:: Пункты меню
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
    echo ===== ПРОВЕРКА PING (IPv4) =====
    echo Проверка связи с %ANDROID_HOST%...
    ping %ANDROID_HOST% -n 4
    if %errorlevel% neq 0 (
        echo [ОШИБКА] Устройство недоступно по IPv4
    ) else (
        echo Устройство доступно по IPv4
    )
    pause
    goto menu

:test_ping_6
    echo.
    echo ===== ПРОВЕРКА PING (IPv6) =====
    echo Проверка связи с %ANDROID_HOST% по IPv6...
    ping -6 %ANDROID_HOST% -n 4
    if %errorlevel% neq 0 (
        echo [ОШИБКА] Устройство недоступно по IPv6
    ) else (
        echo Устройство доступно по IPv6
    )
    pause
    goto menu

:test_telnet
    echo.
    echo ===== ПРОВЕРКА TELNET СОЕДИНЕНИЯ =====
    echo Проверка Telnet на %ANDROID_HOST% (IPv4 и IPv6)...
    
    :: Проверка IPv4
    echo.
    echo [IPv4 ПРОВЕРКА]
    call :test_telnet_address %ANDROID_HOST%
    
    :: Проверка IPv6
    echo.
    echo [IPv6 ПРОВЕРКА]
    call :test_telnet_address %ANDROID_HOST% -6
    
    pause
    goto menu

:test_telnet_address
    set "HOST=%1"
    set "OPTION=%2"
    
    :: Проверка доступности хоста
    if "%OPTION%"=="-6" (
        ping -6 %HOST% -n 1 | find "TTL=" >nul
    ) else (
        ping %HOST% -n 1 | find "TTL=" >nul
    )
    
    if errorlevel 1 (
        echo Хост %HOST% недоступен (%OPTION%)
        goto :eof
    )
    
    :: Проверка порта 23
    echo Проверка порта 23...
    if "%OPTION%"=="-6" (
        set "ADDR_FAMILY=IPv6"
        set "PS_OPTION=-AddressFamily IPv6"
    ) else (
        set "ADDR_FAMILY=IPv4"
        set "PS_OPTION="
    )
    
    powershell -Command "$result = Test-NetConnection -ComputerName '%HOST%' -Port 23 %PS_OPT% -WarningAction SilentlyContinue -ErrorAction SilentlyContinue; if ($result.TcpTestSucceeded) { exit 0 } else { exit 1 }"
    
    if %errorlevel% equ 0 (
        echo Порт 23 открыт (%ADDR_FAMILY%)
        echo Попытка подключения...
        call :telnet_handshake %HOST% %OPTION%
    ) else (
        echo [ОШИБКА] Порт 23 закрыт (%ADDR_FAMILY%)
    )
    goto :eof

:telnet_handshake
    set "HOST=%1"
    set "OPTION=%2"
    
    :: Для IPv6 используем plink
    if "%OPTION%"=="-6" (
        echo Использование plink для IPv6 подключения...
        "%PLINK_BIN%" -telnet %HOST% -batch -m telnet_test
        if %errorlevel% equ 0 (
            echo Успешное подключение к Telnet (IPv6)!
        ) else (
            echo [ОШИБКА] Не удалось подключиться через plink
        )
        goto :eof
    )
    
    :: Для IPv4 используем стандартный telnet
    (
        echo open %HOST% 23
        timeout /t 3 >nul
        echo quit
    ) > telnet_commands.txt
    
    telnet < telnet_commands.txt > "%TEMP%\telnet_test.txt" 2>&1
    
    :: Анализ результатов
    set "TELNET_SUCCESS=false"
    type "%TEMP%\telnet_test.txt" | find "Успешно" >nul && set "TELNET_SUCCESS=true"
    type "%TEMP%\telnet_test.txt" | find "Connected" >nul && set "TELNET_SUCCESS=true"
    type "%TEMP%\telnet_test.txt" | find "Escape character" >nul && set "TELNET_SUCCESS=true"
    
    if "%TELNET_SUCCESS%"=="true" (
        echo Успешное подключение к Telnet (IPv4)!
    ) else (
        echo [ОШИБКА] Не удалось установить соединение
        echo Детали ошибки:
        type "%TEMP%\telnet_test.txt"
    )
    
    :: Очистка временных файлов
    del telnet_commands.txt >nul 2>&1
    del "%TEMP%\telnet_test.txt" >nul 2>&1
    goto :eof

:test_adb_network
    echo.
    echo ===== ПРОВЕРКА АКТИВНОСТИ ADB (СЕТЬ) =====
    echo Проверка порта 5555 на %ANDROID_HOST%...
    
    echo [IPv4 ПРОВЕРКА]
    powershell -Command "$result = Test-NetConnection -ComputerName '%ANDROID_HOST%' -Port 5555; if ($result.TcpTestSucceeded) { echo Порт открыт } else { echo Порт закрыт }"
    
    echo.
    echo [IPv6 ПРОВЕРКА]
    powershell -Command "$result = Test-NetConnection -ComputerName '%ANDROID_HOST%' -Port 5555 -AddressFamily IPv6; if ($result.TcpTestSucceeded) { echo Порт открыт } else { echo Порт закрыт }"
    
    pause
    goto menu

:test_adb_all
    echo.
    echo ===== ПОЛНАЯ ПРОВЕРКА ADB =====
    
    :: Проверка сетевого ADB
    echo.
    echo [СЕТЕВОЕ ПОДКЛЮЧЕНИЕ]
    call :verify_adb
    if %errorlevel% equ 0 (
        echo Сетевое подключение ADB активно.
    ) else (
        echo Сетевое подключение ADB не активно.
    )
    
    :: Проверка USB ADB
    echo.
    echo [USB ПОДКЛЮЧЕНИЕ]
    call :verify_adb_usb
    if %errorlevel% equ 0 (
        echo USB подключение ADB активно.
    ) else (
        echo USB подключение ADB не активно.
    )
    
    pause
    goto menu

:verify_adb_usb
    echo Список USB устройств:
    "%ADB_BIN%" devices
    
    echo.
    echo Проверка подключенных USB устройств...
    for /f "skip=1 tokens=1,2" %%a in ('"%ADB_BIN%" devices') do (
        if "%%b"=="device" (
            echo Найдено авторизованное устройство: %%a
            exit /b 0
        )
        if "%%b"=="unauthorized" (
            echo Найдено неавторизованное устройство: %%a
            exit /b 1
        )
    )
    echo USB устройств не обнаружено.
    exit /b 1