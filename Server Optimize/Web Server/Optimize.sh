#!/usr/bin/env bash

# 设置严格模式
set -euo pipefail

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo "此脚本必须以root权限运行" 
    exit 1
fi

# 颜色定义
CSI=$(echo -e "\033[")
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
detect_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        os_name=$ID
        os_version=$VERSION_ID
    elif [[ -f /etc/redhat-release ]]; then
        os_name="centos"
        os_version=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))
    elif [[ -f /etc/debian_version ]]; then
        os_name="debian"
        os_version=$(cat /etc/debian_version)
    else
        OUT_ERROR "[错误] 未知的系统类型，仅支持 Debian/Ubuntu/CentOS/Red Hat/Fedora 系列！"
        exit 1
    fi

    OUT_INFO "[信息] 检测到系统：${os_name} ${os_version}"
}

# 系统更新
update_system() {
    OUT_ALERT "[信息] 正在更新系统..."
    case $os_name in
        ubuntu|debian)
            apt update && apt dist-upgrade -y && apt autoremove --purge -y
            ;;
        centos|fedora|rhel)
            yum update -y && yum autoremove -y
            ;;
        *)
            OUT_ERROR "[错误] 系统更新不支持此操作系统：$os_name"
            exit 1
            ;;
    esac
}

# 设置网络参数
configure_network_parameters() {
    OUT_ALERT "[信息] 正在优化网络参数..."
    sysctl_file="/etc/sysctl.d/custom.conf"

    # 不同系统支持的参数可能不同
    case $os_name in
        ubuntu|debian)
            cat > $sysctl_file << 'EOF'
# 通用网络参数
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.netfilter.nf_conntrack_max = 2000000
EOF
            ;;
        centos|fedora|rhel)
            cat > $sysctl_file << 'EOF'
# 通用网络参数
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.netfilter.nf_conntrack_max = 1000000
EOF
            ;;
        *)
            OUT_ERROR "[错误] 不支持的系统网络优化：$os_name"
            exit 1
            ;;
    esac

    sysctl --system || OUT_ERROR "[错误] 应用网络参数失败！"
}

# 系统限制优化
configure_system_limits() {
    OUT_ALERT "[信息] 正在优化系统限制..."
    limits_file="/etc/security/limits.d/custom-limits.conf"

    cat > $limits_file << 'EOF'
# 文件描述符限制
* soft nofile 2000000
* hard nofile 2000000
* soft nproc 65535
* hard nproc 65535
EOF
}

# 检查并加载内核模块
load_kernel_modules() {
    OUT_ALERT "[信息] 检查并加载内核模块..."
    if ! lsmod | grep -q '^nf_conntrack'; then
        modprobe nf_conntrack || OUT_ERROR "[错误] 加载nf_conntrack模块失败！"
    fi
}

# 主函数
main() {
    detect_system
    update_system
    configure_network_parameters
    configure_system_limits
    load_kernel_modules
    OUT_INFO "[信息] 系统优化完成！"
    OUT_INFO "[信息] 请使用 'reboot' 命令重启系统以应用所有更改。"
}

main
exit 0
