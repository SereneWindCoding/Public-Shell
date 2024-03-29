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

if [[ ${release} == "centos" ]]; then
    yum makecache
    yum install psmisc -y
else
    apt update
    apt install psmisc -y
fi

OUT_ALERT "[提示] 删除自启中"
rm -f /etc/systemd/system/multi-user.target.wants/cuocuo@*.service

OUT_ALERT "[提示] 删除服务中"
rm -f /etc/systemd/system/cuocuo@.service

OUT_ALERT "[提示] 删除程序中"
rm -f /usr/bin/cuocuo

OUT_ALERT "[提示] 删除配置中"
rm -fr /etc/cuocuo

OUT_ALERT "[提示] 重载服务中"
systemctl daemon-reload

OUT_ALERT "[提示] 清理进程中"
killall cuocuo

OUT_INFO "[信息] 移除完毕！"
exit 0
