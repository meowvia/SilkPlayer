# SilkPlayer Pro 2.0.0 全流程发版与上线交付总览 / Release Handoff Archive

## 1. 工程与代码基准
- 前端开源工程 (LGPL-3.0)：`/Volumes/2T/Projects/SilkPlayer/SilkPlayer`
  - 分支：`main`（与 `release/2.0.0` 保持严格同步）
  - Commit 基准：`78025fa`（docs: align 2.0.0 documentation, theme names, and changelog with discipline standards）
  - 远程仓库：`origin` (SilkPlayer-Private.git) 与 `public` (SilkPlayer.git) 均已推送
  - GitHub Actions 流水线：`Test & Build (macOS)` 在 commit `9c3e0b3` 上顺利跑通（Conclusion: success，公开仓库绿标已亮）
- 闭源内核工程 (Proprietary)：`/Volumes/2T/Projects/SilkPlayer/SilkCoreKit`
  - 分支：`release/2.0.0`
  - Commit 基准：`7e1af5f`（feat(pro): 2.0.0 media library, scraper, nfo parser, and cloud sync implementation）
  - 隔离纪律：物理目录隔离存放，严禁向任何公开仓库合并或泄露源码
- Git 提交作者标准：`meowvia <meowvia@users.noreply.github.com>`
- 版本命名规范：统一去 `v` 前缀（`2.0.0`），镜像命名为 `SilkPlayer-2.0.0-universal.dmg`

## 2. 官方分发资产与校验和
- 物理存放路径：`/Volumes/2T/Projects/SilkPlayer/Website/downloads/`
- Universal 通用架构安装包（Apple Silicon + Intel）：
  - 文件名：`SilkPlayer-2.0.0-universal.dmg`（静态别名 `SilkPlayer-universal.dmg`）
  - 文件大小：约 23 MB
  - SHA-256 校验和：`baf1ca30f35e533355d53dfa491f7bd6b6c74c041bc593f9c223e49129562fdb`
- 架构依赖审计：所有内嵌动态库（FFmpeg 等）全部完成 `@rpath` 相对寻址绑定，无开发机绝对路径残留。

## 3. 2.0.0 核心功能与技术实现
- 局域网媒体库：原生实现 SMB 2/3 与 NFS 挂载，支持局域网自动发现、钥匙串凭证保存与断线自动重连。
- 海报墙与智能刮削：TMDB 中文元数据解析、高清海报抓取、演职员表提取；离线场景支持解析本地 `.nfo` 元数据。
- 双栏影视详情：大图背景视窗、剧集横滑多季选集卡片、分辨率/HDR/音频规格徽章自动提取。
- 独立音乐播放模式：支持折叠迷你状态栏与展开队列视图切换，提供本地音频库与内嵌/外挂歌词同步滚动。
- 高级音频直通：支持 5.1 / 7.1 离散声道 LPCM HDMI 与外接声卡直出。
- 四色全局主题：深灰（Dark Charcoal）、冰蓝（Ice Blue）、暖白（Warm Ivory）、青瓷（Celadon）。
- iCloud 进度接力：跨 Mac 设备自动同步观影断点与剧集已看标记（支持设置内按需关闭）。

## 4. 官方网站与全球加速 CDN 交付
- 生产服务入口：`https://silkplayer.1999909.xyz`（Cloudflare Pages，Zone ID: `ac360499b8663998691e9c949e56c1d9`）
- 本地工作目录：`/Volumes/2T/Projects/SilkPlayer/Website`
- 高清展示图床：全部 18 张高保真功能展示截图（`zh_01.png` - `zh_18.png`）部署于 Cloudflare 边缘 CDN（`/assets/screenshots/`），国内直连秒级加载。
- 早鸟价标签与视觉：
  - Pro 单机版：放大的早鸟价标识（`早鸟价 5 折`，原价 $19.99 现价 $9.99 买断）
  - Pro 多设备版：放大的推荐早鸟价标识（`早鸟价 5 折 - 推荐方案`，原价 $29.99 现价 $14.99 买断）
  - CSS 类 `.early-bird-badge`：字体 `1.05rem`，加粗 `700`，内边距 `0.45rem 1.6rem`，橙色发光微投影。
- 商业售卖通道已正式打通：
  - 移除原先弹出的“即将开放”阻断弹窗，购买按钮直接激活。
  - Pro 单机版结算直链：`https://www.creem.io/product/prod_5rwP78NkqvqfYhmSFCfVIv`
  - Pro 多设备版结算直链：`https://www.creem.io/product/prod_2XmrDZ9g4NMqXfieBTx4lu`
  - 结账页已测试：在国家下拉列表选择 China 即可使用支付宝扫码付款并实时按汇率折算人民币，支付成功后授权码即时发至邮箱。
- 部署状态：部署至 Cloudflare Pages（commit-dirty 版本），并全量刷新 Zone 边缘缓存，线上实测 HTTP 200 验证通过。

## 5. 宣发与社区物料
- 小众软件（Appinn）发帖模板：已严格按照小众软件发现频道标准规约生成标准纯中文发帖文稿，包含开发者第一人称自述、18 张 Cloudflare 边缘加速高清图直链、针对性图文注释，完全去除花哨 Emoji 与特殊标点符号。
- 中文发布说明：提取纯中文版 2.0.0 精简更新说明，沉淀于 `Documentation/RELEASE_NOTES_2.0.0.md`。

## 6. 后续待办与发版推进路线
- 正式发版操作（待用户指令下达）：
  1. 在 `SilkPlayer` 与 `SilkCoreKit` 仓库分别打标 Tag `2.0.0`；
  2. 推送 Tag 至 GitHub；
  3. 执行 `gh release create 2.0.0 SilkPlayer-2.0.0-universal.dmg` 上传发行资产；
  4. 运行 `Website/scripts/sync_release.sh 2.0.0` 确保官网边缘下载探针与 GitHub Release 资产完全对齐。
- 小众软件发帖：用户可直接复制已生成的标准文案前往社区发布。
