#!/bin/bash

# 字体颜色配置
Green="\033[32m"
Font="\033[0m"

echo -e ${Green}开始配置${Font}

sed -i '/ExecStart/s/$/ --skip-conn --skip-procs/' /etc/systemd/system/nezha-agent.service
systemctl daemon-reload
systemctl restart nezha-agent.service

echo -e ${Green}配置完成${Font}