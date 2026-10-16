#!/bin/sh
# fancyss 更新脚本 (干净输出，多架构通用，针对 klcb2010/fancyss 仓库)
# - 自动判断本地版本
# - 获取在线最新版本（支持 socks5 代理）
# - 版本不同才升级
# - 自动选择正确的包（GT-AX6000 等 aarch64 用 hnd_v8_full）
# - 自动解压执行 install.sh
# - BusyBox / curl / wget 兼容

run() {
    "$@"
}

echo_date() {
    TZ=Asia/Shanghai date "+【%Y%m%d %H:%M:%S】: $*"
}

# 根据 CPU 架构选择包（默认 full，不自动切换 lite）
choose_package() {
    local cpu=$(uname -m 2>/dev/null || echo "unknown")
    local pkg="fancyss_hnd_v8_full.tar.gz"  # GT-AX6000 等主流新机默认这个

    case "$cpu" in
        armv7l|armv6l)
            pkg="fancyss_arm_full.tar.gz"
            ;;
        aarch64)
            # 新 Broadcom HND v8 平台（4.19+ 内核）统一用 hnd_v8
            pkg="fancyss_hnd_v8_full.tar.gz"
            ;;
        mips|mipsel)
            if grep -qi "IPQ64" /proc/cpuinfo 2>/dev/null; then
                pkg="fancyss_ipq64_full.tar.gz"
            else
                pkg="fancyss_ipq32_full.tar.gz"
            fi
            ;;
        qca*)
            pkg="fancyss_qca_full.tar.gz"
            ;;
        mtk*)
            pkg="fancyss_mtk_full.tar.gz"
            ;;
        *)
            echo_date "未知架构 ${cpu}，默认使用 fancyss_hnd_v8_full.tar.gz" >&2
            ;;
    esac

    # 调试信息输出到 stderr，避免污染返回值
    echo_date "选中的包: $pkg (架构: $cpu)" >&2

    # 只返回纯包名（不带任何额外输出）
    echo "$pkg"
}

update_ss() {
    # 读取本地版本（优先 fancyss 路径，兼容旧 ss）
    if [ -f "/jffs/.koolshare/fancyss/version" ]; then
        local_ver=$(cat /jffs/.koolshare/fancyss/version 2>/dev/null)
    elif [ -f "/jffs/.koolshare/ss/version" ]; then
        local_ver=$(cat /jffs/.koolshare/ss/version 2>/dev/null)
    else
        local_ver=""
    fi
    echo_date "本地版本: ${local_ver:-未安装或未定义}"

    main_url="https://github.com/klcb2010/fancyss"
    version_url="${main_url}/releases/latest"

    # curl 兼容（优先 fancyss 自带 curl，如果没有用系统）
    if [ -x "/koolshare/bin/curl-fancyss" ]; then
        curl_bin="/koolshare/bin/curl-fancyss"
    else
        curl_bin="$(which curl 2>/dev/null || echo curl)"
    fi
    ln -sf "$curl_bin" /tmp/curl-update 2>/dev/null

    # 检测本地 socks5 代理是否可用（端口 23456 常见）
    socks_proxy=""
    if netstat -nl 2>/dev/null | grep -q ":23456.*LISTEN"; then
        socks_proxy="-x socks5h://127.0.0.1:23456"
    fi

    echo_date "获取在线最新版本"
    latest_tag=$(run /tmp/curl-update -4sk -L -I $socks_proxy "${version_url}" \
        | grep -i '^location:' | awk -F '/' '{print $NF}' | tr -d '\r\n\t ')

    # fallback wget 或直接解析
    if [ -z "$latest_tag" ]; then
        latest_tag=$(wget -qO- --tries=2 "${version_url}" 2>/dev/null \
            | grep -o 'releases/tag/[^"]*' | head -n1 | cut -d'/' -f3 | tr -d '\r\n\t ')
    fi

    if [ -z "$latest_tag" ]; then
        echo_date "无法获取最新版本，退出"
        exit 1
    fi

    # 彻底清理 latest_tag 中的所有空白/换行/回车
    latest_tag=$(echo "$latest_tag" | tr -d '\r\n\t ')
    latest_clean=$(echo "$latest_tag" | sed 's/^v//')

    echo_date "在线版本 : ${latest_clean}"

    # 对比版本
    if [ -n "$local_ver" ] && [ "$local_ver" = "$latest_clean" ]; then
        echo_date "本地已是最新版本 ${local_ver}，无需更新"
        exit 0
    fi

    echo_date "检测到新版本 ${latest_clean}，开始更新"

    cd /tmp || exit 1
    rm -f fancyss_*.tar.gz 2>/dev/null

    package_file=$(choose_package)
    download_url="${main_url}/releases/download/${latest_tag}/${package_file}"

    # 调试：显示实际拼接的 URL（上线后可注释）
    echo_date "拼接的下载 URL: ${download_url}"

    echo_date "下载包: ${package_file}"

    # 先用 curl 下载
    run /tmp/curl-update -4k -sS -L --connect-timeout 8 --max-time 150 \
        --retry 3 --retry-delay 2 $socks_proxy "${download_url}" -o "${package_file}"

    if [ $? -ne 0 ] || [ ! -s "${package_file}" ]; then
        echo_date "curl 下载失败，尝试 wget..."
        wget -q --tries=3 --timeout=10 "${download_url}" -O "${package_file}"
    fi

    if [ ! -s "${package_file}" ]; then
        echo_date "下载失败，请检查网络或 release 是否存在该包"
        exit 1
    fi

    echo_date "下载完成，开始解压并安装"
    tar -zxf "${package_file}" -C /tmp 2>/dev/null

    install_script=$(find /tmp -name install.sh -type f 2>/dev/null | head -n1)
    if [ -z "$install_script" ]; then
        echo_date "未找到 install.sh，解压或包异常"
        rm -f "${package_file}" fancyss* 2>/dev/null
        exit 1
    fi

    chmod +x "$install_script"
    sh "$install_script"

    # 清理临时文件
    rm -rf /tmp/fancyss* /tmp/install.sh "${package_file}" 2>/dev/null

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
