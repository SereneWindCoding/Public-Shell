#!/usr/bin/env bash

iptables -A INPUT -p udp --dport 80 -j REJECT --reject-with icmp-port-unreachable
iptables -A INPUT -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable

yes "" | apt-get install iptables-persistent

printf "\n\n###########################################\n部署完成\n###########################################\n\n"