#!/bin/bash

# 禁止来自IPv4的所有HTTP/S访问请求
iptables -I INPUT -p tcp --dport 80 -j DROP
iptables -I INPUT -p tcp --dport 443 -j DROP

# 对Cloudflare CDN IPv4地址开放HTTP/S入站访问
for i in `curl https://www.cloudflare.com/ips-v4`; do iptables -I INPUT -s $i -p tcp --dport 80 -j ACCEPT; done
for i in `curl https://www.cloudflare.com/ips-v4`; do iptables -I INPUT -s $i -p tcp --dport 443 -j ACCEPT; done

# 禁止来自IPv6的所有HTTP/S访问请求
ip6tables -I INPUT -p tcp --dport 80 -j DROP
ip6tables -I INPUT -p tcp --dport 443 -j DROP

# 对Cloudflare CDN IPv6地址开放HTTP/S入站访问
for i in `curl https://www.cloudflare.com/ips-v6`; do ip6tables -I INPUT -s $i -p tcp --dport 80 -j ACCEPT; done
for i in `curl https://www.cloudflare.com/ips-v6`; do ip6tables -I INPUT -s $i -p tcp --dport 443 -j ACCEPT; done

# 保存iptables配置
iptables-save
ip6tables-save
