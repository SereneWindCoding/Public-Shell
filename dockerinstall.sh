#!/usr/bin/env bash

apt update -y
apt-get upgrade -y
curl -fsSL https://get.docker.com -o get-docker.sh
bash get-docker.sh
service docker restart
echo "安装完成"