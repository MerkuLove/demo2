#!/bin/bash

# 1. Задание имени хоста
hostnamectl set-hostname isp

# 2. Настройка сетевых интерфейсов
# Используем cat <<EOF для записи многострочного конфига
cat <<EOF > /etc/network/interfaces
auto lo
    iface lo inet loopback

auto eth0
    iface eth0 inet dhcp

auto eth1
    iface eth1 inet static
    address 172.16.1.1/28

auto eth2
    iface eth2 inet static
    address 172.16.2.1/28
EOF

# 3. Включение IP Forwarding (маршрутизации)
# Находим строку в файле и раскомментируем её, либо добавляем в конец
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
# На случай, если строки не было, проверим через sysctl напрямую
sysctl -w net.ipv4.ip_forward=1

# Перезагрузка сети
systemctl restart networking

# 4. Установка iptables и настройка NAT
apt-get update
apt-get install -y iptables

# Добавление правила маскарадинга
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Сохранение правил для автозагрузки
iptables-save > /root/rules

# 5. Настройка автозагрузки правил через crontab
# Добавляем задачу в cron без использования текстового редактора
(crontab -l 2>/dev/null; echo "@reboot /sbin/iptables-restore < /root/rules") | crontab -

# 6. Настройка часового пояса
timedatectl set-timezone Europe/Moscow

echo "Конфигурация ISP завершена успешно."