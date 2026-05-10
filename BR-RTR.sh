#!/bin/bash

# Скрипт только для конфигурации BR-RTR (без проверок)

echo "Applying configuration to BR-RTR..."

clis <<EOF
conf t

# Задание имени и домена
hostname br-rtr
ip domain-name au-team.irpo

# Настройка интерфейса ISP
interface isp 
 description "Connect ISP"
 ip address 172.16.2.14/28
 port te0
 service-instance te0/isp
 encapsulation untagged
 connect ip interface isp
exit

# Настройка интерфейса BR-Net
interface BR-Net
 description "Connect BR-Net"
 ip address 192.168.200.1/28
 port te1
 service-instance te1/BR-Net
 encapsulation untagged
 connect ip interface BR-Net
exit

# Шлюз по умолчанию
ip route 0.0.0.0/0 172.168.5.1
write memory

# Создание пользователя
username net_admin
password P@ssw0rd
role admin
exit
write memory

# Настройка GRE туннеля
interface tunnel.0
 description "GRE-to-HQ"
 ip address 10.10.10.2/30
 ip tunnel 172.16.2.14 172.16.1.14 mode gre
exit
write memory

# Настройка OSPF
router ospf 1
 ospf router-id 10.10.10.2
 passive-interface default
 no passive-interface tunnel.0
 network 10.10.10.0/30 area 0
 network 192.168.200.0/28 area 0
exit

# Аутентификация OSPF
interface tunnel.0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 P@ssw0rd
exit

# Настройка NAT
interface isp
 ip nat outside
exit
interface BR-Net
 ip nat inside
exit

ip nat pool BR 192.168.200.1 192.168.200.254
ip nat source dynamic inside-to-outside pool BR overload interface isp
write memory

# Настройка временной зоны
ntp timezone utc+3
write memory

exit
EOF

echo "Configuration applied successfully."