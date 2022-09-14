#!/usr/bin/env bash

printf "\n\n###########################################\n更换系统DNS\n###########################################\n\n"

mv /etc/resolv.conf /etc/resolv.conf.link
chattr -i /etc/resolv.conf
echo "nameserver 223.5.5.5" > /etc/resolv.conf
echo "nameserver 223.6.6.6" >> /etc/resolv.conf
chattr +i /etc/resolv.conf

printf "\n\n###########################################\n系统更新\n###########################################\n\n"

apt update -y
apt-get upgrade -y

printf "\n\n###########################################\n安装依赖\n###########################################\n\n"

apt-get install -y wget net-tools iperf3 curl nano sudo screen dnsutils nload htop mtr tcptraceroute jq

printf "\n\n###########################################\n系统优化\n###########################################\n\n"

bash <(curl -L https://cdn.jsdelivr.net/gh/SereneWindCoding/Public-Shell@main/CNOptimize/optimize.sh)