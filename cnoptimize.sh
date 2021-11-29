#!/usr/bin/env bash

printf "\n\n###########################################\n更换系统DNS\n###########################################\n\n"

chattr -i /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf
chattr +i /etc/resolv.conf

printf "\n\n###########################################\n系统更新\n###########################################\n\n"

apt update -y
apt-get upgrade -y

printf "\n\n###########################################\n安装依赖\n###########################################\n\n"

apt-get install -y wget net-tools iperf3 curl nano sudo screen dnsutils nload htop mtr tcptraceroute jq

printf "\n\n###########################################\n系统优化\n###########################################\n\n"

modprobe ip_conntrack
wget -N --no-check-certificate --header="Authorization: token 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" https://raw.githubusercontent.com/SereneWindCoding/Shell/main/optimize.sh
chmod +x optimize.sh
bash optimize.sh