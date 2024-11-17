#!/usr/bin/env bash

# 启用严格模式
set -euo pipefail

# 定义日志文件
LOG_FILE="/var/log/server-optimization.log"
BACKUP_DIR="/root/system_backup"
NIC_CHECK_FILE="/var/log/network-check.log"

# 定义颜色输出
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
OUT_ALERT() { echo -e "${CYELLOW} $1 ${CEND}" | tee -a "$LOG_FILE"; }
OUT_ERROR() { echo -e "${CRED} $1 ${CEND}" | tee -a "$LOG_FILE"; }
OUT_INFO() { echo -e "${CCYAN} $1 ${CEND}" | tee -a "$LOG_FILE"; }
OUT_SUCCESS() { echo -e "${CGREEN} $1 ${CEND}" | tee -a "$LOG_FILE"; }

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        OUT_ERROR "[错误] 此脚本需要root权限运行"
        exit 1
    fi
}

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

# 检查虚拟化环境
check_virtualization() {
    OUT_INFO "[信息] 检查虚拟化环境..."
    
    is_vm=0
    virt_type="none"
    
    # 检查常见虚拟化标志
    if systemd-detect-virt &>/dev/null; then
        virt_type=$(systemd-detect-virt)
        is_vm=1
    elif [ -f "/sys/hypervisor/type" ]; then
        virt_type=$(cat /sys/hypervisor/type)
        is_vm=1
    elif dmesg | grep -i "vmware\|kvm\|qemu\|virtio\|xen\|hyper-v" &>/dev/null; then
        if dmesg | grep -i "vmware" &>/dev/null; then
            virt_type="vmware"
        elif dmesg | grep -i "kvm\|qemu\|virtio" &>/dev/null; then
            virt_type="kvm"
        elif dmesg | grep -i "xen" &>/dev/null; then
            virt_type="xen"
        elif dmesg | grep -i "hyper-v" &>/dev/null; then
            virt_type="hyper-v"
        fi
        is_vm=1
    fi

    if [ $is_vm -eq 1 ]; then
        OUT_INFO "[信息] 检测到虚拟化环境: $virt_type"
    else
        OUT_INFO "[信息] 检测到物理机环境"
    fi
}

# 检查网卡类型
check_nic_type() {
    local interface=$1
    local is_virtio=0
    
    # 检查是否为virtio网卡
    if ethtool -i $interface 2>/dev/null | grep -q "driver: virtio"; then
        is_virtio=1
    elif lspci | grep -i "virtio" | grep -i "network" &>/dev/null; then
        is_virtio=1
    elif dmesg | grep -i "virtio.*network" | grep $interface &>/dev/null; then
        is_virtio=1
    fi
    
    echo $is_virtio
}

# 安装必要工具
install_requirements() {
    OUT_INFO "[信息] 安装必要工具..."
    if [[ ${release} == "centos" ]]; then
        yum install -y epel-release
        yum install -y ethtool wget net-tools curl chrony
    else
        apt-get update
        apt-get install -y ethtool wget net-tools curl chrony
    fi
    OUT_SUCCESS "[成功] 工具安装完成"
}

# 配置DNS - 根据区域选择不同的DNS服务器
configure_dns() {
    OUT_INFO "[信息] 配置系统DNS..."
    
    read -p "是否使用国内DNS？(y/n): " use_cn_dns
    
    # 确保备份目录存在
    BACKUP_DIR="/root/system_backup"
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        mkdir -p "${BACKUP_DIR}" || {
            OUT_ERROR "[错误] 无法创建备份目录：${BACKUP_DIR}"
            exit 1
        }
    fi

    # 检查并移除符号链接或不可修改属性
    if [[ -L /etc/resolv.conf ]]; then
        rm -f /etc/resolv.conf
    elif [[ -f /etc/resolv.conf ]]; then
        chattr -i /etc/resolv.conf 2>/dev/null || true
        mv /etc/resolv.conf "${BACKUP_DIR}/resolv.conf.bak" || {
            OUT_ERROR "[错误] 无法备份 /etc/resolv.conf 文件"
            exit 1
        }
    fi

    # 写入新的 DNS 配置
    if [[ "${use_cn_dns}" =~ ^[Yy]$ ]]; then
        # 国内DNS配置
        cat > /etc/resolv.conf << EOF
options timeout:2 attempts:3 rotate
nameserver 223.5.5.5
nameserver 223.6.6.6
nameserver 119.29.29.29
nameserver 180.76.76.76
EOF
        OUT_INFO "[信息] 已配置国内DNS"
    else
        # 国外DNS配置
        cat > /etc/resolv.conf << EOF
options timeout:2 attempts:3 rotate
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 9.9.9.9
nameserver 208.67.222.222
EOF
        OUT_INFO "[信息] 已配置国际DNS"
    fi

    # 设置文件为不可修改
    chattr +i /etc/resolv.conf || {
        OUT_ERROR "[错误] 无法设置 /etc/resolv.conf 为只读"
        exit 1
    }

    OUT_SUCCESS "[成功] DNS配置完成"
}

# 检查网卡特性和兼容性
declare -A NIC_FEATURES
check_nic_compatibility() {
    local interface=$1
    OUT_INFO "[信息] 检查网卡 $interface 的特性支持情况..."
    
    # 获取网卡基本信息
    local driver=$(ethtool -i $interface 2>/dev/null | grep "^driver:" | cut -d: -f2 | tr -d ' ')
    local version=$(ethtool -i $interface 2>/dev/null | grep "^version:" | cut -d: -f2 | tr -d ' ')
    local firmware=$(ethtool -i $interface 2>/dev/null | grep "^firmware-version:" | cut -d: -f2 | tr -d ' ')
    
    OUT_INFO "网卡信息: 驱动=$driver, 版本=$version, 固件=$firmware"
    
    # 检查各项特性支持
    local features=""
    
    # 检查TSO支持
    if ethtool -k $interface 2>/dev/null | grep -q "tcp-segmentation-offload: on"; then
        features+="tso "
        NIC_FEATURES[$interface]+="tso "
    fi
    
    # 检查GSO支持
    if ethtool -k $interface 2>/dev/null | grep -q "generic-segmentation-offload: on"; then
        features+="gso "
        NIC_FEATURES[$interface]+="gso "
    fi
    
    # 检查GRO支持
    if ethtool -k $interface 2>/dev/null | grep -q "generic-receive-offload: on"; then
        features+="gro "
        NIC_FEATURES[$interface]+="gro "
    fi
    
    # 检查队列大小调整支持
    if ethtool -g $interface &>/dev/null; then
        features+="queue "
        NIC_FEATURES[$interface]+="queue "
    fi
    
    # 检查中断合并支持
    if ethtool -c $interface &>/dev/null; then
        features+="coalesce "
        NIC_FEATURES[$interface]+="coalesce "
    fi
    
    # 输出支持的特性
    OUT_INFO "支持的特性: $features"
    
    # 检查是否是较新的网卡
    local is_modern=0
    if [[ $features == *"tso"* && $features == *"gso"* && $features == *"gro"* ]]; then
        is_modern=1
        OUT_INFO "检测结果: 现代网卡，支持完整优化"
    else
        OUT_INFO "检测结果: 较老的网卡，将使用基础优化"
    fi
    
    # 返回是否是现代网卡
    echo $is_modern
}
# 创建一个开机自动执行的网卡优化脚本
optimize_network() {
    OUT_INFO "[信息] 配置网卡优化..."
    
    # 创建网卡优化脚本
    cat > /etc/network/if-up.d/network-optimize << 'EOF'
#!/bin/bash

# 只在网卡启动时执行优化
[ "$IFACE" = lo ] && exit 0
[ "$MODE" != start ] && exit 0

# 获取网卡类型
is_virtio=0
if ethtool -i $IFACE 2>/dev/null | grep -q "driver: virtio"; then
    is_virtio=1
fi

# 基础优化
ethtool -K $IFACE rx-checksumming on 2>/dev/null || true
ethtool -K $IFACE tx-checksumming on 2>/dev/null || true
ethtool -K $IFACE scatter-gather on 2>/dev/null || true

if [ $is_virtio -eq 1 ]; then
    # virtio网卡优化
    ethtool -K $IFACE gso off 2>/dev/null || true
    ethtool -K $IFACE tso off 2>/dev/null || true
    ethtool -K $IFACE gro off 2>/dev/null || true
    ethtool -C $IFACE rx-usecs 50 tx-usecs 50 2>/dev/null || true
else
    # 物理网卡优化
    if ethtool -k $IFACE | grep -q "tcp-segmentation-offload: on"; then
        ethtool -K $IFACE tso on 2>/dev/null || true
        ethtool -K $IFACE gso on 2>/dev/null || true
    fi
    ethtool -K $IFACE gro off 2>/dev/null || true
    ethtool -G $IFACE rx 4096 tx 4096 2>/dev/null || true
    ethtool -C $IFACE adaptive-rx off adaptive-tx off \
            rx-usecs 100 tx-usecs 100 \
            rx-frames 64 tx-frames 64 2>/dev/null || true
fi

# CPU亲和性优化
if [ -d "/sys/class/net/$IFACE/queues" ]; then
    num_cores=$(nproc)
    core_mask=0
    for ((i=0; i<num_cores; i++)); do
        core_mask=$((core_mask | (1<<i)))
    done
    core_mask=$(printf "%x" $core_mask)
    
    # 设置RPS/XPS
    for rx_queue in /sys/class/net/$IFACE/queues/rx-*/rps_cpus; do
        echo $core_mask > $rx_queue 2>/dev/null || true
    done
    for tx_queue in /sys/class/net/$IFACE/queues/tx-*/xps_cpus; do
        echo $core_mask > $tx_queue 2>/dev/null || true
    done
    
    # 设置RFS
    echo 32768 > /proc/sys/net/core/rps_sock_flow_entries 2>/dev/null || true
    for rx_queue in /sys/class/net/$IFACE/queues/rx-*/rps_flow_cnt; do
        echo 4096 > $rx_queue 2>/dev/null || true
    done
fi

# 关闭流控
ethtool -A $IFACE rx off tx off 2>/dev/null || true
EOF

    # 设置执行权限
    chmod +x /etc/network/if-up.d/network-optimize
    
    # 立即对当前网卡执行优化
    for interface in $(ls /sys/class/net/ | grep -v '^lo$'); do
        IFACE=$interface MODE=start /etc/network/if-up.d/network-optimize
    done
    
    OUT_SUCCESS "[成功] 网卡优化配置完成"
}

# 系统参数优化
optimize_system() {
    OUT_INFO "[信息] 优化系统参数..."
    
    # 配置sysctl参数
    cat > /etc/sysctl.conf << 'EOF'
# 基础网络参数
net.ipv4.ip_forward = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 20
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_tw_buckets = 550000
net.ipv4.tcp_max_syn_backlog = 30000
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3

# TCP内存设置
net.ipv4.tcp_mem = 786432 1048576 1572864
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 87380 33554432
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.netdev_max_backlog = 50000
net.core.somaxconn = 65535

# TCP拥塞控制
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1

# 路由设置
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# 文件描述符限制
fs.file-max = 2097152
fs.nr_open = 2097152
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288
fs.pipe-max-size = 1048576

# 内存参数
vm.swappiness = 10
vm.min_free_kbytes = 65536
vm.overcommit_memory = 1
vm.max_map_count = 262144
EOF

    # 配置系统限制 - 更高的限制
    cat > /etc/security/limits.conf << 'EOF'
* soft nofile 2097152
* hard nofile 2097152
* soft nproc 2097152
* hard nproc 2097152
root soft nofile 2097152
root hard nofile 2097152
root soft nproc 2097152
root hard nproc 2097152
* soft memlock unlimited
* hard memlock unlimited
EOF
    
    # 确保PAM加载limits配置
    if [[ -f /etc/pam.d/common-session ]]; then
        grep -q '^session.*pam_limits.so$' /etc/pam.d/common-session || \
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
    
    # 应用sysctl参数
    sysctl -p
    
    OUT_SUCCESS "[成功] 系统参数优化完成"
}

# 主函数
main() {
    OUT_INFO "[信息] 开始系统优化..."
    
    # 基础检查
    check_root
    check_system
    check_virtualization
    install_requirements
    
    # 系统配置
    configure_dns
    configure_ntp
    
    # 性能优化
    optimize_system
    optimize_network
    
    OUT_SUCCESS "[成功] 系统优化完成！"
    OUT_INFO "[信息] 建议重启系统使所有优化生效"
}

# 运行主函数
main