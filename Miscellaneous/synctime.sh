#!/usr/bin/env bash

# 设置严格模式
set -euo pipefail

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 脚本路径和名称定义
SCRIPT_PATH="/usr/local/bin"
SCRIPT_NAME="timesync.sh"
FULL_SCRIPT_PATH="${SCRIPT_PATH}/${SCRIPT_NAME}"
LOG_FILE="/var/log/timesync.log"

# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] 错误: $1${NC}" >&2 | tee -a "$LOG_FILE"
    exit 1
}

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    error "此脚本需要root权限运行"
fi

# 定义时区配置
declare -A TIMEZONE_CONFIGS
TIMEZONE_CONFIGS=(
    ["shanghai"]="Asia/Shanghai"
    ["chicago"]="America/Chicago"
)

# 定义不同地区的NTP服务器
declare -A SERVER_CONFIGS
SERVER_CONFIGS=(
    ["shanghai"]="www.baidu.com www.taobao.com www.qq.com"
    ["chicago"]="www.google.com www.amazon.com www.microsoft.com"
)

# 使用说明
usage() {
    cat << EOF
使用方法: $(basename "$0") [选项]

选项:
    -z, --zone <zone>     选择时区 (shanghai 或 chicago)
    -i, --install         安装服务和定时任务
    -h, --help           显示此帮助信息

示例:
    $(basename "$0") -z shanghai         # 同步到上海时区
    $(basename "$0") -z chicago          # 同步到芝加哥时区
    $(basename "$0") -i                  # 安装服务和定时任务
EOF
    exit 1
}

# 安装必要的包
install_packages() {
    log "更新软件包并安装必要组件..."
    apt-get update -y || error "更新软件包失败"
    apt-get install -y htpdate || error "安装htpdate失败"
}

# 同步时间
sync_time() {
    local zone=$1
    local timezone=${TIMEZONE_CONFIGS[$zone]}
    local servers=(${SERVER_CONFIGS[$zone]})
    
    # 设置时区
    log "设置时区为 $timezone..."
    if ! timedatectl set-timezone "$timezone"; then
        error "时区设置失败"
    fi
    
    # 尝试同步时间
    local sync_successful=false
    for server in "${servers[@]}"; do
        log "正在尝试从 $server 同步时间..."
        if htpdate -s "$server"; then
            sync_successful=true
            log "成功从 $server 同步时间"
            break
        else
            log "从 $server 同步失败，尝试下一个服务器..."
        fi
    done
    
    if ! $sync_successful; then
        error "所有服务器时间同步都失败"
    fi
    
    # 更新硬件时钟
    log "更新硬件时钟..."
    if ! hwclock -w; then
        error "硬件时钟更新失败"
    fi
    
    # 显示当前时间信息
    log "时间同步完成!"
    echo "当前系统时间: $(date)"
    echo "当前硬件时间: $(hwclock -r)"
}

# 安装服务和定时任务
install_service() {
    log "安装时间同步服务..."
    
    # 复制脚本到系统目录
    cp -f "$0" "$FULL_SCRIPT_PATH"
    chmod +x "$FULL_SCRIPT_PATH"
    
    # 创建配置文件保存默认时区
    local config_file="/etc/timesync.conf"
    echo "TIMEZONE=${timezone:-shanghai}" > "$config_file"
    
    # 设置定时任务
    local cron_job="0 5 * * * root $FULL_SCRIPT_PATH -z \$(cat $config_file | cut -d= -f2) >> $LOG_FILE 2>&1"
    echo "$cron_job" > "/etc/cron.d/timesync"
    chmod 644 "/etc/cron.d/timesync"
    
    # 设置日志轮转
    cat > "/etc/logrotate.d/timesync" << EOF
$LOG_FILE {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF
    
    # 重启 crond 服务
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart crond.service || systemctl restart cron.service
    else
        service cron restart || service crond restart
    fi
    
    log "服务安装完成！"
    echo -e "\n${GREEN}配置信息：${NC}"
    echo "1. 脚本位置: $FULL_SCRIPT_PATH"
    echo "2. 日志文件: $LOG_FILE"
    echo "3. 配置文件: $config_file"
    echo "4. 定时执行: 每天早上 5:00"
    echo "5. 日志轮转: 每周轮转，保留4周"
}

# 主函数
main() {
    local timezone=""
    local install_mode=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -z|--zone)
                timezone="$2"
                shift 2
                ;;
            -i|--install)
                install_mode=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                error "未知参数: $1"
                ;;
        esac
    done
    
    # 检查参数
    if $install_mode; then
        install_packages
        install_service
    elif [[ -n "$timezone" ]]; then
        if [[ ! ${TIMEZONE_CONFIGS[$timezone]+_} ]]; then
            error "不支持的时区: $timezone"
        fi
        install_packages
        sync_time "$timezone"
    else
        usage
    fi
}

# 运行主函数
main "$@"