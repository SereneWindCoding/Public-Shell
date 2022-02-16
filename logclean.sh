#!/usr/bin/env bash

#获取当前系统年月日
start=$(date +%Y%m%d)

#日志路径
location="/etc/soga/access_log/"

find $location -mtime +3  -name "*.csv" -exec rm -rf {} \;

printf "\n\n###########################################\n部署完成\n###########################################\n\n"