#!/bin/sh
# SSH 公钥注入脚本 - 适配梅林固件
# 防重复注入，权限自动修复，输出带时间戳，与其他脚本统一风格

SSH_KEY='公钥'
SSH_DIR="/root/.ssh"
AUTH_FILE="${SSH_DIR}/authorized_keys"

# 获取当前时间
timestamp() {
    date '+%Y%m%d %H:%M:%S'
}

# 创建目录并修复权限
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# 创建授权文件并修复权限
touch "${AUTH_FILE}"
chmod 600 "${AUTH_FILE}"

# 检查是否已注入，未注入则写入
if ! grep -qxF "${SSH_KEY}" "${AUTH_FILE}"; then
    echo "${SSH_KEY}" >> "${AUTH_FILE}"
    echo "【$(timestamp)】: =========================== SSH公钥已注入 ============================"
else
    echo "【$(timestamp)】: =========================== SSH公钥已存在 ============================"
fi
