#!/usr/bin/env bash
# 设置严格模式
set -euo pipefail
IFS=$'\n\t'

# 检查root权限
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root权限运行" 
   exit 1
fi

# 颜色定义
CSI=$(echo -e "\033[")
CEND="${CSI}0m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"
CCYAN="${CSI}1;36m"

# 输出函数
OUT_ALERT() {
   echo -e "${CYELLOW}[警告] $1 ${CEND}"
}
OUT_ERROR() {
   echo -e "${CRED}[错误] $1 ${CEND}"
}
OUT_INFO() {
   echo -e "${CCYAN}[信息] $1 ${CEND}"
}
OUT_SUCCESS() {
   echo -e "${CGREEN}[成功] $1 ${CEND}"
}
OUT_DEBUG() {
   echo -e "${CBLUE}[调试] $1 ${CEND}"
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
       OUT_ERROR "未知的系统类型，仅支持 Debian/Ubuntu/CentOS/Red Hat/Fedora 系列！"
       exit 1
   fi
   OUT_INFO "检测到系统：${os_name} ${os_version}"
}

# 系统更新
update_system() {
   OUT_ALERT "正在更新系统..."
   case $os_name in
       ubuntu|debian)
           apt update -y || OUT_ERROR "apt update 失败"
           apt dist-upgrade -y || OUT_ERROR "apt upgrade 失败"
           apt autoremove --purge -y || OUT_ERROR "apt autoremove 失败"
           ;;
       centos|fedora|rhel)
           yum update -y || OUT_ERROR "yum update 失败"
           yum autoremove -y || OUT_ERROR "yum autoremove 失败"
           ;;
       *)
           OUT_ERROR "系统更新不支持此操作系统：$os_name"
           exit 1
           ;;
   esac
}

# 设置网络参数
configure_network_parameters() {
   OUT_ALERT "正在优化网络参数..."
   local sysctl_file="/etc/sysctl.d/99-custom-net.conf"
   
   # 检查目录
   if [[ ! -d /etc/sysctl.d ]]; then
       OUT_ERROR "/etc/sysctl.d 目录不存在"
       exit 1
   fi

   # 备份原配置
   if [[ -f $sysctl_file ]]; then
       cp "$sysctl_file" "${sysctl_file}.bak.$(date +%Y%m%d%H%M%S)"
       OUT_DEBUG "已备份原配置文件"
   fi

   # 创建新配置
   cat > "$sysctl_file" << EOF
# 网络性能优化参数
# Created: $(date +%Y-%m-%d)
# For: International Web Server to Asia users

# TCP 基础参数
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.netfilter.nf_conntrack_max = 2000000

# TCP 缓冲区
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 87380 16777216
net.ipv4.tcp_mem = 786432 1048576 26777216

# TCP 连接优化
net.ipv4.tcp_max_tw_buckets = 262144
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_slow_start_after_idle = 0

# TCP keepalive 参数
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3

# TCP Fast Open
net.ipv4.tcp_fastopen = 3

# 连接跟踪
net.netfilter.nf_conntrack_tcp_timeout_established = 1800
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 60

# 其他优化
net.core.optmem_max = 16777216
EOF

   # 应用配置
   if ! sysctl --system > /dev/null 2>&1; then
       OUT_ERROR "sysctl配置验证失败！正在回滚..."
       if [[ -f "${sysctl_file}.bak" ]]; then
           mv "${sysctl_file}.bak" "$sysctl_file"
       fi
       exit 1
   fi
   OUT_SUCCESS "网络参数配置完成"
}

# 系统限制优化
configure_system_limits() {
   OUT_ALERT "正在优化系统限制..."
   local limits_file="/etc/security/limits.d/99-custom-limits.conf"
   
   # 获取nginx运行用户
   local nginx_user
   if command -v nginx >/dev/null 2>&1; then
       nginx_user=$(ps aux | grep "nginx: master" | grep -v grep | awk '{print $1}' | head -1)
   fi
   
   OUT_DEBUG "检测到 Nginx 运行用户: ${nginx_user:-未检测到}"

   # 备份原配置
   if [[ -f $limits_file ]]; then
       cp "$limits_file" "${limits_file}.bak.$(date +%Y%m%d%H%M%S)"
   fi

   # 创建基础配置
   cat > "$limits_file" << EOF
# 系统限制参数优化
# Created: $(date +%Y-%m-%d)
# For: High Performance Web Server

# 全局限制
* soft nofile 2000000
* hard nofile 2000000
* soft nproc 65535
* hard nproc 65535
* soft stack 16384
* hard stack 16384
EOF

   # 如果找到nginx用户，添加特定限制
   if [[ -n "$nginx_user" ]]; then
       cat >> "$limits_file" << EOF

# Nginx user specific limits
$nginx_user soft nofile 2000000
$nginx_user hard nofile 2000000
EOF
       OUT_SUCCESS "已为 Nginx 用户 ($nginx_user) 添加特定限制"
   else
       OUT_ALERT "未检测到 Nginx 用户，仅应用全局限制"
   fi
}

# 检查并加载必要的内核模块
load_kernel_modules() {
   OUT_ALERT "检查并加载内核模块..."
   local modules=(
       "nf_conntrack"
   )

   # 创建模块加载配置
   local modules_file="/etc/modules-load.d/custom-modules.conf"
   
   for mod in "${modules[@]}"; do
       if ! lsmod | grep -q "^$mod"; then
           modprobe "$mod" || OUT_ERROR "加载 $mod 模块失败"
       fi
       echo "$mod" >> "$modules_file"
   done
   OUT_SUCCESS "内核模块加载完成"
}

# 优化验证
verify_optimization() {
   OUT_ALERT "验证优化结果..."
   local check_failed=0

   local params=(
       "net.ipv4.tcp_max_syn_backlog:65535"
       "net.core.somaxconn:65535"
       "net.ipv4.tcp_tw_reuse:1"
       "net.core.rmem_max:16777216"
       "net.ipv4.tcp_fastopen:3"
   )

   for param in "${params[@]}"; do
       local name="${param%:*}"
       local expected="${param#*:}"
       local actual
       actual=$(sysctl -n "$name")
       if [[ "$actual" != "$expected" ]]; then
           OUT_ERROR "$name = $actual (期望值: $expected)"
           check_failed=1
       fi
   done

   # 检查文件描述符限制
   local nofile_soft
   nofile_soft=$(ulimit -Sn)
   if [[ "$nofile_soft" -lt 2000000 ]]; then
       OUT_ERROR "软文件描述符限制未正确设置：$nofile_soft (应为 2000000)"
       check_failed=1
   fi

   if [[ $check_failed -eq 1 ]]; then
       OUT_ERROR "部分参数未正确设置，请检查系统日志"
   else
       OUT_SUCCESS "所有参数已正确设置"
   fi
}

# 主函数
main() {
   OUT_INFO "开始系统优化..."
   detect_system
   update_system
   load_kernel_modules
   configure_network_parameters
   configure_system_limits
   verify_optimization
   
   OUT_SUCCESS "系统优化完成！"
   OUT_INFO "请使用 'reboot' 命令重启系统以应用所有更改。"
   OUT_INFO "重启后可以使用 'sysctl -a' 命令检查参数是否生效。"
}

# 执行主函数
main
exit 0