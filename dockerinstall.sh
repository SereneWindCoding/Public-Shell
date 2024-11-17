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
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] 警告: $1${NC}"
}

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    error "此脚本需要root权限运行"
    exit 1
fi

# 检查系统要求
check_system_requirements() {
    log "检查系统要求..."
    
    # 检查内存
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $total_mem -lt 2048 ]]; then
        warning "系统内存小于2GB，Docker可能无法正常运行"
    fi

    # 检查磁盘空间
    free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $free_space -lt 20 ]]; then
        warning "磁盘剩余空间小于20GB，建议清理磁盘"
    fi
}

# 备份原有Docker配置
backup_existing_docker() {
    if [ -d "/etc/docker" ]; then
        log "备份现有Docker配置..."
        backup_dir="/etc/docker.backup.$(date +%Y%m%d_%H%M%S)"
        cp -r /etc/docker "$backup_dir"
        log "Docker配置已备份到 $backup_dir"
    fi
}

# 安装必要的依赖
install_prerequisites() {
    log "更新软件包列表..."
    if ! apt-get update -y; then
        error "更新软件包列表失败"
        exit 1
    fi

    log "升级系统软件包..."
    if ! apt-get upgrade -y; then
        error "升级系统软件包失败"
        exit 1
    fi

    log "安装必要的依赖包..."
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
}

# 安装Docker
install_docker() {
    log "下载Docker安装脚本..."
    if ! curl -fsSL https://get.docker.com -o get-docker.sh; then
        error "下载Docker安装脚本失败"
        exit 1
    fi

    log "执行Docker安装..."
    if ! bash get-docker.sh; then
        error "Docker安装失败"
        exit 1
    fi

    # 清理安装脚本
    rm -f get-docker.sh
}

# 配置Docker
configure_docker() {
    log "配置Docker..."
    
    # 创建daemon.json配置文件
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": [
        "https://mirror.ccs.tencentyun.com",
        "https://mirror.baidubce.com"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    }
}
EOF
}

# 启动Docker服务
start_docker() {
    log "重启Docker服务..."
    if ! systemctl restart docker; then
        error "Docker服务启动失败"
        exit 1
    fi

    # 等待Docker启动
    sleep 3

    # 验证Docker是否正常运行
    if ! docker info >/dev/null 2>&1; then
        error "Docker未能正常启动"
        exit 1
    fi
}

# 验证安装
verify_installation() {
    log "验证Docker安装..."
    
    # 检查Docker版本
    docker_version=$(docker --version)
    log "Docker版本: $docker_version"

    # 测试Docker功能
    log "测试Docker功能..."
    if docker run --rm hello-world >/dev/null 2>&1; then
        log "Docker测试成功！"
    else
        error "Docker功能测试失败"
        exit 1
    fi
}

# 主流程
main() {
    log "开始安装Docker..."
    
    check_system_requirements
    backup_existing_docker
    install_prerequisites
    install_docker
    configure_docker
    start_docker
    verify_installation
    
    log "Docker安装和配置已完成！"
    
    # 显示一些有用的下一步信息
    echo -e "\n${GREEN}推荐的下一步操作：${NC}"
    echo "1. 将当前用户添加到docker组（需要重新登录生效）："
    echo "   sudo usermod -aG docker \$USER"
    echo "2. 检查Docker系统信息："
    echo "   docker info"
    echo "3. 测试Docker："
    echo "   docker run hello-world"
}

# 执行主流程
main