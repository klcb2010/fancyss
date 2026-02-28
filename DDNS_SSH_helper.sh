#!/bin/sh
# DDNS_SSH_helper.sh
# 功能：1. 注入指定SSH公钥
#      2. 设置 territory_code = US/01
#      3. 设置 DOWNGRADE_CHECK_PASS = 1
# 适用：梅林固件改版

# ==================== 配置区 ====================
SSH_KEY='公钥'                  # ← 务必替换成你的完整公钥
SSH_DIR="/root/.ssh"
AUTH_FILE="${SSH_DIR}/authorized_keys"
TARGET_TERRITORY="US/01"
LOG_FILE="/jffs/scripts/DDNS_helper.log"
# ==============================================

timestamp() {
    date '+%Y%m%d %H:%M:%S'
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> "$LOG_FILE"
}

# ---------------------- 开始 ----------------------
log "===== DDNS_SSH_helper started ====="

# ====================== SSH 公钥注入 ======================
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}" 2>/dev/null

touch "${AUTH_FILE}"
chmod 600 "${AUTH_FILE}" 2>/dev/null

if ! grep -qxF "${SSH_KEY}" "${AUTH_FILE}"; then
    echo "${SSH_KEY}" >> "${AUTH_FILE}"
    log "SSH 公钥已成功注入"
    echo "【$(timestamp)】: =========================== SSH公钥已注入 ============================"
else
    log "SSH 公钥已存在，跳过注入"
    echo "【$(timestamp)】: =========================== SSH公钥已存在 ============================"
fi

# ====================== territory_code 设置 ======================
CURRENT_TERR="$(nvram get territory_code 2>/dev/null)"
[ -z "$CURRENT_TERR" ] && CURRENT_TERR="(unset)"

if [ "$CURRENT_TERR" = "$TARGET_TERRITORY" ]; then
    log "territory_code 已是 ${TARGET_TERRITORY}，跳过"
else
    nvram set territory_code="$TARGET_TERRITORY"
    nvram commit
    log "territory_code 已从 ${CURRENT_TERR} 变更为 ${TARGET_TERRITORY}"
fi

# ====================== DOWNGRADE_CHECK_PASS 设置 ======================
CURRENT_DOWNGRADE="$(nvram get DOWNGRADE_CHECK_PASS 2>/dev/null)"
[ -z "$CURRENT_DOWNGRADE" ] && CURRENT_DOWNGRADE="(unset)"

if [ "$CURRENT_DOWNGRADE" = "1" ]; then
    log "DOWNGRADE_CHECK_PASS 已是 1，跳过"
else
    nvram set DOWNGRADE_CHECK_PASS=1
    nvram commit
    log "DOWNGRADE_CHECK_PASS 已从 ${CURRENT_DOWNGRADE} 变更为 1"
fi

log "===== DDNS_SSH_helper finished ====="
