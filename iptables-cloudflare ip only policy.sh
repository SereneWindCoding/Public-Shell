#!/bin/bash

# 设置严格模式
set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}此脚本必须以root权限运行${NC}"
    exit 1
fi

# 检查系统类型
check_system() {
    if [ -f /etc/debian_version ]; then
        if [ -f /etc/lsb-release ]; then
            echo -e "${GREEN}检测到 Ubuntu 系统${NC}"
            SYSTEM="ubuntu"
        else
            echo -e "${GREEN}检测到 Debian 系统${NC}"
            SYSTEM="debian"
        fi
    elif [ -f /etc/redhat-release ]; then
        echo -e "${GREEN}检测到 RHEL/CentOS 系统${NC}"
        SYSTEM="rhel"
    elif [ -f /etc/arch-release ]; then
        echo -e "${GREEN}检测到 Arch Linux 系统${NC}"
        SYSTEM="arch"
    elif [ -f /etc/fedora-release ]; then
        echo -e "${GREEN}检测到 Fedora 系统${NC}"
        SYSTEM="fedora"
    else
        echo -e "${YELLOW}未能精确识别系统类型，将使用通用配置${NC}"
        SYSTEM="generic"
    fi
}

# 检查并安装必要工具
check_requirements() {
    local missing_tools=()
    
    # 检查基本工具
    for tool in curl iptables ip6tables; do
        if ! command -v $tool >/dev/null 2>&1; then
            missing_tools+=($tool)
        fi
    done
    
    # 根据不同系统安装缺失工具和持久化包
    case $SYSTEM in
        "debian"|"ubuntu")
            apt-get update >/dev/null 2>&1
            if [ ${#missing_tools[@]} -ne 0 ]; then
                apt-get install -y ${missing_tools[*]}
            fi
            # 安装持久化包
            if ! dpkg -l | grep -q "iptables-persistent"; then
                echo -e "${YELLOW}正在安装 iptables-persistent...${NC}"
                DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
            fi
            ;;
        "rhel"|"fedora")
            if [ ${#missing_tools[@]} -ne 0 ]; then
                yum -y install ${missing_tools[*]}
            fi
            # 安装持久化包
            if ! rpm -q iptables-services >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装 iptables-services...${NC}"
                yum -y install iptables-services
                systemctl enable iptables ip6tables
                systemctl start iptables ip6tables
            fi
            ;;
        "arch")
            if [ ${#missing_tools[@]} -ne 0 ]; then
                pacman -Sy --noconfirm ${missing_tools[*]}
            fi
            if ! pacman -Qs iptables >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装 iptables...${NC}"
                pacman -Sy --noconfirm iptables
            fi
            ;;
    esac
}

# 下载Cloudflare IP列表
download_cf_ips() {
    local type=$1
    local tmp_file=""
    
    if [ "$type" = "v4" ]; then
        tmp_file="/tmp/cf_ipv4.txt"
        echo -e "${YELLOW}正在下载 Cloudflare IPv4 列表...${NC}"
        curl -s https://www.cloudflare.com/ips-v4 -o "$tmp_file"
    else
        tmp_file="/tmp/cf_ipv6.txt"
        echo -e "${YELLOW}正在下载 Cloudflare IPv6 列表...${NC}"
        curl -s https://www.cloudflare.com/ips-v6 -o "$tmp_file"
    fi
    
    if [ ! -s "$tmp_file" ]; then
        echo -e "${RED}下载的 IP 列表为空${NC}"
        exit 1
    fi
}

# 配置防火墙规则
configure_firewall() {
    echo -e "${YELLOW}正在配置防火墙规则...${NC}"
    
    # 备份当前规则
    mkdir -p /etc/iptables/backup
    iptables-save > /etc/iptables/backup/rules.v4.$(date +%Y%m%d_%H%M%S)
    ip6tables-save > /etc/iptables/backup/rules.v6.$(date +%Y%m%d_%H%M%S)
    
    # 配置IPv4规则
    echo -e "${YELLOW}配置 IPv4 规则...${NC}"
    
    # 清除现有规则
    iptables -F
    iptables -X
    iptables -Z
    
    # 设置默认策略
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    # 允许已建立的连接和本地连接
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    
    # 允许SSH（防止锁定）
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # 允许Cloudflare IP
    while IFS= read -r ip; do
        [[ -n "$ip" ]] && iptables -A INPUT -s "$ip" -p tcp -m multiport --dports 80,443 -j ACCEPT
    done < /tmp/cf_ipv4.txt
    
    # 阻止其他HTTP/HTTPS访问
    iptables -A INPUT -p tcp -m multiport --dports 80,443 -j DROP
    
    # 配置IPv6规则
    echo -e "${YELLOW}配置 IPv6 规则...${NC}"
    
    # 清除现有规则
    ip6tables -F
    ip6tables -X
    ip6tables -Z
    
    # 设置默认策略
    ip6tables -P INPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
    ip6tables -P OUTPUT ACCEPT
    
    # 允许已建立的连接和本地连接
    ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A INPUT -i lo -j ACCEPT
    
    # 允许SSH（防止锁定）
    ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # 允许Cloudflare IPv6
    while IFS= read -r ip; do
        [[ -n "$ip" ]] && ip6tables -A INPUT -s "$ip" -p tcp -m multiport --dports 80,443 -j ACCEPT
    done < /tmp/cf_ipv6.txt
    
    # 阻止其他HTTP/HTTPS访问
    ip6tables -A INPUT -p tcp -m multiport --dports 80,443 -j DROP
}

# 确保规则持久化
ensure_persistence() {
    echo -e "${YELLOW}正在确保规则持久化...${NC}"
    
    case $SYSTEM in
        "debian")
            # Debian 使用 netfilter-persistent
            mkdir -p /etc/iptables
            iptables-save > /etc/iptables/rules.v4
            ip6tables-save > /etc/iptables/rules.v6
            
            # 启用 netfilter-persistent 服务
            systemctl enable netfilter-persistent
            systemctl restart netfilter-persistent
            ;;
            
        "ubuntu")
            # Ubuntu 使用 iptables-persistent
            mkdir -p /etc/iptables
            iptables-save > /etc/iptables/rules.v4
            ip6tables-save > /etc/iptables/rules.v6
            
            # 启用 iptables-persistent 服务
            systemctl enable iptables-persistent
            systemctl restart iptables-persistent
            ;;
            
        "rhel"|"fedora")
            # RHEL/CentOS 使用 iptables-services
            service iptables save
            service ip6tables save
            
            systemctl enable iptables
            systemctl enable ip6tables
            systemctl restart iptables
            systemctl restart ip6tables
            ;;
            
        *)
            # 通用系统采用启动脚本方案
            mkdir -p /etc/iptables
            iptables-save > /etc/iptables/rules.v4
            ip6tables-save > /etc/iptables/rules.v6
            
            # 创建通用启动脚本
            mkdir -p /etc/network/if-pre-up.d/
            cat > /etc/network/if-pre-up.d/iptables << 'EOF'
#!/bin/sh
/sbin/iptables-restore < /etc/iptables/rules.v4
/sbin/ip6tables-restore < /etc/iptables/rules.v6
EOF
            chmod +x /etc/network/if-pre-up.d/iptables
            ;;
    esac
    
    # 添加双重保险（对所有系统）
    mkdir -p /etc/network/if-pre-up.d/
    cat > /etc/network/if-pre-up.d/iptables << 'EOF'
#!/bin/sh
if [ -f /etc/iptables/rules.v4 ]; then
    /sbin/iptables-restore < /etc/iptables/rules.v4
fi
if [ -f /etc/iptables/rules.v6 ]; then
    /sbin/ip6tables-restore < /etc/iptables/rules.v6
fi
EOF
    chmod +x /etc/network/if-pre-up.d/iptables
}

# 验证规则
verify_rules() {
    echo -e "${YELLOW}验证防火墙规则配置...${NC}"
    
    case $SYSTEM in
        "debian")
            if systemctl is-active netfilter-persistent >/dev/null 2>&1; then
                echo -e "${GREEN}netfilter-persistent 服务运行中${NC}"
            else
                echo -e "${RED}netfilter-persistent 服务未运行${NC}"
                return 1
            fi
            ;;
        "ubuntu")
            if systemctl is-active iptables-persistent >/dev/null 2>&1; then
                echo -e "${GREEN}iptables-persistent 服务运行中${NC}"
            else
                echo -e "${RED}iptables-persistent 服务未运行${NC}"
                return 1
            fi
            ;;
        "rhel"|"fedora")
            if systemctl is-active iptables >/dev/null 2>&1; then
                echo -e "${GREEN}iptables 服务运行中${NC}"
            else
                echo -e "${RED}iptables 服务未运行${NC}"
                return 1
            fi
            ;;
    esac
    
    # 检查规则文件
    if [ -f /etc/iptables/rules.v4 ] && [ -f /etc/iptables/rules.v6 ]; then
        echo -e "${GREEN}规则文件已保存${NC}"
        # 显示当前规则
        echo -e "${GREEN}当前IPv4规则：${NC}"
        iptables -L INPUT -n -v | grep -E "80|443"
        echo -e "${GREEN}当前IPv6规则：${NC}"
        ip6tables -L INPUT -n -v | grep -E "80|443"
    else
        echo -e "${RED}规则文件未找到${NC}"
        return 1
    fi
}

# 清理临时文件
cleanup() {
    rm -f /tmp/cf_ipv4.txt /tmp/cf_ipv6.txt
}

# 主函数
main() {
    echo -e "${GREEN}开始配置 Cloudflare IP 防护...${NC}"
    
    check_system
    check_requirements
    
    # 下载IP列表
    download_cf_ips "v4"
    download_cf_ips "v6"
    
    # 配置防火墙
    configure_firewall
    
    # 确保持久化
    ensure_persistence
    
    # 验证配置
    verify_rules
    
    # 清理
    cleanup
    
    echo -e "${GREEN}Cloudflare IP 防护配置完成！${NC}"
    echo -e "${YELLOW}规则备份保存在 /etc/iptables/backup/ 目录下${NC}"
    echo -e "${GREEN}请重启系统以验证规则是否正确持久化${NC}"
}

main

exit 0