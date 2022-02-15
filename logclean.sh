#!/bin/sh

#获取当前系统年月日
start=$(date +%Y%m%d)

#日志路径
location="/etc/soga/access_log/"

find $location -mtime +7  -name "*.log" -exec rm -rf {} \;