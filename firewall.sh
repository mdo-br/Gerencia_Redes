#!/bin/bash
# ================================================================
#  FIREWALL DO LABORATÓRIO DE SEGURANÇA - Ubuntu Server
#  Descrição:
#     Configura NAT, DNAT e roteamento entre LAN, DMZ e Internet.
#     Compatível com ambiente VMware/VirtualBox com 3 interfaces:
#       enp0s3 -> Internet (Bridge ou NAT)
#       enp0s8 -> LAN (192.168.56.0/24)
#       enp0s9 -> DMZ (192.168.57.0/24)
# ================================================================

echo "[+] Ativando roteamento IPv4..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null
sed -i '/^#*net.ipv4.ip_forward/c\net.ipv4.ip_forward=1' /etc/sysctl.conf

echo "[+] Limpando regras antigas..."
iptables -F
iptables -t nat -F
iptables -X

echo "[+] Definindo políticas padrão (DROP - segurança)..."
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

echo "[+] Permitindo tráfego de loopback..."
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

echo "[+] Permitindo conexões estabelecidas e relacionadas..."
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "[+] Permitindo SSH para administração do firewall..."
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

echo "[+] Configurando NAT (masquerade) para LAN e DMZ..."
iptables -t nat -A POSTROUTING -s 192.168.56.0/24 -o enp0s3 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.57.0/24 -o enp0s3 -j MASQUERADE

echo "[+] Configurando DNAT (porta 80 -> Webserver da DMZ)..."
iptables -t nat -A PREROUTING -i enp0s3 -p tcp --dport 80 -j DNAT --to-destination 192.168.57.10:80

echo "[+] Regras de encaminhamento (FORWARD)..."
# LAN → Internet
iptables -A FORWARD -i enp0s8 -o enp0s3 -j ACCEPT
# DMZ → Internet
iptables -A FORWARD -i enp0s9 -o enp0s3 -j ACCEPT
# Internet → LAN/DMZ (somente respostas)
iptables -A FORWARD -i enp0s3 -o enp0s8 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i enp0s3 -o enp0s9 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "[+] Salvando regras para persistência..."
apt-get install -y iptables-persistent > /dev/null 2>&1
netfilter-persistent save

echo "[+] Firewall configurado com sucesso!"
iptables -L -v -n
iptables -t nat -L -v -n
