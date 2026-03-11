#!/bin/sh
# refresh DDNS update - IPv6-only
# Triggered by cron (weekly on Sunday 03:30)

LOG_FILE="/jffs/scripts/ddns_refresh.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Script started - forcing DDNS update" >> "$LOG_FILE"
logger -t "DDNS_refresh" "Script started - forcing DDNS update"

# 重启 httpd 服务（保持原逻辑）
service restart_httpd >> "$LOG_FILE" 2>&1 || echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: restart_httpd failed" >> "$LOG_FILE"

# 获取当前公网 IPv6
IPV6=$(curl -6 -s https://ifconfig.co)
if [ -z "$IPV6" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to get public IPv6" >> "$LOG_FILE"
    logger -t "DDNS_refresh" "Failed to get public IPv6"
    exit 1
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Public IPv6 detected: $IPV6" >> "$LOG_FILE"

# 设置 nvram DDNS 只用 IPv6
nvram set ddns_custom_ip="$IPV6"
nvram set ddns_update=1
nvram commit

# 重启 DDNS 服务
service restart_ddns_le >> "$LOG_FILE" 2>&1 || echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: restart_ddns_le failed" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Script finished - DDNS refresh triggered" >> "$LOG_FILE"
logger -t "DDNS_refresh" "Script finished - DDNS refresh triggered"
