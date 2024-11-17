#!/usr/bin/env bash

# 启用严格模式
set -euo pipefail

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] 错误: $1${NC}" >&2
    exit 1
}

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    error "此脚本需要root权限运行"
fi

# 检查必要的命令
check_requirements() {
    local required_commands=("curl" "jq" "wget" "tar")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "安装必要的组件: $cmd"
            apt-get update && apt-get install -y "$cmd" || error "安装 $cmd 失败"
        fi
    done
}

# 获取最新版本
get_latest_version() {
    log "获取最新版本信息..."
    
    # 使用 GitHub API 获取最新版本
    local api_response
    api_response=$(curl -s "https://api.github.com/repos/zhboner/realm/releases/latest") || error "无法连接到 GitHub API"
    
    # 检查是否有错误信息
    if echo "$api_response" | jq -e 'select(.message?)' &>/dev/null; then
        error "GitHub API 返回错误: $(echo "$api_response" | jq -r '.message')"
    fi
    
    # 获取最新版本号
    local latest_version
    latest_version=$(echo "$api_response" | jq -r '.tag_name') || error "解析版本信息失败"
    
    # 获取下载 URL
    local download_url
    download_url=$(echo "$api_response" | jq -r '.assets[] | select(.name | contains("x86_64-unknown-linux-musl")) | .browser_download_url') || error "未找到适合的下载文件"
    
    if [[ -z "$download_url" ]]; then
        error "未找到可下载的文件"
    fi
    
    echo "$download_url"
}

# 下载和安装
install_realm() {
    local download_url=$1
    local temp_dir
    temp_dir=$(mktemp -d)
    log "使用临时目录: $temp_dir"
    
    # 下载文件
    log "下载 Realm..."
    cd "$temp_dir" || error "无法进入临时目录"
    wget -q --show-progress "$download_url" || error "下载失败"
    
    # 解压文件
    log "解压文件..."
    tar -xzf realm-*.tar.gz || error "解压失败"
    
    # 设置权限并移动到目标目录
    log "安装 Realm..."
    chmod +x realm || error "设置执行权限失败"
    mv realm /usr/bin/realm || error "移动文件失败"
    
    # 清理临时文件
    cd / && rm -rf "$temp_dir"
}

# 创建配置目录
setup_configuration() {
    log "创建配置目录..."
    mkdir -p /etc/realm || error "创建配置目录失败"
    
    log "创建 systemd 服务文件..."
    cat > /etc/systemd/system/realm@.service <<EOF || error "创建服务文件失败"
[Unit]
Description=Realm Service
After=network.target

[Service]
Type=simple
LimitCPU=infinity
LimitFSIZE=infinity
LimitDATA=infinity
LimitSTACK=infinity
LimitCORE=infinity
LimitRSS=infinity
LimitNOFILE=infinity
LimitAS=infinity
LimitNPROC=infinity
LimitMEMLOCK=infinity
LimitLOCKS=infinity
LimitSIGPENDING=infinity
LimitMSGQUEUE=infinity
LimitRTPRIO=infinity
LimitRTTIME=infinity
ExecStart=/usr/bin/realm -c /etc/realm/%i.json
Restart=always
RestartSec=4

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载 systemd 配置
    log "重新加载 systemd 配置..."
    systemctl daemon-reload || error "重新加载 systemd 配置失败"
}

# 验证安装
verify_installation() {
    log "验证安装..."
    
    if ! command -v realm &> /dev/null; then
        error "Realm 安装验证失败"
    fi
    
    local version
    version=$(realm -V 2>&1) || error "无法获取 Realm 版本"
    log "已安装 Realm 版本: $version"
}

# 主函数
main() {
    log "开始安装 Realm..."
    
    check_requirements
    local download_url
    download_url=$(get_latest_version)
    install_realm "$download_url"
    setup_configuration
    verify_installation
    
    echo -e "\n${GREEN}###########################################"
    echo "Realm 安装完成！"
    echo -e "###########################################${NC}\n"
    
    # 显示使用说明
    echo -e "${YELLOW}使用说明：${NC}"
    echo "1. 在 /etc/realm/ 目录下创建你的配置文件（例如：config.json）"
    echo "2. 启动服务：systemctl start realm@config"
    echo "3. 设置开机自启：systemctl enable realm@config"
    echo "4. 查看服务状态：systemctl status realm@config"
    echo "5. 查看日志：journalctl -u realm@config"
}

# 运行主函数
main