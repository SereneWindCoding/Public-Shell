#!/usr/bin/env bash

# 启用严格模式
set -euo pipefail

# 定义颜色输出函数
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
CDGREEN="${CSI}32m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"
CMAGENTA="${CSI}1;35m"
CCYAN="${CSI}1;36m"

# 输出函数
OUT_ALERT() { echo -e "${CYELLOW} $1 ${CEND}"; }
OUT_ERROR() { echo -e "${CRED} $1 ${CEND}"; }
OUT_INFO() { echo -e "${CCYAN} $1 ${CEND}"; }

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    OUT_ERROR "[错误] 此脚本需要root权限运行"
    exit 1
fi

# 检测系统类型
check_system() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian|raspbian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -q -E -i "raspbian|debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    else
        OUT_ERROR "[错误] 不支持的操作系统！"
        exit 1
    fi
}

# 配置DNS
configure_dns() {
    OUT_INFO "[信息] 配置系统DNS..."
    
    if [[ -L /etc/resolv.conf ]]; then
        rm -f /etc/resolv.conf
    fi
    
    if [[ -f /etc/resolv.conf ]]; then
        mv /etc/resolv.conf /etc/resolv.conf.bak
    fi
    
    chattr -i /etc/resolv.conf 2>/dev/null || true
    
    echo "nameserver 223.5.5.5" > /etc/resolv.conf
    echo "nameserver 223.6.6.6" >> /etc/resolv.conf
    
    chattr +i /etc/resolv.conf
}

# 系统更新
update_system() {
    OUT_INFO "[信息] 更新系统..."
    if [[ ${release} == "centos" ]]; then
        yum makecache
        yum install epel-release -y
        yum update -y
    else
        apt update -y
        apt-get upgrade -y
        apt dist-upgrade -y
        apt autoremove --purge -y
    fi
}

# 安装工具包
install_tools() {
    OUT_INFO "[信息] 安装系统工具..."
    if [[ ${release} == "centos" ]]; then
        yum install -y wget net-tools iperf3 curl nano sudo screen bind-utils nload htop mtr tcptraceroute jq
    else
        apt-get install -y wget net-tools iperf3 curl nano sudo screen dnsutils nload htop mtr tcptraceroute jq
    fi
}

# 安装和配置haveged
configure_haveged() {
    OUT_INFO "[信息] 配置 haveged 服务..."
    if [[ ${release} == "centos" ]]; then
        yum install haveged -y
    else
        apt install haveged -y
    fi
    
    systemctl disable haveged
    systemctl enable haveged
    systemctl restart haveged
}

# 系统参数优化
optimize_system() {
    OUT_INFO "[信息] 优化系统参数..."
    
    # 配置sysctl参数
    cat > /etc/sysctl.conf << 'EOF'
vm.swappiness = 10
fs.file-max = 1000000
net.ipv4.ip_forward = 1
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_mtu_probing = 1
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_thin_linear_timeouts = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.ip_local_port_range= 10000 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
EOF

    # 配置系统限制
    cat > /etc/security/limits.conf << 'EOF'
* soft nofile 512000
* hard nofile 512000
* soft nproc 512000
* hard nproc 512000
root soft nofile 512000
root hard nofile 512000
root soft nproc 512000
root hard nproc 512000
EOF

    # 应用sysctl参数
    sysctl -p
    
    # 配置网络优化服务
    cat > /etc/systemd/system/nettune.service << 'EOF'
[Unit]
After=network.service
[Service]
Type=oneshot
ExecStart=/usr/share/nettune.sh
[Install]
WantedBy=multi-user.target
EOF

    # 创建网络优化脚本
    cat > /usr/share/nettune.sh << 'EOF'
#!/bin/bash
ip r c `ip r|head -n1` initcwnd 10000 initrwnd 10000
EOF

    # 设置执行权限并启用服务
    chmod +x /usr/share/nettune.sh
    systemctl enable --now nettune
}

# 主函数
main() {
    OUT_INFO "[信息] 开始系统初始化..."
    
    check_system
    
    OUT_INFO "[信息] 更换系统DNS..."
    configure_dns
    
    OUT_INFO "[信息] 开始系统更新..."
    update_system
    
    OUT_INFO "[信息] 安装依赖包..."
    install_tools
    
    OUT_INFO "[信息] 开始系统优化..."
    configure_haveged
    optimize_system
    
    OUT_INFO "[信息] 系统初始化完成！"
}

# 运行主函数
main