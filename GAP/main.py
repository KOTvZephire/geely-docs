import os
import sys
import socket
from icmplib import ping, resolve
import telnetlib
import threading
import time
import questionary
from questionary import Choice



HOSTNAME = "android.local"


def give_hostname():
    host = questionary.text(
        f'Укажите хост:',
        default=HOSTNAME
    ).ask()
    return host
    

def test_ping(family=4):
    host = give_hostname()
    print(ping(host, count=1, timeout=10, family=family))


def get_ip_host(family=4, host=None):
    """Получение IP-адреса с помощью icmplib"""
    if host == None: host = give_hostname()
    try:
        print(f"\nПолучение адреса IPv{family} для {host}")
        # Для IPv6
        if family == 6:
            result = socket.getaddrinfo(host, None, socket.AF_INET6)
            addr = result[0][4][0]
            address = addr.split('%')[0]
        
        
        # Для IPv4
        else:
            address = socket.gethostbyname(host)
        
        print(f"Получен адрес: {address}")
        return address
    
    except socket.gaierror:
        return None

        

def check_telnet(host=None, port=23, timeout=10):
    """Проверка доступности Telnet-сервера"""
    if host == None: host = give_hostname()
    try:
        with telnetlib.Telnet(host, port, timeout) as tn:
            return True
    except (ConnectionRefusedError, socket.timeout, socket.gaierror):
        return False
    except Exception as e:
        print(f"Неизвестная ошибка Telnet: {e}")
        return False



def ask_version():
    answer = questionary.select(
            'Какою версию IP использовать:',
            use_shortcuts=True,
            instruction=' ',
            choices=[
                Choice('IPv4', 4, shortcut_key='1'),
                Choice('IPv6', 6, shortcut_key='2'),
            ]
        ).ask()
    return answer


def run_telnet_commands(host, commands, family=None, port=23, timeout=10):
    """Выполнение команд через Telnet с получением вывода"""
    if family == None: family = ask_version()
    try:
        with telnetlib.Telnet(host, port, timeout) as tn:
            output = []
            
            # Читаем приветственное сообщение (если есть)
            initial = tn.read_until(b"login:", timeout).decode(errors="ignore")
            if initial:
                output.append(initial)
            
            # Выполняем команды
            for cmd in commands:
                tn.write(cmd.encode() + b"\n")
                response = tn.read_until(b"\n", timeout).decode(errors="ignore")
                output.append(response)
            
            return "\n".join(output)
    except Exception as e:
        return f"Ошибка выполнения команд: {str(e)}"


def run_interactive_telnet(host, port=23, timeout=5):
    """Запуск интерактивной Telnet-сессии"""
    try:
        print(f"\nЗапуск интерактивной Telnet-сессии к {host}:{port}")
        print("Для выхода введите 'exit' или нажмите Ctrl+C\n")
        
        # Подключаемся к серверу
        tn = telnetlib.Telnet(host, port, timeout)
        
        # Флаг для контроля работы потока вывода
        running = True
        
        def read_output():
            """Чтение вывода от сервера в отдельном потоке"""
            while running:
                try:
                    data = tn.read_very_eager()
                    if data:
                        print(data.decode('utf-8', errors='replace'), end='', flush=True)
                    time.sleep(0.1)
                except (ConnectionAbortedError, EOFError):
                    print("\nСоединение закрыто сервером")
                    running = False
                    break
                except Exception:
                    break
        
        # Запускаем поток для чтения вывода
        output_thread = threading.Thread(target=read_output, daemon=True)
        output_thread.start()
        
        # Основной цикл для ввода команд
        while running:
            try:
                # Читаем ввод пользователя
                command = input()
                
                # Проверяем команды выхода
                if command.lower() in ['exit', 'quit']:
                    running = False
                    break
                
                # Отправляем команду на сервер
                tn.write(command.encode() + b"\n")
                
            except KeyboardInterrupt:
                print("\nЗавершение сессии...")
                running = False
                break
            except EOFError:
                print("\nЗавершение сессии...")
                running = False
                break
        
        # Закрываем соединение
        tn.close()
        print("Telnet-сессия завершена")
        
    except (ConnectionRefusedError, socket.timeout, socket.gaierror) as e:
        print(f"Ошибка подключения: {e}")
    except Exception as e:
        print(f"Ошибка в работе Telnet: {e}")


######################
# Интерактивные меню #
######################


def diagnostics_menu():
    while(True):
        answer = questionary.select(
            'Диагностика и тесты:',
            use_shortcuts=True,
            instruction=' ',
            choices=[
                
                Choice('Тест доступности по IPv4', lambda: test_ping(4), shortcut_key='1'),
                Choice('Тест доступности по IPv6', lambda: test_ping(6), shortcut_key='2'),
                Choice('Тест получения адреса IPv4', lambda: get_ip_host(4), shortcut_key='3'),
                Choice('Тест получения адреса IPv6', lambda: get_ip_host(6), shortcut_key='4'),
                Choice('Тест доступа Telnet', lambda: check_telnet(), shortcut_key='5'),
                Choice('Назад', False, shortcut_key='0')
            ]
        ).ask()
        if answer: answer() 
        else: break


def operations_menu():
    while(True):
        answer = questionary.select(
            'Активация ADB:',
            use_shortcuts=True,
            instruction=' ',
            choices=[
                
                Choice('Активатор Cityray', lambda: test_ping(4), shortcut_key='1'),
                Choice('', lambda: test_ping(6), shortcut_key='2'),
                Choice('', lambda: get_ip_host(4), shortcut_key='3'),
                Choice('', lambda: get_ip_host(6), shortcut_key='4'),
                Choice('', lambda: check_telnet(), shortcut_key='5'),
                Choice('Назад', False, shortcut_key='0')
            ]
        ).ask()
        if answer: answer() 
        else: break



if __name__ == "__main__":
    while(True):
        answer = questionary.select(
            'Скрипт активации ADB:',
            use_shortcuts=True,
            instruction=' ',
            choices=[
                Choice('Диагностика и тесты', diagnostics_menu, shortcut_key='1'),
                Choice('Активация ADB', operations_menu, shortcut_key='2'),
                Choice('Выход', sys.exit, shortcut_key='0')
            ]
        ).ask()
        answer()
        