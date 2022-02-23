#!/bin/bash

# 删除除当天之外的日志
yy=`date +%Y`
mm=`date +%m`
dd=`date +%d`
# 日志路径
log_path="/etc/soga/access_log"

if  [ -d "${log_path}" ]; then
/usr/bin/find "${log_path}"/* -not -name "access_log_${yy}_${mm}_${dd}.csv" | xargs rm -rf
fi