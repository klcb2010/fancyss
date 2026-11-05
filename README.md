
# 2026年 11月5日  修复    anytls


#   本仓库修改点如下

-  每天4:30自动更新最新版

- 替换 在线GFW规则 保持最新版本

- 故障转移默认刷新页面不弹窗

- 自定义黑白名单  打包即用

# 相关脚本在 [Asuswrt-Merlin-Custom-Scripts](https://github.com/klcb2010/Asuswrt-Merlin-Custom-Scripts)
- 国外游戏玩家取消 QUIC流量屏蔽 否则提示网络异常

## cron_task.txt 注入状态

目前已在两个自动构建工作中 临时注释停用 cron_task.txt 注入步骤。因此构建时不会再把该文件中的自定义定时任务及后台启动代码注入到 `ssconfig.sh`。

`cron_task.txt` 文件仍保留在仓库中，没有删除；如以后需要恢复，只需取消对应工作流中 `Inject cron_task safely` 步骤的注释即可。
