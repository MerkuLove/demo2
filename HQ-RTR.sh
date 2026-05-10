#!/bin/bash

# Скрипт автоматизации настройки HQ-RTR
# Использование: sudo ./setup_hq_rtr.sh

echo "Начинаю настройку HQ-RTR..."

# Функция для отправки команд в CLI (предполагается использование ecocli или аналога)
# Если настройка идет через прямую запись в конфиг-файлы Linux, команды адаптированы.
# В данном случае используем перенаправление потока в оболочку управления.

clis << 'EOF'
configure terminal

# 1. Настройка внешнего интерфейса (ISP)
interface isp
 description "Connect ISP"
 ip address 172.16.1.14/28
 port te0
 service-instance te0/isp
  encapsulation untagged
  connect ip interface isp
exit

# 2. Настройка внутренних интерфейсов (VLANs)
interface vl100
 description "Servers - vlan100"
 ip address 192.168.100.1/27
exit

interface vl200
 description "Clients - vlan200"
 ip address 192.168.100.65/28
exit

interface vl999
 description "Managements - vlan999"
 ip address 192.168.100.81/29
exit

# Привязка сервисов к физическому порту te1
port te1
 service-instance te1/vl100
  encapsulation dot1q 100 exact
  rewrite pop 1
  connect ip interface vl100
 exit
 service-instance te1/v200
  encapsulation dot1q 200 exact
  rewrite pop 1
  connect ip interface vl200
 exit
 service-instance te1/vl999
  encapsulation dot1q 999 exact
  rewrite pop 1
  connect ip interface vl999
 exit
exit

# 3. Маршрут по умолчанию
ip route 0.0.0.0/0 172.168.4.1

# 4. Создание администратора
username net_admin
 password P@ssw0rd 
 role admin
exit

# 5. Настройка GRE туннеля до BR-RTR
interface tunnel.0
 description "GRE-to-BR"
 ip address 10.10.10.1/30
 ip tunnel 172.16.1.14 172.16.2.14 mode gre
exit

# 6. Настройка OSPF
router ospf 1
 ospf router-id 10.10.10.1
 passive-interface default
 no passive-interface tunnel.0
 network 10.10.10.0/30 area 0
 network 192.168.100.0/27 area 0
 network 192.168.100.64/28 area 0
 network 192.168.100.80/29 area 0
exit

# Настройка аутентификации в OSPF на туннеле
interface tunnel.0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 P@ssw0rd
exit

# 7. Настройка NAT
interface isp
 ip nat outside
exit

interface vl100 
 ip nat inside
exit

interface vl200
 ip nat inside
exit

interface vl999
 ip nat inside
exit

ip nat pool HQ 192.168.100.1-192.168.100.254
ip nat source dynamic inside-to-outside pool HQ overload interface isp

# 8. Настройка DHCP сервера
dhcp-server 1
 ip pool HQ 192.168.100.66-192.168.100.78
 exit
 pool HQ 1
  mask 28
  gateway 192.168.100.65
  dns 192.168.100.2
  domain-name au-team.irpo
 exit
exit

interface vl200 
 dhcp-server 1
exit

# 9. Настройка времени
ntp timezone utc+3

# Сохранение конфигурации
write memory
EOF

echo "Настройка HQ-RTR завершена."