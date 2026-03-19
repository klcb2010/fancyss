#!/bin/sh
# fancyss 更新脚本 (干净输出版)
# - 自动判断本地版本
# - 自动获取在线最新版本
# - 对比版本，不相同才升级
# - 自动解压并执行 install.sh
# - BusyBox / curl / wget / netstat / dbus 兼容
# - 输出干净，无 + 命令调试痕迹

run() {
  "$@"
}

echo_date() {
  echo "【$(TZ=UTC-8 date +%Y年%m月%d日\ %H:%M:%S)】: $*"
}

update_ss() {

  # 读取本地版本
  if [ -f "/jffs/.koolshare/ss/version" ]; then
    ss_basic_version_local=$(cat /jffs/.koolshare/ss/version)
  else
    ss_basic_version_local=""
  fi
  echo_date "本地版本: ${ss_basic_version_local:-未定义}"

  main_url="https://github.com/klcb2010/fancyss"
  VERSION_URL="${main_url}/releases/latest"

  # curl 兼容处理
  if [ -x /koolshare/bin/curl-fancyss ]; then
    ln -sf /koolshare/bin/curl-fancyss /tmp/curl-update
  else
    ln -sf $(which curl) /tmp/curl-update
  fi

  # 检测 SOCKS5
  SOCKS5_OPEN=$(netstat -nl 2>/dev/null | grep -w "23456" | grep -Eo "v2ray|xray|naive|tuic")

  # 获取最新版本
  echo_date "获取在线最新版本"
  if [ -n "${SOCKS5_OPEN}" ]; then
    LATEST_TAG=$(run /tmp/curl-update -4sk -L -I -x socks5h://127.0.0.1:23456 "${VERSION_URL}" \
      | grep -i '^location:' | awk -F '/' '{print $NF}' | tr -d '\r')
  else
    LATEST_TAG=$(run /tmp/curl-update -4sk -L -I "${VERSION_URL}" \
      | grep -i '^location:' | awk -F '/' '{print $NF}' | tr -d '\r')
  fi

  # curl 失败 fallback
  if [ -z "${LATEST_TAG}" ]; then
    LATEST_TAG=$(wget -qO- "${VERSION_URL}" \
      | grep -o 'releases/tag/[^"]*' \
      | head -n 1 \
      | cut -d '/' -f3 \
      | tr -d '\r')
  fi

  if [ -z "${LATEST_TAG}" ]; then
    echo_date "无法获取在线最新版本，退出"
    exit 1
  fi

  # 去掉 v 前缀用于版本比较
  LATEST_TAG_CLEAN=$(echo "${LATEST_TAG}" | sed 's/^v//')
  echo_date "在线版本 : ${LATEST_TAG_CLEAN}"

  command -v dbus >/dev/null 2>&1 && dbus set ss_basic_version_web="${LATEST_TAG}"

  # 对比版本
  if [ "${ss_basic_version_local}" = "${LATEST_TAG_CLEAN}" ]; then
    echo_date "本地已是最新版本 ${ss_basic_version_local}，无需更新"
    exit 0
  fi

  echo_date "检测到新版本 ${LATEST_TAG_CLEAN}，开始更新"

  cd /tmp || exit 1
  rm -rf fancyss_*.tar.gz

  DOWNLOAD_URL="${main_url}/releases/download/${LATEST_TAG}/fancyss_hnd_full.tar.gz"

  run /tmp/curl-update -4k -sS -L --connect-timeout 5 --max-time 120 \
    --retry 3 --retry-delay 1 "${DOWNLOAD_URL}" -o fancyss_hnd_full.tar.gz

  if [ "$?" != "0" ] || [ ! -s fancyss_hnd_full.tar.gz ]; then
    wget -q --tries=3 --timeout=5 "${DOWNLOAD_URL}" -O fancyss_hnd_full.tar.gz
  fi

  if [ ! -s fancyss_hnd_full.tar.gz ]; then
    echo_date "下载失败"
    exit 1
  fi

  echo_date "下载完成，开始解压并安装"

  tar -zxf fancyss_hnd_full.tar.gz -C /tmp

  INSTALL_SCRIPT=$(find /tmp -name install.sh | head -n 1)
  if [ -z "$INSTALL_SCRIPT" ]; then
    echo_date "未找到 install.sh，解压可能异常"
    exit 1
  fi

  chmod +x "$INSTALL_SCRIPT"
  sh "$INSTALL_SCRIPT"

  rm -rf /tmp/fancyss* /tmp/install.sh

  echo_date "更新完成"
}

case "$1" in
update)
  update_ss
  ;;
*)
  echo "用法: sh $0 update"
  ;;
esac
