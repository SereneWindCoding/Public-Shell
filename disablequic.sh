#!/usr/bin/env bash

apt-get install iptables -y
iptables -A INPUT -p udp --dport 80 -j REJECT --reject-with icmp-port-unreachable
iptables -A INPUT -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable

apt-get install iptables-persistent -y
netfilter-persistent save

printf "\n\n###########################################\n部署完成\n###########################################\n\n"