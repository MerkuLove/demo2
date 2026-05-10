#!/bin/bash

# 1. Настройка имени хоста
hostnamectl set-hostname br-srv.au-team.irpo

# 2. Настройка сети (ALT Linux style)
# Переименование интерфейса
mv /etc/net/ifaces/ens1{8,9}

# Очистка options и установка TYPE=eth
echo "TYPE=eth" > /etc/net/ifaces/ens19/options

# Настройка IP, маршрута и DNS
echo "192.168.200.2/28" > /etc/net/ifaces/ens19/ipv4address
echo "default via 192.168.200.1" > /etc/net/ifaces/ens19/ipv4route
echo "nameserver 10.2.0.3" > /etc/net/ifaces/ens19/resolv.conf

# Перезапуск сети
systemctl restart network

# 3. Настройка пользователя
useradd sshuser -u 2026
# Неинтерактивная установка пароля
echo "sshuser:P@ssw0rd" | chpasswd
usermod -aG wheel sshuser

# Настройка sudo без пароля для sshuser
echo "sshuser ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# 4. Настройка SSH
# Создание баннера
echo "Authorized access only" > /etc/openssh/banner

# Редактирование sshd_config через sed
# Изменяем порт, добавляем AllowUsers после Logging, ограничиваем попытки и включаем баннер
sed -i 's/#Port 22/Port 2026/' /etc/openssh/sshd_config
sed -i '/#Logging/a AllowUsers sshuser' /etc/openssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 2/' /etc/openssh/sshd_config
sed -i 's|#Banner none|Banner /etc/openssh/banner|' /etc/openssh/sshd_config

# Перезапуск службы SSH
systemctl restart sshd

# 5. Настройка времени
timedatectl set-timezone Europe/Moscow

echo "Конфигурация BR-SRV завершена."