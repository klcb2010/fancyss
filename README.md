#   修改点如下

-  修改 　国内国外方案  　　  　　  　　  确保任意模式下优先调用自定义黑名单   　 　  解决Grok、 ChatGPT错误

-  注入 　DDNS_SSH_helper定时公钥    　DDNS区域更改为US  　 　 　 　 　 　 　    　　开启固件降级功能

-  精简 　精简通知 　 　　  　　  　　  　删除空白通知

#  官方 部分原文  保留推广 支持开发


- Fancyss is a project providing tools to across the GFW on asuswrt/merlin based router with software center. 
- 此项目提供用于asuswrt、asuswrt-merlin为基础的，带软件中心固件（≥384）路由器的科学上网功能。

---
- 📺 广告1：[ChatGPT Plus、Netflix、Disney+、Spotify、YouTube等会员账号合租，95折优惠码: fancyss](https://nf.video/9QQkT)
- 🚀 广告2：[fancyss合作top机场：<b>Nexitally/奶昔</b> | 全中转机场 / 优质线路资源 / 支持udp / 解锁流媒体，ChatGPT](https://nxboom.com/?PartnerCode=af8f126dd490446e80737444dd0064f6)
- ✈️ 广告3：[fancyss高速机场推荐：<b>ssLinks</b> | 性价比全中转机场 / 80+线路 / 流媒体解锁，9折优惠码: fancyss](https://98a6251b6cd7471da86cca993b6dbe6f.36d.biz/#/register?code=yf6ozeEO)
---

## 插件特色

- 多平台支持：博通armv7，博通armv8，联发科Filogic 830 MT7986A，高通ipq系列
- 多客户端支持：Shadowsocks、ShadowsocksR、V2ray、Xray、Trojan、NaïveProxy、TuicV5、Hysteria2
- shadowsocks支持SIP003插件：simple-obfs；V2ray和Xray支持多种协议配置
- 多种模式支持：gfwlist模式、大陆白名单、游戏模式、全局模式、回国模式
- 提供多种现成的DNS方案，并且可以自由方便的进行DNS方案自定义配置
- 支持SS/SSR/V2ray/Xray/Trojan节点的在线订阅，支持节点生成二维码用以分享
- 故障转移、主备切换、负载均衡、定时重启、定时订阅、规则更新、二进制更新
- 支持kcptun、udpspeeder、udp2raw，可以实现代理加速，游戏加速，应对丢包等
- 同时提供full版本和lite版本，hnd_lite版本安装后占用不到8MB的空间，适合小jffs机型
- armv8机型支持tcp fast open和ss/ssr/trojan多核心运行

## 支持机型/固件


最新固件下载地址：[https://fw.koolcenter.com/](https://fw.koolcenter.com/)


## 插件说明

fancyss 3.0支持hnd、hnd_v8、qca、arm、mtk 、ipq32、ipq64七个平台，本仓库有full版本

内置定时任务和静默运行任务可自行调整 在仓库根目录 cron_task.txt 


## 插件安装

到发布页下载后通过软件中心本地安装

## 关于皮肤
102.6开始  梅林取消了ROG皮肤 


## 目录说明

1. **fancyss**：插件代码主目录，由build.sh打包成不同路由器的离线安装包
2. **binaries**：一些在线更新的二进制程序，如v2ray、xray
3. **packages**：不同平台的离线安装包的最新版本，用于插件的在线更新
4. **rules**：插件的规则文件，如gfwlist.conf、chnroute.txt、cdn.txt

## 打包插件

> 打包过程就是将fancyss目录下相关二进制和代码文件通过脚本生成不同平台，不同版本的离线安装包。
>
> 为保证在不同路由器/固件版本中都能运行，项目提供的所有二进制都是预编译好的，且尽量提供全静态编译版本。

1. 克隆本项目：使用linux系统，比如Ubuntu 20.04

   ```bash
   git clone https://github.com/hq450/fancyss.git
   ```

2. 切换到3.0分支

   ```bash
   cd fancyss
   git checkout 3.0
   ```

3. 修改代码：根据自己需要修改代码主目录fancyss目录下的相关文件，如`./fancyss/ss/ssconfig.sh`

4. 打包插件，运行打包命令后会自动同步rules下最新的规则和binaries下最新的二进制

   如需要开发，请使用`sh build.sh debug`命令，将会额外打包带`debug`字样的安装包，安装包内网页文件等保留了注释信息

   ```bash
   sh build.sh
   ```

5. 打包好的离线安装包 在发布页

## 相关链接

* 官改/梅改固件下载【网方网站】（最新固件）：[https://www.koolcenter.com](https://www.koolcenter.com/)
* 官改/梅改固件下载【固件镜像】（次新固件）：[https://fw.koolcenter.com](https://fw.koolcenter.com)


[^1]: RT-AC86U从384_81918_koolshare固件版本开始，使用的是asuswrt风格ui，而不是rog风格。
[^2]: RT-AX89X采用的SoC为ipq8074/ipq8074A，支持64位系统，但是其固件是32位系统。
