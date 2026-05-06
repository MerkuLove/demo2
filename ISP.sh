#!/bin/bash

# Проверка на права суперпользователя
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен быть запущен от имени root" 
   exit 1
fi

echo "--- Настройка имени хоста ---"
hostnamectl set-hostname isp

echo "--- Настройка сетевых интерфейсов ---"
# Резервное копирование старого конфига
cp /etc/network/interfaces /etc/network/interfaces.bak

cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
    address 172.16.4.1
    netmask 255.255.255.240

auto eth2
iface eth2 inet static
    address 172.16.5.1
    netmask 255.255.255.240
EOF

echo "--- Включение маршрутизации (IP Forwarding) ---"
# Включаем в текущей сессии
sysctl -w net.ipv4.ip_forward=1
# Сохраняем в конфиг для автозагрузки
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
# На случай, если строки не было, добавим её
grep -qxF 'net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

echo "--- Перезагрузка сети ---"
systemctl restart networking
sysctl -p | grep "ip_forward"

echo "--- Установка ПО и настройка NAT ---"
apt-get update
apt-get install -y iptables

# ВАЖНО: В вашем примере был интерфейс ens19 для NAT. 
# Если интернет приходит на eth0, замените ens19 на eth0 ниже.
OUT_IF="ens19" 
iptables -t nat -A POSTROUTING -o $OUT_IF -j MASQUERADE

echo "--- Сохранение правил iptables ---"
iptables-save > /root/rules

# Добавление в crontab для автозагрузки правил после ребута
(crontab -l 2>/dev/null; echo "@reboot /sbin/iptables-restore < /root/rules") | crontab -

echo "--- Настройка времени ---"
timedatectl set-timezone Europe/Moscow

echo "--- Проверка параметров ---"
ip -c -br -4 a
iptables -t nat -L -n -v
timedatectl

echo "Настройка завершена! Рекомендуется перезайти в терминал для обновления имени хоста."