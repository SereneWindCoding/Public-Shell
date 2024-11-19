#!/bin/bash
# 配置参数
THRESHOLD=1024                          # 内存空余阈值（单位：MB）
COMMAND="soga restart"                  # 重启服务命令
LOG_FILE="/var/log/soga_memory_monitor.log"  # 日志文件路径
LOCK_FILE="/var/run/soga_monitor.lock"  # 锁文件路径
RESTART_COOLDOWN=600                    # 重启冷却时间(秒)，设置为10分钟
LOG_DAYS=7                             # 日志保留天数

# 检查是否以root权限运行
if [ "$(id -u)" != "0" ]; then
   echo "此脚本需要root权限" 
   exit 1
fi

# 创建日志目录（如果不存在）
mkdir -p "$(dirname "$LOG_FILE")"

# 清理7天前的日志内容
cleanup_old_logs() {
    if [ -f "$LOG_FILE" ]; then
        # 获取7天前的时间戳
        CUTOFF_DATE=$(date -d "7 days ago" +%Y-%m-%d)
        # 创建临时文件
        TEMP_LOG=$(mktemp)
        # 只保留7天内的日志
        sed -n "/^\[${CUTOFF_DATE}/,\$p" "$LOG_FILE" > "$TEMP_LOG"
        # 替换原文件
        mv "$TEMP_LOG" "$LOG_FILE"
    fi
}

# 获取锁，防止多个实例同时运行
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "另一个实例正在运行"
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"

# 记录日志
log_message() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1" >> "$LOG_FILE"
}

# 清理锁文件
trap 'rm -f "$LOCK_FILE"' EXIT

# 清理旧日志（每天凌晨执行一次）
if [ "$(date +%H:%M)" = "00:00" ]; then
    cleanup_old_logs
fi

# 获取当前空余内存（单位：MB）
FREE_MEMORY=$(free -m | awk '/^Mem:/{print $7}')

# 检查上次重启时间
if [ -f "/tmp/last_restart" ]; then
    last_restart=$(cat "/tmp/last_restart")
    now=$(date +%s)
    if [ $((now - last_restart)) -lt "$RESTART_COOLDOWN" ]; then
        log_message "距离上次重启时间不足 ${RESTART_COOLDOWN} 秒，跳过本次检查"
        exit 0
    fi
fi

# 检查内存是否低于阈值
if [ "$FREE_MEMORY" -lt "$THRESHOLD" ]; then
    log_message "内存不足: 当前空余内存 ${FREE_MEMORY}MB，小于阈值 ${THRESHOLD}MB"
    
    # 执行重启命令
    log_message "正在重启服务：soga..."
    if $COMMAND; then
        log_message "服务 soga 已成功重启"
        date +%s > "/tmp/last_restart"
    else
        log_message "服务 soga 重启失败，请检查系统状态！"
    fi
else
    log_message "内存正常: 当前空余内存 ${FREE_MEMORY}MB，大于阈值 ${THRESHOLD}MB"
fi