#!/usr/bin/env bash

timedatectl set-timezone Asia/Shanghai
htpdate -s www.baidu.com
hwclock -w

echo "时间同步完成完成"