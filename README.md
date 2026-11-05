
# 2026年 11月5日  修复    anytls


#   本仓库修改点如下

-  每天4:30自动更新最新版

- 替换 在线GFW规则 保持最新版本

- 故障转移默认刷新页面不弹窗

- 自定义黑白名单  打包即用

# 相关脚本在 [Asuswrt-Merlin-Custom-Scripts](https://github.com/klcb2010/Asuswrt-Merlin-Custom-Scripts)
- 国外游戏玩家取消 QUIC流量屏蔽 否则提示网络异常

## cron_task.txt 注入状态

目前已在两个自动构建工作中 临时注释停用 cron_task.txt 注入步骤。因此构建时不会再把该文件中的自定义定时任务及后台启动代码注入到 `ssconfig.sh`。如需恢复，需要同时在 ssconfig文件末端增加 

<pre><code class="language-bash">
#CUSTOM_INJECT_START
LOG_TIME=$(date '+【%Y%m%d %H:%M:%S】')
echo "$LOG_TIME: 自定义任务启动" >> /tmp/custom_task.log
======================= 自定义任务启动开始 ===========================
for task in ss_update_daily clean_logs rclone_clean_cache rclone_guard; do
cru d $task 2>/dev/null
done
cru a rclone_guard "*/10 * * * * /jffs/scripts/rclone_webdav.sh >> /tmp/rclone_guard.log 2>&1"
cru a ss_update_daily "30 4 * * * sh /jffs/.koolshare/scripts/ss_update.sh update >> /jffs/scripts/ss_update.log 2>&1"
cru a clean_logs "0 3 * * * /jffs/scripts/clean_logs.sh >> /jffs/scripts/clean_logs.txt 2>&1"
cru a refresh_ddns "0 6 * * 1 sh /jffs/scripts/refresh_ddns.sh >> /jffs/scripts/ddns_refresh.log 2>&1"
rclone_cache清理
cru a rclone_clean_cache "0 */2 * * * /bin/sh /jffs/scripts/rclone_clean_cache.sh >> /tmp/rclone_clean.log 2>&1"
======================= 3.0 后台服务强启 =======================
检查 rclone，如果没跑就启动
if ! ps -w | grep -v grep | grep -q "rclone_webdav.sh"; then
/bin/sh /jffs/scripts/rclone_webdav.sh >/dev/null 2>&1 &
fi
检查 SSH_helper，如果没跑就启动
if ! ps -w | grep -v grep | grep -q "SSH_helper.sh"; then
/bin/sh /jffs/scripts/SSH_helper.sh >/dev/null 2>&1 &
fi
allow_port() {
PORT=$1
iptables -C INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
ip6tables -C INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null || \
ip6tables -I INPUT -p tcp --dport $PORT -j ACCEPT
}
allow_port 8180
allow_port 8181
allow_port 2525
echo "$LOG_TIME: ======================= 自定义任务启动完毕 =========================== "
#CUSTOM_INJECT_END
</code></pre>


然后 取消工作流中 `Inject cron_task safely` 步骤的注释即可。
