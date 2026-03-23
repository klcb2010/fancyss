#!/bin/sh
# fancyss 更新脚本 (最终全平台稳定版)
# - 自动判断本地版本
# - 自动获取在线最新版本
# - 对比版本，不相同才升级
# - 自动选择架构对应的 fancyss_full 包
# - 支持 HND V8 / HND 旧版 / ARM / MTK / QCA / IPQ32 / IPQ64
# - 自动解压并执行 install.sh
# - BusyBox / curl / wget / netstat / dbus 兼容
# - 下载显示进度，支持断点续传和重试
# - 输出干净，无调试痕迹

run() { "$@"; }

echo_date() { 
    echo "【$(TZ=UTC-8 date +%Y年%m月%d日\ %H:%M:%S)】: $*"
}

# 根据 CPU 架构选择 fancyss_full 包
choose_package() {
    CPU_ARCH=$(uname -m)
    PACKAGE_NAME="fancyss_hnd_full.tar.gz"  # 默认 HND 旧版

    case "$CPU_ARCH" in
        armv7l|armv6l)
            PACKAGE_NAME="fancyss_arm_full.tar.gz"
            ;;
        aarch64)
            PACKAGE_NAME="fancyss_arm_full.tar.gz"
            ;;
        mips|mipsel)
            if grep -q "IPQ64" /proc/cpuinfo 2>/dev/null; then
                PACKAGE_NAME="fancyss_ipq64_full.tar.gz"
            else
                PACKAGE_NAME="fancyss_ipq32_full.tar.gz"
            fi
            ;;
        qca*)
            PACKAGE_NAME="fancyss_qca_full.tar.gz"
            ;;
        mtk*)
            PACKAGE_NAME="fancyss_mtk_full.tar.gz"
            ;;
        hnd*|bcm*)
            if grep -q "HND V8" /proc/cpuinfo 2>/dev/null || grep -q "V8" /proc/cpuinfo 2>/dev/null; then
                PACKAGE_NAME="fancyss_hnd_v8_full.tar.gz"
            else
                PACKAGE_NAME="fancyss_hnd_full.tar.gz"
            fi
            ;;
        *)
            echo_date "未知架构，默认使用 HND 旧版包"
            ;;
    esac

    echo_date "检测架构: $CPU_ARCH，选择安装包: $PACKAGE_NAME"
    echo "$PACKAGE_NAME"
}

# 下载文件，支持 curl/wget，显示进度条，断点续传，重试
download_file() {
    URL="$1"
    OUTPUT="$2"

    # 优先 curl
    if command -v curl >/dev/null 2>&1; then
        for i in 1 2 3 4 5; do
            echo_date "使用 curl 下载（第 $i 次尝试）: $OUTPUT"
            curl -C - -4k -# --connect-timeout 10 --max-time 300 --retry 3 --retry-delay 2 "$URL" -o "$OUTPUT"
            [ $? -eq 0 ] && [ -s "$OUTPUT" ] && return 0
            echo_date "curl 下载失败，重试..."
            sleep 2
        done
    fi

    # fallback wget
    if command -v wget >/dev/null 2>&1; then
        for i in 1 2 3 4 5; do
            echo_date "使用 wget 下载（第 $i 次尝试）: $OUTPUT"
            wget -c --progress=bar:force -t 5 --timeout=30 "$URL" -O "$OUTPUT"
            [ $? -eq 0 ] && [ -s "$OUTPUT" ] && return 0
            echo_date "wget 下载失败，重试..."
            sleep 2
        done
    fi

    return 1
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

    # 检测 SOCKS5
    SOCKS5_OPEN=$(netstat -nl 2>/dev/null | grep -w "23456" | grep -Eo "v2ray|xray|naive|tuic")

    # 获取最新版本
    echo_date "获取在线最新版本"
    if [ -x /koolshare/bin/curl-fancyss ]; then
        CURL_CMD="/koolshare/bin/curl-fancyss -4sk"
    elif command -v curl >/dev/null 2>&1; then
        CURL_CMD="curl -4sk"
    else
        CURL_CMD=""
    fi

    if [ -n "$CURL_CMD" ]; then
        if [ -n "${SOCKS5_OPEN}" ]; then
            LATEST_TAG=$($CURL_CMD -L -I -x socks5h://127.0.0.1:23456 "$VERSION_URL" \
                | grep -i '^location:' | awk -F '/' '{print $NF}' | tr -d '\r')
        else
            LATEST_TAG=$($CURL_CMD -L -I "$VERSION_URL" \
                | grep -i '^location:' | awk -F '/' '{print $NF}' | tr -d '\r')
        fi
    fi

    if [ -z "$LATEST_TAG" ]; then
        LATEST_TAG=$(wget -qO- "$VERSION_URL" | grep -o 'releases/tag/[^"]*' | head -n 1 | cut -d '/' -f3 | tr -d '\r')
    fi

    if [ -z "$LATEST_TAG" ]; then
        echo_date "无法获取在线最新版本，退出"
        exit 1
    fi

    LATEST_TAG_CLEAN=$(echo "$LATEST_TAG" | sed 's/^v//')
    echo_date "在线版本 : $LATEST_TAG_CLEAN"

    command -v dbus >/dev/null 2>&1 && dbus set ss_basic_version_web="$LATEST_TAG"

    if [ "$ss_basic_version_local" = "$LATEST_TAG_CLEAN" ]; then
        echo_date "本地已是最新版本 $ss_basic_version_local，无需更新"
        exit 0
    fi

    echo_date "检测到新版本 $LATEST_TAG_CLEAN，开始更新"

    cd /tmp || exit 1
    rm -rf fancyss_*.tar.gz

    PACKAGE_FILE=$(choose_package)
    DOWNLOAD_URL="${main_url}/releases/download/${LATEST_TAG}/${PACKAGE_FILE}"

    if ! download_file "$DOWNLOAD_URL" "$PACKAGE_FILE"; then
        echo_date "下载失败，退出"
        exit 1
    fi

    echo_date "下载完成，开始解压并安装"
    tar -zxf "$PACKAGE_FILE" -C /tmp
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
