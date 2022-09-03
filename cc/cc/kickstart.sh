#!/usr/bin/env bash
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

OUT_ALERT() {
    echo -e "${CYELLOW}$1${CEND}"
}

OUT_ERROR() {
    echo -e "${CRED}$1${CEND}"

    exit 1
}

OUT_INFO() {
    echo -e "${CCYAN}$1${CEND}"
}

ERR_CLEANUP() {
    cd ~
    rm -fr cuocuo
    rm -fr release

    OUT_ERROR "[错误] $1"

    exit 1
}

if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
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
fi

wget_exists=$(wget -V 2>/dev/null)
ntpdate_exists=$(ntpdate -v 2>/dev/null)
htpdate_exists=$(htpdate 2>/dev/null)
if [[ ${wget_exists} == "" ]] || [[ ${ntpdate_exists} ==  "" ]] || [[ ${htpdate_exists} ==  "" ]]; then
    OUT_ALERT "[提示] 安装依赖软件包中"

    if [[ ${release} == "centos" ]]; then
        yum makecache
        yum install epel-release -y

        yum makecache
        yum install wget ntp htpdate -y
    else
        apt update
        apt install wget ntpdate htpdate -y
    fi
fi

cd ~

OUT_ALERT "[提示] 同步时间中"
timedatectl set-timezone Asia/Shanghai
ntpdate pool.ntp.org || htpdate -s www.baidu.com
hwclock -w

if [[ $# != 1 ]]; then
    OUT_ALERT "[提示] 下载程序中"
    wget -O cuocuo https://download.renzhe.work/cuocuo || ERR_CLEANUP "下载程序失败！"
fi

OUT_ALERT "[提示] 复制程序中"
chmod +x cuocuo
cp -f cuocuo /usr/bin

OUT_ALERT "[提示] 配置服务中"
cat > /etc/systemd/journald.conf <<EOF
[Journal]
SystemMaxUse=384M
SystemMaxFileSize=128M
ForwardToSyslog=no
EOF
cat > /etc/systemd/system/cuocuo@.service <<EOF
[Unit]
Description=Mithril Cable Network
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
ExecStart=/usr/bin/cuocuo -c /etc/cuocuo/%i.json
Restart=always
RestartSec=4

[Install]
WantedBy=multi-user.target
EOF

OUT_ALERT "[提示] 重载服务中"
systemctl daemon-reload

OUT_ALERT "[提示] 清理垃圾中"
cd ~ && rm -f cuocuo

OUT_INFO "[信息] 部署完毕！"
exit 0
