#!/bin/bash

# 1. Настройка имени хоста
hostnamectl set-hostname hq-srv.au-team.irpo

# 2. Настройка сети (ALT Linux style /etc/net)
mv /etc/net/ifaces/ens18 /etc/net/ifaces/ens19 2>/dev/null
echo "TYPE=eth" > /etc/net/ifaces/ens19/options
echo "192.168.100.2/27" > /etc/net/ifaces/ens19/ipv4address
echo "default via 192.168.100.1" > /etc/net/ifaces/ens19/ipv4route
echo "nameserver 10.2.0.3" > /etc/net/ifaces/ens19/resolv.conf
systemctl restart network

# 3. Создание пользователя sshuser
# Пароль передается через chpasswd для автоматизации
useradd sshuser -u 2026
echo "sshuser:P@ssw0rd" | chpasswd
usermod -aG wheel sshuser
echo "sshuser ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# 4. Настройка SSH
# Изменяем порт, лимиты и баннер
sed -i 's/#Port 22/Port 2026/' /etc/openssh/sshd_config
echo "AllowUsers sshuser" >> /etc/openssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 2/' /etc/openssh/sshd_config
sed -i 's|#Banner none|Banner /etc/openssh/banner|' /etc/openssh/sshd_config

echo "Authorized access only" > /etc/openssh/banner
systemctl restart sshd

# 5. Установка и настройка DNS (Bind)
apt-get update
apt-get install bind bind-utils -y

# Настройка options.conf
cat <<EOF > /etc/bind/options.conf
options {
    directory "/var/lib/bind";
    listen-on { 127.0.0.1; 192.168.100.2; };
    listen-on-v6 { none; };
    forwarders { 10.2.0.3; };
    allow-query { any; };
    recursion yes;
    allow-recursion { any; };
};
EOF

# Добавление зон в rfc1912.conf
cat <<EOF >> /etc/bind/rfc1912.conf
zone "au-team.irpo" {
    type master;
    file "au-team.irpo";
};

zone "100.168.192.in-addr.arpa" {
    type master;
    file "100.168.192.in-addr.arpa";
};
EOF

# Создание файла прямой зоны
cp /etc/bind/zone/empty /etc/bind/zone/au-team.irpo
sed -i 's/localhost/au-team.irpo/g' /etc/bind/zone/au-team.irpo
cat <<EOF >> /etc/bind/zone/au-team.irpo
@	IN 	A	192.168.100.2
hq-srv	IN 	A 	192.168.100.2
hq-rtr  IN	A	192.168.100.1
br-rtr  IN	A	192.168.200.1
hq-cli  IN	A	192.168.100.65
br-srv  IN	A	192.168.200.2
isp     IN	A	172.16.4.1
isp     IN	A	172.16.5.1
EOF

# Создание файла обратной зоны
cp /etc/bind/zone/empty /etc/bind/zone/100.168.192.in-addr.arpa
sed -i 's/localhost/au-team.irpo/g' /etc/bind/zone/100.168.192.in-addr.arpa
cat <<EOF >> /etc/bind/zone/100.168.192.in-addr.arpa
2	IN	PTR 	hq-srv.au-team.irpo.
65	IN	PTR	hq-cli.au-team.irpo.
1	IN	PTR	hq-rtr.au-team.irpo.
EOF

# Права доступа и запуск Bind
chown root:named /etc/bind/zone/au-team.irpo
chown root:named /etc/bind/zone/100.168.192.in-addr.arpa
systemctl enable --now bind

# 6. Настройка времени
timedatectl set-timezone Europe/Moscow

echo "Конфигурация HQ-SRV завершена."