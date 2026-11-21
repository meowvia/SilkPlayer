# SilkPlayer Pro 2.0.0 成果归档 / Delivery Archive

## 交付基准与版本信息
- 版本号：2.0.0 (Build 2026112001)
- 产品类型：SilkPlayer Pro（专业版）
- 发布日期：2026-11-20
- 分支与代码基准：
  - 前端仓库 (LGPL-3.0)：`SilkPlayer/SilkPlayer` 分支 `main` (commit `78025fa`)
  - 闭源内核 (Proprietary)：`SilkPlayer/SilkCoreKit` 分支 `release/2.0.0` (commit `7e1af5f`)
- 官方发布镜像：SilkPlayer-2.0.0-universal.dmg
- 镜像大小：约 23 MB
- 校验和 (SHA-256)：baf1ca30f35e533355d53dfa491f7bd6b6c74c041bc593f9c223e49129562fdb
- 依赖审计：全部三方动态库均完成 @rpath 相对路径重置，无绝对硬编码路径。

## 核心交付内容
1. 局域网媒体库与海报墙：
   - 原生支持 SMB 2/3 与 NFS 挂载浏览。
   - 智能刮削引擎与本地 .nfo 离线解析。
   - 双栏影视详情页、剧集横滑多季选集与格式徽章自动提取。
2. 独立音乐播放模式：
   - 折叠迷你状态与展开队列视图。
   - 包含本地音频库扫描与内嵌/外挂歌词同步滚动渲染。
3. 高级音频与多声道输出：
   - 5.1 与 7.1 离散声道 LPCM 直通。
4. 视觉主题与跨机同步：
   - 原厂四色全局主题（深灰、冰蓝、暖白、青瓷）。
   - 可选 iCloud 观看进度与剧集断点跨设备接力。
5. 官网与物料交付：
   - 官网地址：https://silkplayer.1999909.xyz
   - 18 张高清功能展示截图全量上线 Cloudflare CDN (/assets/screenshots/zh_01.png - zh_18.png)。
   - Pro 单机版与多设备版早鸟价 5 折标签放大呈现。
   - GitHub Actions CI 双分支流水线通过验证（Conclusion: success）。
