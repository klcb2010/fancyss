#!/bin/sh
# DDNS_helper.sh - 华硕区域与降级许可助手

LOG_FILE="/jffs/scripts/DDNS_helper.log"
TARGET="US/01"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> "$LOG_FILE"
}

log "===== DDNS_helper started ====="

########################################
# territory_code 检查与设置
########################################

CURRENT_TERR="$(nvram get territory_code 2>/dev/null)"
[ -z "$CURRENT_TERR" ] && CURRENT_TERR="(unset)"

if [ "$CURRENT_TERR" = "$TARGET" ]; then
    log "territory_code already '$TARGET', skip"
else
    nvram set territory_code="$TARGET"
    nvram commit
    log "territory_code changed from '$CURRENT_TERR' to '$TARGET'"
fi


########################################
# DOWNGRADE_CHECK_PASS 检查与设置
########################################

CURRENT_DOWNGRADE="$(nvram get DOWNGRADE_CHECK_PASS 2>/dev/null)"
[ -z "$CURRENT_DOWNGRADE" ] && CURRENT_DOWNGRADE="(unset)"

if [ "$CURRENT_DOWNGRADE" = "1" ]; then
    log "DOWNGRADE_CHECK_PASS already '1', skip"
else
    nvram set DOWNGRADE_CHECK_PASS=1
    nvram commit
    log "DOWNGRADE_CHECK_PASS changed from '$CURRENT_DOWNGRADE' to '1'"
fi
