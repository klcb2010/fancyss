#!/bin/sh
# refresh DDNS update
# Triggered by cron (weekly on Sunday 03:30)

LOG_FILE="/jffs/ddns_refresh.log"  # 脚本内部日志，持久化

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Script started - forcing DDNS update" >> "$LOG_FILE"
logger -t "DDNS_refresh" "Script started - forcing DDNS update"

service restart_httpd >> "$LOG_FILE" 2>&1 || echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: restart_httpd failed" >> "$LOG_FILE"
nvram set ddns_update=1
nvram commit
service restart_ddns_le >> "$LOG_FILE" 2>&1 || echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: restart_ddns_le failed" >> "$LOG_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Script finished - DDNS refresh triggered" >> "$LOG_FILE"
logger -t "DDNS_refresh" "Script finished - DDNS refresh triggered"
