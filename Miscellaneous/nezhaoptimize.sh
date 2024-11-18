#!/bin/bash

# 字体颜色配置
Green="\033[32m"
Font="\033[0m"

echo -e "${Green}开始配置${Font}"

# 修改 ExecStart 行，添加所需参数
sed -i '/ExecStart/s/$/ --skip-conn --skip-procs --disable-auto-update --disable-force-update --disable-command-execute/' /etc/systemd/system/nezha-agent.service

# 重载 systemd 配置并重启服务
systemctl daemon-reload
systemctl restart nezha-agent.service

echo -e "${Green}配置完成${Font}"