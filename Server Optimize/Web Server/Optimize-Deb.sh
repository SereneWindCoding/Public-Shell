#!/usr/bin/env bash

# 设置严格模式
set -euo pipefail

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo "此脚本必须以root权限运行" 
    exit 1
fi

# 颜色定义
echo=echo
for cmd in echo /bin/echo; do
    $cmd >/dev/null 2>&1 || continue
    if ! $cmd -e "" | grep -qE '^-e'; then
        echo=$cmd
        break
    fi
done
CSI=$($echo -e "\033[")
CEND="${CSI}0m"
CRED="${CSI}1;31m"
CYELLOW="${CSI}1;33m"
CCYAN="${CSI}1;36m"

# 输出函数
OUT_ALERT() {
    echo -e "${CYELLOW} $1 ${CEND}"
}
OUT_ERROR() {
    echo -e "${CRED} $1 ${CEND}"
}
OUT_INFO() {
    echo -e "${CCYAN} $1 ${CEND}"
}

# 检查系统类型
check_system() {
    if [[ -f /etc/debian_version ]]; then
        release="debian"
    elif [[ -f /etc/lsb-release ]]; then
        release="ubuntu"
    else
        OUT_ERROR "[错误] 仅支持Debian/Ubuntu系统！"
        exit 1
    fi
}

# 系统更新
update_system() {
    OUT_ALERT "[信息] 正在更新系统..."
    if ! apt update; then
        OUT_ERROR "[错误] apt update 失败"
        exit 1
    fi
    if ! apt dist-upgrade -y; then
        OUT_ERROR "[错误] apt dist-upgrade 失败"
        exit 1
    fi
    if ! apt autoremove --purge -y; then
        OUT_ERROR "[错误] apt autoremove 失败"
        exit 1
    fi
}

# 优化系统参数
optimize_system() {
    OUT_ALERT "[信息] 正在优化系统参数..."
    
    # 备份原始配置
    cp /etc/sysctl.conf /etc/sysctl.conf.bak
    cp /etc/security/limits.conf /etc/security/limits.conf.bak
    
    # 设置sysctl参数
    cat > /etc/sysctl.conf << 'EOF'
# 文件描述符限制
fs.file-max = 2000000
fs.inotify.max_user_instances = 65536

# API服务器网络优化
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_timestamps = 1

# 快速回收TIME_WAIT连接
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_max_tw_buckets = 262144

# 连接跟踪优化
net.netfilter.nf_conntrack_max = 2000000
net.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_established = 1800

# API高并发优化
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535

# TCP缓冲区优化
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 87380 16777216

# TIME_WAIT复用优化
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2

# TCP keepalive优化
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3

# TCP内存优化
net.ipv4.tcp_mem = 786432 1048576 1572864
net.ipv4.tcp_moderate_rcvbuf = 1
EOF

    # 设置系统限制
    cat > /etc/security/limits.conf << 'EOF'
# API服务器系统限制优化
* soft nofile 2000000
* hard nofile 2000000
* soft nproc 65535
* hard nproc 65535

# Web服务特定用户配置
www-data soft nofile 2000000
www-data hard nofile 2000000
www-data soft nproc 65535
www-data hard nproc 65535

# Nginx特定配置
nginx soft nofile 2000000
nginx hard nofile 2000000
nginx soft nproc 65535
nginx hard nproc 65535
EOF

    # 加载nf_conntrack模块
    modprobe nf_conntrack || true

    # 应用sysctl参数
    if ! sysctl -p; then
        OUT_ERROR "[错误] 应用sysctl参数失败"
        # 恢复备份
        mv /etc/sysctl.conf.bak /etc/sysctl.conf
        mv /etc/security/limits.conf.bak /etc/security/limits.conf
        exit 1
    fi
}

# 主函数
main() {
    check_system
    update_system
    optimize_system
    OUT_INFO "[信息] 系统优化完成！"
    OUT_INFO "[信息] 建议重启系统以应用所有更改"
}

main
exit 0