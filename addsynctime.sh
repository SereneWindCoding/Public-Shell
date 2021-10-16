#!/usr/bin/env bash

printf "\n\n###########################################\n时间同步脚本\n###########################################\n\n"

wget -P /etc/cuocuo/ -N --no-check-certificate https://cdn.jsdelivr.net/gh/SereneWindCoding/Public-Shell@main/synctime.sh

printf "\n\n###########################################\n设置Crontab命令\n###########################################\n\n"

cat >> /var/spool/cron/crontabs/root <<EOF
30 2 * * * bash /etc/cuocuo/synctime.sh
EOF

printf "\n\n###########################################\n配置完成\n###########################################\n\n"