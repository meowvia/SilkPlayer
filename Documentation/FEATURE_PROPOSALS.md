# SilkPlayer 功能提案库 (Feature Proposals)

本文档为 SilkPlayer 唯一定点功能提案库，用于集中归档产品功能设想、交互逻辑设计与技术可行性分析。

管理准则:
1. 统一归口: 所有未经落地的新功能想法全部在此登记，严禁在其他地方散落记录；
2. 状态跟踪: 尚未落地、暂不着急实现的功能保持静默归档；
3. 闭环销项: 一旦某个功能在后续分支开发中成功落地验证，在此文档中划掉销项（注明落地版本）。

---

## 提案索引表 (Proposal Index)

| 提案编号 | 提案名称 | 状态 | 目标版本 |
| :--- | :--- | :--- | :--- |
| ~~提案 001~~ | ~~办公室防打扰模式 (摸鱼模式 / Boss Key)~~ | **已废弃删除** (偏离原生极简播放器定位) | **已废弃** |
| ~~提案 002~~ | ~~设置为默认播放器与格式关联管理 (Default Player)~~ | ~~待落地评估 (未开始)~~ **已落地销项** | **1.3.0** |
| 提案 003 | 原生轻量 SMB 局域网与 NAS 深度互联中枢 (Native SMB & NAS Pro Integration) | 待落地评估 (未开始) | **2.0.0+ 商业化 Pro 规划 (1.x 暂不部署)** |
| 提案 004 | 局域网轻量投屏功能 (DLNA / Screencast) | 待落地评估 (未开始) | 1.1.0 候选 |
| ~~提案 005~~ | ~~纯音频播放体验与原生极简封面动效 (Audio Artwork & Waveform)~~ | ~~待落地评估 (未开始)~~ **已落地销项** | **1.1.0** |
| ~~提案 006~~ | ~~音视频双轨独立列表与智能分流管理 (Dual-Track Media Playlist)~~ | ~~核心需求 2.4 已落地，主界面双轨待落地~~ **已落地销项** | **1.4.0** |
| 提案 007 | VP9 硬件加速解码与色彩管线 (VP9 Hardware Decoding) | 待落地评估 (未开始) | 1.5.0 候选 |
| 提案 008 | 外挂字幕自动检索与同名关联推荐 (External Subtitle Auto-Search) | 待落地评估 (未开始) | 1.5.0 候选 |
| 提案 009 | 杜比视界 Profile 5 动态色调映射与 macOS EDR 管线优化 (Dolby Vision Profile 5 EDR & DTM) | 待落地评估 (未开始) | 1.5.0 候选 |
| 提案 010 | 私有自用增强分支与端侧离线听译/网络流沙盒 (Personal Edition & On-Device ASR/Radio Pipeline) | 需求立项 (自用验证中) | 自用专用分支 / 待成熟毕业 |
| ~~提案 011~~ | ~~非原生预览格式文稿图标与品牌 Logo 占位替换 (Document Types Iconography & Fallback Branding)~~ | ~~正式立项 (下个版本解决)~~ **已落地销项** | **1.4.0** |
| 提案 012 | 智能片头片尾静默探测与无缝连播跳过 (Smart Opening/Ending Skip Pipeline) | 需求定稿 (技术方案就绪) | **1.7.0 核心排期** |
| 提案 013 | HDR10 与杜比视界动态 EDR 高光软滚降压制 (Dynamic EDR Tone-Mapping & Highlight Roll-off) | 需求定稿 (方案设计就绪) | **1.6.0 核心排期** |
| 提案 014 | 全场景大动态范围自适应画质重构与局部对比度增强 (SDR-to-EDR Dynamic Range Expansion) | 技术攻关立项 (算法探索) | 技术储备 (1.5.0 顺延) |
| ~~提案 015~~ | ~~播控栏交互式音量微调与起播防爆音安全锁 (Interactive Volume Popover & Pre-play Audio Safety Lock)~~ | ~~正式立项 (方案设计完成)~~ **已落地销项** | **1.5.0** |
| ~~提案 016~~ | ~~多文件夹与批量剧集导入全局智能自然排序 (Multi-Folder & Batch Episode Intelligent Natural Sorting)~~ | ~~正式立项 (方案设计完成)~~ **已落地销项** | **1.5.0** |
| ~~提案 017~~ | ~~全链路系统级资源占用优化与高频空转治理 (System-wide Performance & Resource Footprint Optimization)~~ | ~~正式立项 (方案就绪)~~ **已落地销项** | **1.5.0** |
| 提案 018 | 偏好设置模块 macOS HIG 规范化全量重构 (Native Settings HIG Architecture & Design Overhaul) | 正式立项 (方案设计完成) | **1.6.0 核心排期** |
| 提案 019 | 播放列表侧边拉手边框贴合与极简透明线框重构 (Playlist Drawer Handle Border-Flush & Transparent Stroke Redesign) | 正式立项 (设计定稿) | **1.6.0 核心排期** |
| 提案 020 | 智能静默更新检测、周级克制频控与用户数据无损在位覆盖安装 (Smart Silent Update, Weekly Cadence & Lossless In-Place Overwrite Installer) | 正式立项 (方案设计完成) | **1.6.0 核心排期** |
| 提案 021 | 播控栏与进度条无底框全景纯悬浮化重构 (Cinema-Embedded Canvas HUD) | 正式立项 (设计定稿) | **1.7.0 核心排期** |


---

## ~~提案 001: 办公室防打扰模式 (摸鱼模式 / Boss Key)~~ [已正式废弃删除]

### 1. 提案背景与市场价值
- 目标人群: 办公室上班族、多任务场景下需要快速隐蔽音画播放的用户。
- 传播属性: 具有天然的社交与社区讨论度，适合在 V2EX、小众软件、少数派等独立开发者与数码社区作为版本特色功能进行营销引流。
- 产品定位: 实验性低频趣味功能，服务于特定场景下的隐私保护。

### 2. 原始方案缺陷与风险规避
原始设想: 检测到光标移动一定幅度，直接销毁前台播放。
该设计存在三个严重缺陷，正式方案中予以否决:
1. 误触率过高: 用户正常观影时调节音量、拖动时间轴、挪动鼠标或桌面轻微晃动极易发生误触发，严重破坏观影连续性。
2. 动作破坏性过大: 直接销毁播放会导致解码管线释放、播放进度丢失、缓冲区重置，事后无法快速恢复播放。
3. 系统权限门槛高: 若要在非激活状态下全局监听鼠标移动，必须向用户索取 macOS Accessibility (辅助功能) 权限，极易引发用户对隐私和安全性的质疑。

### 3. 落地实施方案 (推荐设计)
#### 3.1 触发机制 (定向盲操，零误触)
- 机制 A (热角甩动): 当播放器处于前台时，用户受惊慌快速将光标甩向屏幕指定角落 (如左上角)，触发阈值基于边界命中而非普通位移。
- 机制 B (极简盲按按键): 快速连击两次 Esc 键，或使用系统全局快捷键 (如 Cmd + Option + H)。

#### 3.2 响应动作 (静音隐藏与挂起)
- 瞬间静音: SilkAudioEngine 立即将硬件增益切为 0，防止由于耳机脱落或静音延迟导致声音外泄。
- 窗口隐藏: 播放器窗口瞬间隐藏 (orderOut 或 NSApp.hide)，停止 CAMetalLayer 渲染。
- 状态挂起: 记录微秒级断点时间戳，挂起解码管线，内存进入极低休眠状态。

#### 3.3 恢复机制
- 危机解除后，点击 macOS 菜单栏图标或再次按下快捷键，窗口原位呼出，并在 0.1 秒内无缝继续播放。

#### 3.4 权限与合规
- 仅在前台窗口内或通过标准系统热键机制实现，严禁调用全局 CGEventTap，不申请辅助功能权限，保持轻量与纯净。

### 4. 废弃决议归档 (2026-11-07)
- **决议结论**: 经项目架构与产品定位全面审核，该功能属于低频非核心实验设想，极易产生误触风险，且与 SilkPlayer 极致轻量、极简专业的专业本地媒体播放器定位相背离；
- **当前状态**: **已正式废弃删除**，自 1.6.0 规划序列中永久剔除，不再进行任何研发与维护。

---

## ~~提案 002: 设置为默认播放器与格式关联管理 (Default Player & Format Associations)~~ [已在 1.3.0 落地销项]

### 1. 提案背景与设计哲学
- 零侵扰原则: 严禁在应用冷启动或更新时弹窗强行索要默认播放器权限。弹窗索权是国产流氓软件的典型特征，极易引起 macOS 核心用户群体的反感与卸载。
- 显式用户意图: 将选择权完全归还用户，仅在系统设置面板中提供明确、克制的操作入口。
- 一站式统合: 将设为默认播放器与常见媒体容器格式关联深度统合，用户点击一次即可完成全格式接管，也可按需自定义格式范围。

### 2. 交互与功能架构
#### 2.1 设置面板入口布局
- 归属模块: SilkSettingsView (设置面板) 的通用 (General) 选项卡。
- 视觉与交互呈现:
  - 状态指示: 实时检测当前系统默认状态，展示 已是系统默认播放器 或 未完全关联。
  - 操作按钮: 提供 一键设为默认播放器 按钮。
  - 展开明细 (高级选项): 允许用户按分类勾选关联范围，如常见视频格式 (MP4, MKV, MOV, WebM, AVI, TS, M2TS, FLV 等)、音频容器格式或蓝光原盘镜像文件。

#### 2.2 行为守则
- 启动静默: 播放器生命周期内绝不主动弹出任何提示关联格式的对话框或通知横幅。
- 权限尊重: 若系统提示打开方式确认，遵循 macOS 原生 Launch Services 规范处理，不劫持系统关联。

### 3. 技术实现路径
#### 3.1 补充 Info.plist 的 UTI 与文件扩展名声明
- 现状分析: Resources/Info.plist 当前仅声明了基础系统级 UTI (public.movie, public.video, public.avi, com.apple.quicktime-movie, public.mpeg-4)。
- 改造任务:
  - 扩展 CFBundleDocumentTypes，加入 MKV (org.matroska.mkv), WebM (org.webmproject.webm), TS (public.mpeg-ts), FLV 等现代视频容器类型与对应文件后缀；
  - 声明 UTImportedTypeDeclarations，确保系统识别所有未注册公版格式。

#### 3.2 系统级关联接口封装 (Launch Services)
- 后台服务: 封装 FormatAssociationService，通过 CoreServices / LaunchServices 底层接口或 NSWorkspace 进行批量注册。
- 关键系统 API:
  - LSSetDefaultRoleHandlerForContentType: 为每个目标媒体 UTI 设置默认 Viewer 角色为 com.silkplayer.SilkPlayer；
  - LSCopyDefaultRoleHandlerForContentType: 用于打开设置页面时读取当前每类格式的实际默认处理器，并反显状态。

### 4. 落地销项记录
- **落地版本**: **1.3.0**；
- **落地验证**: 核心服务 `FormatAssociationService` 已全面打通 `LSSetDefaultRoleHandlerForContentType` 批量绑定，`SilkSettingsView` 支持实时检测与按需点击关联，`LSHandlerRank` 设为 `Alternate` 确保对系统纯净零侵扰；冷启动默认播放器提示弹窗成功拦截并收拢为显式意图。相关单元测试与 CI 流水线全绿跑通。

---

## 提案 003: 原生轻量 SMB 局域网与 NAS 深度互联中枢 (Native SMB & NAS Pro Integration)

### 1. 提案背景、商业价值与核心原则
- **商业化分层锚点 (Pro Feature)**:
  - 本地单机媒体播放（本地磁盘拖拽即播、硬件加速、基础双列表）作为免费基本盘；
  - 局域网直连、NAS 深度挂载、网络硬盘盒集成、SMB/NFS/WebDAV 协议穿透与专用大缓存流式管线，定位于面向高端视听与 Homelab 用户的核心商业化高阶功能；
- **历史版本永久免费不撤回原则**:
  - 在商业收费机制正式落地之前发布的所有历史版本（包括 1.5.0、1.6.0 等），均永久保持免费且全功能分发，绝不回撤、绝不人为暗中劣化，树立极高社区声誉；
- **当前机制与未来收拢收口**:
  - **现状过渡**: 当前版本中，通过 macOS Finder 挂载到 `/Volumes/` 的网络硬盘盒与 NAS 共享，仍以普通文件路径兼容读取；
  - **未来收拢**: 后续收费大版本中，通过 `URLResourceKey.volumeIsLocalKey` 与文件系统类型识别区分物理磁盘与网络卷，将局域网网络存储读取从通用文件读取中剥离收拢，统一整合至独立的【局域网 / NAS 中枢】高阶模块中，作为商业授权的核心权益。

### 2. 交互与功能架构
#### 2.1 入口与呈现 (统一抽屉整合)
- 入口内聚: 收拢在播放窗口右侧已有的统一抽屉 (SilkUnifiedDrawerView) 中，顶部提供极简分段: [ 播放列表 | 局域网 ]。
- 系统挂载零配置秒开: 自动读取系统 /Volumes/ 下已挂载的网络宗卷 (如用户在访达中已连接的 NAS)，直接以网络驱动器图标呈现，点开即浏览，零配置零表单。
- 局域网发现 (Bonjour): 后台利用 _smb._tcp 静默发现局域网内的存储设备，列出设备友好名称 (如 "Debian 业务机", "群晖 NAS")。
- 单步凭据输入: 仅在初次点击未登录设备时，弹出仿原生访达风格的单步简易小条 (用户名/密码/访客)，凭据自动加密保存至 macOS 钥匙串 (Keychain)。

#### 2.2 播放联动
- 目录树点播: 点击视频直接加入主窗口播放并起播，自动加载同目录关联字幕。

### 3. 技术实现路径
- 系统内核级挂载: 优先采用 macOS 原生 NetFS / mount_smbfs 机制，挂载后文件作为标准 POSIX 路径供播放器调用。
- 解码管线零侵入: 现有的 FFmpeg 解码、Metal 硬件着色渲染、杜比视界 Profile 5 校正 100% 原生复用，无需重写底层 I/O。

### 4. 版本规划建议
- **执行时间节点**: 严格定位于 **2.0.0 商业化大版本及以后阶段**实施；
- **核心开发纪律**: 在 2.0.0 实施之前（整个 1.x 分支生命周期内），局域网/NAS 配置全部静默挂起，不进行任何形式的编码与功能部署，全力集中资源打造 1.x 本地播放极致体验（HIG 设置重构、拉手微调、智能静默更新管道演练）；
- 结合本地激活码授权机制（Moyin 授权服务 `license.1999909.xyz`），在 2.0.0 形成免费基线版与 Pro 版的清晰商业价值阶梯。

---

## 提案 004: 局域网无损投屏功能 (Screencast / DLNA & AirPlay)

### 1. 提案背景与设计哲学
- 核心场景: 用户在 Mac mini / MacBook 上播放高清本地或 NAS 视频时，一键无损投送到客厅电视或投影仪。
- 轻量原则: Mac 端作为极轻量流媒体中继与遥控器，电视端自主拉流硬解，Mac 端 CPU 与 GPU 占用近乎为 0。

### 2. 交互与功能架构
#### 2.1 触发与选择
- 入口布局: 在播放控制条 (PlayerHUDView) 右上角增加极简投屏气泡图标。
- 浮层展开: 点击弹出磨砂半透明 Popover，实时展示局域网扫描到的智能电视/盒子列表及状态。

#### 2.2 投屏中控模式
- 画面联动: 选中设备后，本地窗口转入轻量投屏占位面板 (显示正在投屏设备名称)，本地静音挂起。
- 遥控联动: 本地播放进度条、播放/暂停、快进快退按键直接映射为向电视下发的控制指令，实时同步远端播放进度。

### 3. 技术实现路径
#### 3.1 本地微型流服务器 (SilkCastStreamer)
- 基于 Apple 原生 Network.framework (NWListener) 实现自包含嵌入式 HTTP Range Server。
- 仅响应带 Range 头的 HTTP GET 分段读取请求，随投屏启动，随投屏结束销毁，零常驻开销。

#### 3.2 设备发现与控制 (SilkDLNAEngine)
- 基于 SSDP (UDP 组播 239.255.255.250:1900) 发现局域网 MediaRenderer 设备。
- 封装轻量 SOAP XML 协议下发 SetAVTransportURI、Play、Pause、Seek 指令。

#### 3.3 与 SMB 协同
- 当投屏 NAS 视频时，Mac 作为轻量中继代理，直接将 NAS 流透明分发给电视，电视端免配任何凭据即可播放。

### 4. 版本规划建议
- 纳入 1.1.0 局域网能力阶段规划，与提案 003 协同演进。

---

## ~~提案 005: 纯音频播放体验与原生极简封面动效 (Audio Artwork & Waveform)~~ [已在 1.1.0 落地销项]

> 状态: 已落地销项 (2026-10-15 随 1.1.0 正式发布，包含黑胶旋转动效、音频声波光晕、32 频段音频频谱、即将播放曲目无缝预览及全格式音频支持)。

### 1. 提案背景与设计哲学
- 解决痛点: 修复 Issue #2 (MP3/FLAC 纯音频文件无法播放且显示无音频) 后，用户播放音频时若面对纯黑背景，缺乏视觉反馈，难以判断播放状态。
- 原生轻量原则: 坚决拒绝重度音乐播放器花哨臃肿的 3D 渲染与全屏粒子动效。严格坚守轻量、性能低占用的产品底线，CPU 与 GPU 附加占用必须严格限制在 0.5% 以内。
- 用户惊喜感: 通过高精度提取内嵌封面、原生磨砂材质融合与极低开销的优雅声波律动，提供丝滑精致的原生 macOS 影音工具质感。

### 2. 交互与视觉架构
#### 2.1 纯音频画面布局
- 居中专辑封面: 提取音频文件内嵌的专辑封面 (ID3v2 APIC / FLAC Picture)，以 Apple Music 风格的微圆角与柔和投影居中呈现 (标准尺寸 240x240 或 300x300)。
- 动态磨砂背景: 提取封面主色调并施加系统级层叠磨砂虚化 (NSVisualEffectView)，随歌曲切换平滑淡入。
- 无封面兜底: 当音频未包含内嵌封面时，显示精致的极简黑胶唱片或声波矢量占位图标，避免界面空洞。

#### 2.2 极简音频动效 (微功耗设计)
- 严禁重型渲染: 严禁采用高帧率全频段 FFT 复杂频谱分析或高开销 Metal 着色器计算。
- 方案 A (极简声波微动): 在封面下方或 HUD 旁展示仿 Apple 播客风格的 4 柱微型原生声波条，基于当前音量电平 (RMS/Peak) 做微秒级弹簧律动。
- 方案 B (黑胶唱片缓速旋转): 纯 CoreAnimation 硬件变换，播放时以 33 RPM 极低帧率匀速缓转，暂停时缓停，GPU 占用近乎为 0。
- 节能挂起策略: 窗口最小化、失去屏幕可见性或进入后台时，立即暂停动效定时器，能耗彻底归零。

### 3. 技术实现路径
#### 3.1 封面提取与内存缓存
- FFmpeg 提取: 在 SilkDemuxer 中识别 AV_DISPOSITION_ATTACHED_PIC 类型的视频包，仅在解封装阶段解出单张图像并转换为 CGImage。
- 静态缓存: 将提取到的封面缓存于当前 MediaItem 中，内存占用低于 1MB，切歌时自动释放。

#### 3.2 底层时钟与音频流解封装
- 结合 FIX-001 修复，在 SilkDemuxer 中放开纯音频返回门禁 (videoStreamIndex >= 0 || audioStreamIndex >= 0)。
- 在 SilkPlayerEngine 中建立独立音频时钟循环，持续以 15Hz 频率回调 engineDidUpdateTime，确保时间轴与进度条平稳推进。

### 4. 实施阶段建议
- P0 阶段: 在修复 Issue #2 底层解码与播放时钟的同时，优先完成内嵌封面的静态提取与居中渲染。
- P1 阶段: 在独立实验分支中评估微型声波律动动效，经能耗与性能实测达标后再行合并。

---

## 提案 006: 音视频双轨独立列表与智能分流管理 (Dual-Track Media Playlist & Smart Classification)

### 1. 提案背景与核心用户痛点
- 痛点现状: 播放器支持视频播放与纯音频（黑胶唱机模式），但底层播放列表目前为单一数组混合存储。用户导入混合媒体（如既有电影连续剧，又有包含数百首歌曲的音乐文件夹）后，所有文件混杂在一起；
- 体验撕裂:
  1. 切歌串台: 听歌切歌时偶发冷不丁跳出一段电影，或观影连续播放时突然插入一首 MP3；
  2. 窗口几何突变: 音视频串台直接诱发 16:9 宽屏视频窗口与 1:1 黑胶正方形窗口之间的剧烈跳变与重绘；
  3. 洗牌队列污染: Fisher-Yates 洗牌卡牌堆在混合库中无法做到纯粹的音乐洗牌。

### 2. 核心架构设计 (双轨物理隔离 + 智能分流)

#### 2.1 数据与存储隔离
- 在 `PlaylistManager` 中将单数组架构升级为双轨独立存储：
  - `videoItems: [PlaylistItem]` (电影、剧集、短视频)
  - `audioItems: [PlaylistItem]` (无损音乐、歌曲、播客)
  - `activeCategory: MediaCategory` (`.video` 或 `.audio`)
- 分别持久化于 `UserDefaults`：`com.silkplayer.playlist.video` 与 `com.silkplayer.playlist.audio`，各轨独立记录播放索引与游标。

#### 2.2 智能自动识别与分流引擎
- 基于现有 `MediaFileClassifier.classify(url)` 原生哈希比对（已覆盖 17 种主流视频与 25 种无损音频格式）；
- 拖入或导入任何单文件、多文件或复合文件夹时，底层自动毫秒级分流：
  - 音频文件自动归入音乐库；
  - 视频文件自动归入视频库；
  - 彻底杜绝交叉污染，用户无需手动归类。

#### 2.3 洗牌与播放流转纯净化
- 洗牌卡牌堆（`shuffleQueue`）仅针对当前激活分类构建；
- 处于音乐模式时，380 首歌曲在自身库内独立洗牌、无放回消费；切歌、下一曲、上一曲绝对不溢出到视频库。

#### 2.4 空列表且随机模式下导入媒体的首曲洗牌优化 (Shuffle-First Import on Empty Playlist) [已在 1.3.0 落地]
- 痛点: 播放列表为空时，导入媒体/文件夹始终固定播放第一首。若处于随机播放模式，每次导入都强制听第一首，影响测试与日常体验；
- 优化方案: 当 `playbackMode == .shuffle` 且列表为空时，导入后立即基于洗牌算法随机抽取一首起播，其余曲目无放回入池。（已在 1.3.0 落地验证，见 `PlaylistManager.appendItems` 与回归测试 Test 53）。

#### 2.5 剧集长文件名智能净化与四级容错管道 (MediaFilenameSanitizer) [排期 1.4.0 核心实现]
- 痛点现状: 网络下载影视资源文件名冗长且充斥广告水印（如 `[最新电影www.dyg7.com]`）与压制参数，默认中间截断（`.middle`）恰好将关键的季集数（`S02E01`）吞噬，导致多行剧集视觉上完全雷同，用户无法分辨具体集数；
- 架构实现 (不改变抽屉宽度与排版框架的前提下实施四级级联容错)：
  1. 第 1 级（行首剧集徽标识别）: 纯本地轻量正则解析 `S(\d+)E(\d+)`、`EP(\d+)`、`第(\d+)集`、` - (\d+) `，匹配成功将左侧默认列表行号（如 `01`）直接替换为高亮集数徽标（如 `E01`）；未匹配则自然回退列表行号；
  2. 第 2 级（广告与压制去噪）: 智能过滤方括号内网址广告、发布组标签与非必要视频参数（如 `1080p`, `x265`, `HD中英双字`），腾出横向空间；改用 `.tail` 尾部截断，保留完整剧名；
  3. 第 3 级（双行紧凑信息架构）: 第一行纯净剧名，第二行时长与弱化元数据；
  4. 第 4 级（原生 Tooltip 悬停兜底）: 为每行附加 `.help(item.title)`，悬停瞬间浮显完整原始路径，兜底极端非标命名。
- 性能与非破坏性原则: 纯内存字符串即时处理，单项解析耗时 < 0.01ms，保证列表 120fps 满血滚动；底层物理文件路径与播放核心状态 100% 保持原汁原味。

### 3. 紧凑原生交互设计 (严格保持现有侧边栏宽度)
- 宽度规范: 抽屉宽度严格保持现有 200~240pt 原生紧凑尺寸，不因为新增功能改变侧边栏尺寸；
- 候选界面形态:
  - 方案 A (推荐 · 标题原生下拉式): 顶栏文字为 `音乐列表 378 ⌄`，点击呼出原生磨砂气泡菜单切换 `视频列表 0`，占用空间与现有完全一致；
  - 方案 B (紧凑图标胶囊): 采用 SF Symbols 微型矢量线框图标 `[ 音符图标 378 | 胶片图标 0 ]`，总宽度仅约 80pt，视觉呼吸感极佳。
- 底部操作隔离:
  - 处于音乐页时，`一键清空` 明确提示并仅清空音乐，绝不误伤视频列表；
  - `+ 添加媒体...` 默认优先筛选对应分类。

### 4. 场景状态机设计 (生命周期完备性)
- 冷启动: 记录 `lastActiveCategory`，自然冷启恢复上次退出状态；双击外部媒体冷启时精准进入目标模式，同时完整保护另一轨道的历史资产；
- 热运行导入: 拖至主视口视为立即播放该媒体，拖至侧边栏抽屉视为静默收纳分流；
- 跨模态唤醒: 播放音乐中途从外部打开视频时，安全挂起音乐断点，切入视频模式；切回音乐时可精准断点续播。

### 5. 版本规划建议
- 主界面双轨列表纳入 **1.4.0 核心里程碑**进行系统级状态机重构与专项交付。

---

## 提案 007: VP9 硬件加速解码与色彩管线 (VP9 Hardware Accelerated Decoding)

### 1. 提案背景与技术价值
- 现状分析: YouTube、Bilibili 及部分 WebM 封装的 4K/8K 视频广泛使用 VP9 编码。当前解码管线优先走 VideoToolbox 硬件解码器，当遇到部分非标准 VP9 封装时可能回退至软解，引发高分辨率高帧率下的 CPU 负载上升与发热；
- 优化目标: 在 Apple Silicon 平台上利用系统原生 VideoToolbox `kCMVideoCodecType_VP9` 硬件解码能力，打通基于 IOSurface 的零拷贝直出至 Metal 渲染管线。

### 2. 实施方案
- 解码器扩展: 在 `SilkCoreKit/SilkVideoToolboxDecoder.swift` 中检测系统对 VP9 硬件解码的支持情况（`VTIsHardwareDecodeSupported(kCMVideoCodecType_VP9)`）；
- 容器解析支持: 完善 WebM / MKV 容器中 VP9 `Csd`（Codec Private Data）解析，正确构建 `CMFormatDescription`；
- 色彩管线适配: 适配 VP9 Profile 0（8-bit BT.709）与 Profile 2（10-bit BT.2020 PQ/HLG），无缝复用现有 Metal 色彩转换着色器。

---

## 提案 008: 外挂字幕自动检索与同名关联推荐 (External Subtitle Auto-Search & Matching)

### 1. 提案背景与用户痛点
- 痛点现状: 用户观影时常有外挂字幕需求（如 `.srt`、`.ass`、`.vtt`）。目前播放器支持同目录同名自动加载以及手动点击“加载外挂字幕...”，但在多字幕文件同目录（如命名带有语言后缀 `.chs.srt`、`.cht.ass`、`.en.srt`）或同级 `Subs/` 目录时，需用户频繁手动选取；
- 优化目标: 建立标准化同目录与子目录字幕模糊匹配机制，提升外挂字幕加载效率。

### 2. 实施方案
- 智能扫描策略:
  1. 同级目录扫描: 当加载媒体 `video.mkv` 时，异步扫描同级目录下所有以 `video.` 开头且扩展名为支持字幕格式的文件；
  2. 常用子目录扫描: 递归检查同级 `Subs/`、`subtitles/`、`Sub/` 子目录；
  3. 语言标签解析: 从文件名提取语言标记（如 `chs`, `cht`, `zh`, `en`, `ja` 等）并展示在字幕轨选择菜单中；
- 非阻塞异步处理: 在后台线程执行扫描与比对，通过主线程通知 `PlayerCore` 刷新 `subtitleTracks` 列表，绝不阻塞音视频起播链路。

---

## 提案 009: 杜比视界 Profile 5 动态色调映射与 macOS EDR 管线优化 (Dolby Vision Profile 5 EDR & DTM)

### 1. 提案背景与技术价值
- 现状分析: SilkPlayer 目前已完成基于 FFmpeg RPU 解析与原生 Metal 着色器的基础杜比视界 Profile 5 色彩重构（IPTPQc2 $\to$ LMS $\to$ Display P3），成功实现跨 MP4/MKV/TS 容器的自主可控渲染。但在高动态范围高光映射与苹果 Liquid Retina XDR 屏幕硬件协同上，距离行业高标（如 Infuse 依赖系统闭源管线的表现）仍有提升空间；
- 优化目标: 在不依赖苹果私有播放器黑盒的前提下，将自主 Metal 渲染管线升级为具备帧级动态色调映射（Dynamic Tone Mapping / DTM）与原生 EDR 硬件动态感知能力的标准级方案。

### 2. 实施方案
#### 2.1 帧级 L1/L2 动态色调映射（Tone Mapping Engine）
- 在着色器中接入杜比 L1 动态元数据（`max_pq`, `min_pq`, `avg_pq`）与 L2 显示目标数据；
- 实现标准 Hermite / Bezier 色调曲线拟合，将 1,000 ~ 4,000 尼特母带高光自适应压缩至目标显示器物理动态范围，消除高光死白与暗场细节丢失。

#### 2.2 macOS 原生 EDR 管线深度适配
- 配置 `CAMetalLayer` 为 `wantsExtendedDynamicRangeContent = true` 与 `CGColorSpace.extendedLinearDisplayP3` 色彩空间；
- 监听 `NSScreen.maximumPotentialExtendedDynamicRangeColorComponentValue`，根据屏幕实际 EDR 动态余量动态调节着色器线性光输出倍率。

#### 2.3 工程化合成测试矩阵（Synthetic Test Matrix）
- 引入开源基准工具 `dovi_tool`，基于短片源自动化合成覆盖 100 ~ 10,000 尼特、多段多项式（1 ~ 8 段）、不同码率与容器封装的极端基准测试样本集，保障极端边缘场景下的渲染鲁棒性。

---

## 提案 010: 私有自用增强分支与端侧离线听译/网络流沙盒 (Personal Edition & On-Device ASR/Radio Pipeline)

### 1. 提案背景与设计哲学
- 背景动因:
  1. 规避公共合规风险: 针对网络电台/直播流（特别涉及跨境与港台信源）以及潜在的特殊题材音视频即时字幕翻译，若在公开版本中直接内置或提供中心化服务，存在极高法律监管与服务商封禁风险；
  2. 满足开发者自用深度体验: 开发者个人具有高质量网络广播日常收听、Homelab 内网视听源挂载、以及特定片源即时字幕翻译的真实高频刚需；
  3. 双轨隔离原则: 确立“公开版专注极致轻量无感、零外部资源纯中立；自用版承载实验性高阶特性、自备算力与资源”的双轨策略。

### 2. 双版本隔离架构设计
- 核心代码统一基准:
  - 核心播放内核与主界面架构不分叉，避免多分支合并地狱；
  - 采用**“通用能力沉淀在主干，私有资源与实验逻辑通过环境隔离”**的设计模式：
    - 方案 A（本地配置挂载，首选）: 播放器检测本地专用路径（如 `~/Library/Application Support/SilkPlayer/personal_config.json` 或私有 M3U），命中后动态激活“自用电台/Homelab 直播”面板；公开用户环境无该文件，界面保持极简；
    - 方案 B（私有分支编译宏）: 在私有仓库 `SilkPlayer-Private` 中建立 `feature/personal-workspace`，通过 `#if SILK_PERSONAL_BUILD` 条件编译注入私有资产。

### 3. 端侧离线即时听译方案 (ASR & Subtitle Translation)
#### 3.1 解决拖拽 Seek 断流痛点的工程逻辑
- 摒弃播放时实时麦克风抓取的流式方案，改用**“起播即后台超速预提取索引（Background Fast-Indexing）”**：
  - 视频加载后立即起播画面（零等待）；
  - 后台低优先级线程以 30x~50x 速度快速抽取音频并送入 Apple Silicon NPU 本地推理（基于 CoreML 的 SenseVoice-Small 或 Whisper Turbo）；
  - 10~20 秒内构建出全片毫秒级对齐的字幕时间轴（Cue List），确保用户任意拖动进度条时字幕能够瞬间命中。
#### 3.2 离线翻译管道
- 本地利用 macOS 15+ 原生 `Translation.framework`（系统自带神经网络离线翻译，免 Key、零费用），或配置个人私有无审查 LLM API 端点进行对照翻译；
- 自用版先行验证模型吞吐量、热量控制与拖拽响应体验；待技术完全成熟、无合规与成本风险后再评估向正式版毕业的可能。

### 4. 自用网络广播与内网流媒体
- 仅在自用环境挂载预设的国内外精选高音质音乐电台，以及直连 Homelab 自建 IPTV（如 `http://192.168.100.234:35455/live.m3u`）；
- 公开发布版严格遵循“纯中立播放器原则”，绝不内置任何预设频道。

---

## 提案 011: 非原生预览格式文稿图标与品牌 Logo 占位替换 (Document Types Iconography & Fallback Branding)

### 1. 提案背景与用户痛点
- 痛点现状:
  - macOS 系统的 QuickLook 仅对苹果原生支持的封装与编码（如 `.mp4`, `.mov`, `.m4v`）自动解码抽帧生成视频画面缩略图；
  - 对于海量非苹果原生格式（如 `.mkv`, `.webm`, `.flv`, `.avi`, `.ts`, `.rmvb`, `.wmv`），系统无法生成画面缩略图，Finder 会自动回退展示默认打开该文件的 App 所提供的“文稿图标（Document Icon）”；
  - SilkPlayer 当前 `Resources/Info.plist` 的 `CFBundleDocumentTypes` 与 `UTImportedTypeDeclarations` 中完全缺失 `CFBundleTypeIconFile`、`CFBundleTypeIconSystemGenerated` 与 `UTTypeIconFile` 声明，且资源目录缺失专注文档图标文件；
  - 导致用户将 SilkPlayer 设为系统默认播放器后，所有非原生格式在 Finder 中全部降级显示为 macOS 最底层的“空白白纸”无特征图标，严重削弱了产品的视觉品质感，让用户产生“文件损坏或未被正确识别”的负面心理。
- 目标定位:
  - **纳入 1.4.0 核心排期解决**；
  - 凡被 SilkPlayer 设为默认打开的媒体格式，若系统本身不具备画面缩略图/预览图，在 Finder 中一律强制使用 SilkPlayer 品牌 Logo / 规范折角文稿图标进行占位替换。

### 2. 实施方案与技术路径
#### 2.1 现代 macOS 原生文稿图标系统合成 (`CFBundleTypeIconSystemGenerated`)
- 在 `Resources/Info.plist` 的 `CFBundleDocumentTypes`（针对 `Video Media` 与 `Audio Media`）中添加并激活：
  ```xml
  <key>CFBundleTypeIconSystemGenerated</key>
  <true/>
  ```
- 启用后，macOS 11~15+ 系统渲染器会自动以 Apple 规范的拟物折角文稿纸为基底，将 SilkPlayer 官方 AppIcon 居中置入，并在右下角带上规范的扩展名文字标签（如 MKV, AVI, FLV），实现系统级自然融合。

#### 2.2 专有文稿图标资产与声明绑定 (`CFBundleTypeIconFile` & `UTTypeIconFile`)
- 在 `Resources/` 目录中打包标准高清文稿图标资产 `DocumentIcon.icns`（带微弧光泽与播放器胶卷质感）；
- 在 `CFBundleDocumentTypes` 中显式绑定 `<key>CFBundleTypeIconFile</key><string>DocumentIcon</string>`；
- 在 `UTImportedTypeDeclarations` 的每个非原生媒体声明中（`org.matroska.mkv`, `org.webmproject.webm`, `com.adobe.flash.video`, `public.avi` 等）同步补充 `<key>UTTypeIconFile</key><string>DocumentIcon</string>`，确保所有回退链路 100% 封闭覆盖。

### 3. 验收标准
1. 在全新机器或测试环境中安装构建的 SilkPlayer 并执行“设为默认播放器”；
2. 检查桌面与下载目录下的 `.mkv`, `.flv`, `.webm`, `.avi`, `.wmv` 等文件；
3. 验证所有无原生视频缩略图的文件在 Finder 各种视图（图标、列表、分栏、画廊）下，均整齐划一展示带有 SilkPlayer Logo 的高清晰度文稿图标，彻底杜绝“空白白纸文稿”现象。

---

## 提案 012: 智能片头与片尾识别与跳过管线 (Smart Intro & Credits Detection Pipeline)

### 1. 提案背景与技术挑战
- **排期规划**: **1.7.0 核心排期**；
- **场景痛点**:
  - 美剧与现代剧集普遍采用冷开场（Cold Open）叙事结构，在播放数分钟正片剧情后才切入片头主题曲，且各集冷开场时长高度不固定（例如第 1 集为 01:30 - 02:45，第 2 集为 05:10 - 06:25）；
  - 传统固定秒数跳过逻辑（如固定跳过前 90 秒）在美剧场景下会导致核心剧情被截断；
  - 部分剧集（如《绝命毒师》）仅有 3-5 秒短标题卡，或特定集数完全无片头仅有片尾，直接强行跳转容易产生误跳事故；
  - 单机原生播放器无法采用云端服务端耗时数小时预先离线分析的重型方案，必须在 SMB / WebDAV 等网络挂载和低功耗限制下实现低延迟探测。
- **目标定位**:
  - **纳入 1.5.0 核心排期**；
  - 建立精准、轻量、可撤销的端侧剧集片头与片尾探测管线。

### 2. 架构设计与技术路径 (三层探测架构)
#### 2.1 第一层：容器章节语义快速解析 (Chapter Semantic Parser)
- **触发时机**: 文件打开与解复用（Demuxing）阶段，耗时 < 1ms，零 CPU 与 I/O 额外开销；
- **匹配规则**: `SilkDemuxer` 读取媒体容器的 Chapter 结构，使用正则匹配章节名称：
  - 片头关键词: `(?i)^(intro|opening|op|cold[ _-]?open|片头)`
  - 片尾关键词: `(?i)^(outro|credits|ed|ending|片尾)`
- **输出**: 若成功匹配语义标签，直接提取精准时间区间 `[startTime, endTime]`。

#### 2.2 第二层：播放列表跨集音频指纹互相关引擎 (Cross-Episode Chromaprint Engine)
- **触发条件**: 容器无语义章节信息，且当前播放列表中存在同目录或命名模式一致的同季多集视频（>= 2 集）；
- **低功耗提取**:
  - 由后台 Swift Concurrency Actor（`priority: .utility`）接管，仅抽取前 10 分钟单声道 8kHz/16kHz 音频流；
  - 网络挂载（SMB/WebDAV）环境下严格限制并发流读取速度，杜绝 I/O 风暴；
- **互相关匹配**:
  - 计算音频频谱色度特征指纹（Chromaprint / Acoustic Fingerprint）；
  - 采用滑动窗口互相关（Cross-Correlation）算法，搜索两集之间重合度 > 88%、持续时长 20s - 120s 的共同音频序列，计算出该集片头的绝对起止时间戳；
- **本地持久化**: 探测结果存入本地轻量缓存（基于文件头部校验哈希），同一剧集只计算一次。

#### 2.3 第三层：交互浮层与防误触撤销机制 (OSD Bubble & Safety Fallback)
- **浮层提示**: 播放进度步入片头区间时，画面右下角淡入悬浮气泡：“跳过片头 [Space / Return] (5s 倒计时)”；
- **自动跳过配置**: 在偏好设置提供“自动跳过片头/片尾”开关（默认关闭）；
- **瞬时撤销**: 发生自动跳过后，OSD 显示“已跳过片头 01:25 - 02:40 [按 Z 撤销]”，用户在 3 秒内触发快捷键可瞬间回跳，防范算法误判导致的剧情丢失。

### 3. 验收标准
1. 具有规范 Chapter 章节标签的 MKV/MP4 视频，起播后精准在片头区间触发提示并可无缝跳转；
2. 针对无章节标签但同季多集的美剧，在后台静默提取音频指纹后准确计算出带有不同冷开场时长的片头区间；
3. 纯音频播放模式与单集独立视频模式下，不启动跨集比对，保障系统资源零消耗；
4. 任何跳转行为均具备单键撤销链路。

---

## 提案 013: HDR10 与杜比视界动态 EDR 高光软滚降压制 (Dynamic EDR Tone-Mapping & Highlight Roll-off)

### 1. 提案背景与物理根因
- **场景痛点**:
  - 当前 `kernel.metal` 中的 HDR10（`f2`）与杜比视界（`f0`）片元着色器在完成逆 PQ 变换后，直接通过 `*(10000.0 / 203.0)` 线性无损缩放为 EDR 亮度；
  - 片源中超过屏幕物理头顶高度（`edrHeadroom`）的高光像素未经过任何肩部平滑过渡，遭遇 macOS 显示合成器硬截断（Hard-clipping）；
  - 在大光比场景下（例如户外蓝天白云、直射阳光照耀、高光反光面），漫反射的蓝天（约 300~500 nits）尚在屏幕硬件线性显示舒适区，但白云向阳面（1,500~4,000+ nits）超出显示器硬件极限，导致白云内部棉絮阴影与卷积纹理全部糊成大面积死白，轮廓局部过曝。
- **目标定位**:
  - **纳入 1.6.0 核心排期**；
  - 建立“中低光 1:1 绝对保真 + 高光区自适应软滚降”的动态 EDR 色调映射管线。

### 2. 架构设计与技术路径
#### 2.1 动态物理 Headroom 注入
- `SilkMetalRenderView.swift` 在渲染编码前，将已有的 `cachedEDRHeadroom` 打包为 Uniform 结构体，通过 `setFragmentBytes` 注入 `f2`（HDR10）与 `f0`（杜比视界）着色器。

#### 2.2 软拐点肩部滚降算法 (Soft-Knee Shoulder Roll-off)
- **安全拐点（Knee Point）**:
  - 以 ITU-R BT.2408 漫反射白电平（203 nits，EDR = 1.0）为基准安全拐点；
  - $0 \le Y \le 1.0$ 的暗部、人物面部与中低光环境光 100% 直通，不作任何压缩，保持纯正对比度与黑位层次。
- **高光区间连续有理压缩 (Smooth Rational Compression)**:
  - 针对感知亮度 $Y > 1.0$ 的超高光像素，采用一阶导数连续的非线性平滑滚降曲线，将 $1.0 \sim 4,000+\text{ nits}$（EDR 1.0 ~ 19.7）平滑收拢至当前屏幕的物理极限 `headroom`：
    $$\text{excess} = Y - \text{knee}$$
    $$\text{max\_excess} = \max(\text{headroom} - \text{knee}, 0.1)$$
    $$\text{compressed\_excess} = \text{max\_excess} \cdot \left(\frac{\text{excess}}{\text{excess} + \text{max\_excess}}\right)$$
    $$Y_{\text{mapped}} = \text{knee} + \text{compressed\_excess}$$
- **色度等比缩放保真**:
  - 基于加权感知亮度 $Y$ 计算压缩系数 $\frac{Y_{\text{mapped}}}{Y}$，对 RGB 三通道等比缩放，杜绝单通道提前饱和造成的白云暖阳色相漂移。

### 3. 验收标准
1. 高动态范围蓝天白云片源中，白云轮廓层次丰富，向阳明暗过渡柔和自然，彻底消除高光死白；
2. 在 MacBook Pro XDR 屏与普通 SDR 屏幕（MacBook Air / iMac / 外接显示器）上自适应匹配，SDR 屏不发灰，XDR 屏不爆光；
3. Metal 片元着色器执行耗时增加少于 0.02ms，保障 120fps 满帧流畅度。

---

## 提案 014: 全场景大动态范围自适应画质重构与局部对比度增强 (SDR-to-EDR Dynamic Range Expansion & Local Contrast)

### 1. 提案背景与研究方向
- **场景痛点**:
  - 当前画质增强管线（`QualityEnhanceUniforms` / `f3` 着色器）主要聚焦于基于拉普拉斯算子的微观边缘与微纹理锐度增强，在人物面部特写、发丝纤维与服饰纹理上有显著提升；
  - 但对于大动态范围大场景（如广角风光、逆光黄昏、日光大对比度远景），现行算法仅对 $L > 0.68$ 的镜面高光做了简单的二次方权重点缀，对画面的宏观层次感、逆光通透度和空间纵深感提升较为有限。
- **目标定位**:
  - **纳入 1.5.0 核心排期**；
  - 推进“微观锐度 + 宏观大动态范围重构（SDR-to-EDR Remastering）”双重融合管线。

### 2. 技术探索与实现路径
#### 2.1 场景自适应逆色调映射 (Adaptive Inverse Tone Mapping, ITM)
- 结合运行时采集的平均画面亮度（APL）与场景动态区间，构建非线性 S 型亮度扩展曲线；
- 在不破坏中灰曝光的前提下，适度拉伸天空、阳光与灯火等高光区域的动态上限，使 SDR 内容在 XDR 屏幕上呈现更充沛的光感。

#### 2.2 频带分离与局部对比度增强 (Bilateral/Guided Local Contrast)
- 将视频画面分解为包含几何轮廓的照明基底（Base Illumination Layer）与包含高频细节的微纹理层（Detail Layer）；
- 在照明层执行大尺度的局部对比度适度拉伸，强化远景山川层次、阴云褶皱与逆光人物立体感，重构大动态范围场景下的通透度。

#### 2.3 高光色相与饱和度保护 (Gamut & Saturation Defense)
- 在 BT.709 向 Display P3 色域扩展与 EDR 提亮过程中，引入动态饱和度补偿，防止高光在大动态拉伸后颜色泛白或夕阳红通道溢出产生塑料感。

### 3. 验收标准
1. 在大光比风光、逆光街景等片源中开启画质增强，画面明暗反差、空间纵深感与通透度有肉眼可见的质感提升；
2. 不破坏原生黑电平（不泛灰白雾），不产生边缘光晕（Haloing）伪影；
3. GPU 额外算力开销控制在 0.5ms 以内，满足 4K 60fps 实时流畅运行。

---

## ~~提案 015: 播控栏交互式音量微调与起播防爆音安全锁 (Interactive Volume Popover & Pre-play Audio Safety Lock)~~（已实施销项）

### 1. 提案背景与痛点复盘
- **场景痛点**:
  - 当前音量调节仅依赖画面右侧滚动滚轮或触控板双指滑动触发的瞬态垂直音量条（`SilkVerticalVolumeBarView`）；
  - 媒体未起播、暂停态或静止空置时，界面缺乏任何常态可视化元素（Missing Pre-play Affordance），用户完全无法感知当前播放器音量是 0%、50% 还是 150%；
  - 在外放扬声器环境下打开私密敏感视频或大动态高电平片源时，由于无法在起播前确认或预调音量，极易因突发响度引发严重的尴尬与设备爆音风险；
  - 拒绝在主进度条（`PlayerProgressSection`）旁强行焊接常驻横向滑轨，避免挤占毫秒级精密时间轴视口与破坏极简美学。
- **目标定位**:
  - **纳入 1.5.0 核心排期**；
  - 建立“极简常态 24pt 图标 + 起播前一键静音安全锁 + 悬停展开微型滑块”的 Apple 原生交互闭环。

### 2. 交互与功能架构
#### 2.1 极简常态指示 (Collapsed State)
- 收拢在播控栏右翼工具区（`rightWingControls`，位于音轨与字幕图标旁），常态仅占据 24pt 标准图标位；
- 采用动态扬声器 SF Symbols 图标：
  - 静音态：`speaker.slash.fill`（醒目红色）；
  - 低电平（< 40%）：`speaker.wave.1.fill`；
  - 正常电平（40% ~ 100%）：`speaker.wave.2.fill`；
  - 超载增强（> 100%）：橙色高亮标记。

#### 2.2 起播前一键静音保险锁 (One-Click Mute Safety)
- 视频加载前、暂停态或播放中，单击喇叭图标即可瞬间切换静音与解除静音（映射快捷键 `M`）；
- 用户在载入敏感文件前，扫一眼图标即可掌握外放状态，单键锁死音频输出，保证零声音泄露。

#### 2.3 悬停平滑展开微型滑块 (Hover-to-Expand)
- 鼠标指针悬停于喇叭区域时，平滑展开长度约 72pt 的紧凑微型滑块（复用现有 `HUDVolumeSlider.swift`）；
- 支持直接拖拽滑块与滚轮微调，移开光标后平滑收拢回 24pt 图标态；
- 绝不侵占主进度条拖拽空间，在各窗口尺寸等级（`HUDLayoutTier`）下自适应收放。

#### 2.4 手势双轨保留
- 画面右侧区域的鼠标滚轮与触控板连续手势 100% 保留，与新图标滑块形成“宏观大范围手势 + 微观精准点按预设”的双轨互补。

### 3. 技术实现路径
- 复用与调优 [`HUDVolumeSlider.swift`](file:///Volumes/2T/Projects/SilkPlayer/SilkPlayer/Sources/SilkPlayer/HUD/HUDVolumeSlider.swift)；
- 在 [`PlayerHUDView.swift`](file:///Volumes/2T/Projects/SilkPlayer/SilkPlayer/Sources/SilkPlayer/PlayerHUDView.swift) 的 `rightWingControls` 与紧凑模式菜单中按需分发挂载；
- 联动 `PlayerCore.volume`、`isMuted` 与 `AppSettings.shared.maxVolumeLimit`，确保多处状态完全同步。

### 4. 验收标准
1. 媒体未播放、暂停及播放各状态下，播控栏右侧均清晰呈现当前音量与静音状态；
2. 视频未载入或暂停时，支持单键提前置为静音，起播时保证零声音泄露；
3. 悬停展开与收拢过渡平滑自然，不挤占 `PlayerScrubberView` 进度条有效交互宽度；
4. 画面右侧滚轮与新滑条双向联动，数据与 OSD 状态 100% 保持原子一致。

---

## ~~提案 016: 多文件夹与批量剧集导入全局智能自然排序 (Multi-Folder & Batch Episode Intelligent Natural Sorting)~~（已实施销项）

### 1. 提案背景与实机数据排查
- **实机运行与数据复现**:
  - 用户从外置盘 `/Volumes/HDD2T/影音娱乐/电视剧/` 批量拖拽导入《璀璨之城》4 个分段文件夹至播放列表：
    - 文件夹列表：`璀璨之城04-05`、`璀璨之城01-03`、`璀璨之城06-10`、`璀璨之城11-15`；
  - 检查播放器持久化偏好数据（`com.silkplayer.playlist.items`），实际排布呈现显著倒挂错乱：
    - 索引 `[0-1]`: 04集、05集（来自 `璀璨之城04-05`）
    - 索引 `[2-4]`: 01集、02集、03集（来自 `璀璨之城01-03`）
    - 索引 `[5-9]`: 06集 ~ 10集（来自 `璀璨之城06-10`）
    - 索引 `[10-14]`: 11集 ~ 15集（来自 `璀璨之城11-15`）
  - 导致第 04、05 集直接插队排在第 01 集前面，破坏剧集正常收看体验。
- **物理根因定位**:
  - 核心入口定位：[`PlayerWindowManager.swift`](file:///Volumes/2T/Projects/SilkPlayer/SilkPlayer/Sources/SilkPlayer/App/PlayerWindowManager.swift#L491-L504) 之 `expandFilesAndDirectories(_ paths: [String])`；
  - macOS 访达（Finder）在多选拖拽或多选打开时，`NSPasteboard` 传递的文件夹路径数组并未强制按名称排序，而是依赖系统内部遍历或鼠标选区次序；
  - 底层 `MediaFileClassifier.findVideos(in:)` 仅在**单个文件夹作用域内**做了局部自然排序（`localizedStandardCompare`）；外层 `expandFilesAndDirectories` 则通过 `for path in paths { results.append(...) }` 简单顺序拼接；
  - 展开后的整批路径数组在注入 `PlaylistManager.appendItems` 之前，**缺失批次全局自然语义排序（Global Batch Natural Sort）**。
- **目标定位**:
  - **纳入 1.5.0 核心排期**；
  - 建立“多文件夹层级扁平化 + 批次全量自然语言对比 + 剧集编号语义权重”的高健壮性导入排序管线。

### 2. 架构设计与技术路径
#### 2.1 全局批次自然排序统一入口 (Global Batch Natural Sort)
- 在 `PlayerWindowManager.expandFilesAndDirectories` 扁平化展开所有子目录媒体后，对最终产出的 `results` 执行全局自然排序：
  ```swift
  results.sort { path1, path2 in
      let file1 = URL(fileURLWithPath: path1).lastPathComponent
      let file2 = URL(fileURLWithPath: path2).lastPathComponent
      return file1.localizedStandardCompare(file2) == .orderedAscending
  }
  ```
- 统一收归所有入口（拖拽导入 `handleDroppedURLs`、访达外部打开 `openExternalFiles`、侧边抽屉文件选择 `addMediaViaPicker`）。

#### 2.2 剧集语义编号智能增强排序 (Semantic Episode Priority)
- 针对分季分集视频（如 `01.mkv`, `EP02.mp4`, `S01E03.mkv`, `第04集.mp4`），结合现有的 [`MediaFilenameSanitizer.swift`](file:///Volumes/2T/Projects/SilkPlayer/SilkPlayer/Sources/SilkPlayer/Playlist/MediaFilenameSanitizer.swift)：
  1. 优先提取清洗后的剧集序号（`episodeBadge` / `episodeNumber`）；
  2. 若两文件均解析出同季剧集编号，优先按集数数值升序对齐；
  3. 若无显式剧集编号，平滑回退至 Apple 原生 `localizedStandardCompare`，完美规避字符编码与多位数错位。

### 3. 验收标准
1. 同时拖入多个分卷目录（如 `04-05`、`01-03`、`06-10`、`11-15`）时，播放列表中剧集严格按照 `01 -> 02 -> ... -> 15` 递增排列；
2. 即使单个目录下包含跨级子目录或多个散落剧集文件，导入后依然按剧集自然顺序排列；
3. 单批次导入上百集剧集时，排序计算耗时低于 5ms，主线程保持 120fps 丝滑响应。

---

## ~~提案 017: 全链路系统级资源占用优化与高频空转治理 (System-wide Performance & Resource Footprint Optimization)~~（已实施销项）

### 1. 提案背景与实机物理基准测试数据
- **排期规划**: **1.5.0 核心排期**；
- **评估原则**: 稳定优先、可执行性优先、优秀占用优先。坚决不设前提指标门槛，不追求极致压榨占用而牺牲鲁棒性，一切以实测物理数据为依据；
- **实测基线数据 (Apple Silicon M4 物理机实测)**:
  1. 空载待机（无媒体播放）：CPU 11.4% · 物理足迹（Footprint）36.5 MB · RSS 119.4 MB；
  2. 本地 1080p SDR 播放 (`ToS-4k-1920.mov`)：CPU 26.5% · 物理足迹 138.2 MB · 71 个 IOSurface；
  3. 本地 4K 10-bit HEVC 120Mbps (`jellyfish`)：CPU 29.2% · 物理足迹 782.5 MB · 71 个 IOSurface (1.5GB 虚拟)；
  4. 4K 60fps 杜比视界 Profile 5 (`Mystery Box`)：CPU 26.8% · 物理足迹 666.7 MB · 80 个 IOSurface；
  5. 局域网 SMB 4K 电影 (24GB `哪吒之魔童闹海.mkv`)：CPU 30.2% · 物理足迹 622.7 MB · 126 个 IOSurface；
  6. 纯音频无损播放 (`方大同 - 特别的人.wav`)：CPU 58.4% · 物理足迹 177.9 MB · RSS 276.3 MB。

### 2. 四大定点优化模块与技术路径

#### 2.1 模块 A：纯音频视图光晕预烘焙与渲染管线轻量化（治理 58.4% CPU 倒挂）
- **问题根因**: 
  [`AudioArtworkView.swift`](file:///Volumes/2T/Projects/SilkPlayer/SilkPlayer/Sources/SilkPlayer/Player/AudioArtworkView.swift) 中的 `FloatingVinylDiscView` 与 `AudioVisualizerHaloView` 由 30fps `TimelineView` 与 30Hz `audioRhythmTimer` 驱动，包含 5 层带有高额 `blur(radius: 32)` 与多重 `shadow` 的动态光环计算，导致主线程大量消耗在位图高斯模糊光栅化上；
- **实施路径**:
  1. 将光晕同心圆效果预烘焙为静态高质量位图资产，通过修改透明度与缩放响应音量能量，移除运行时的实时高斯模糊与多重动态阴影计算；
  2. 黑胶唱片旋转统一走 CoreAnimation 原生图层动画（`CABasicAnimation`），移除 30fps `TimelineView` 的主线程逐帧插值重算；
  3. 将音频律动采样频率从 30Hz 调整为 20Hz，并对微小波动设置死区过滤。

#### 2.2 模块 B：动态区分播放态与暂停态的帧缓冲策略（治理 4K 显存常态 782MB）
- **问题根因**: 
  [`SilkPlayerEngine.swift`](file:///Volumes/2T/Projects/SilkPlayer/SilkCoreKit/Sources/SilkCoreKit/Engine/SilkPlayerEngine.swift) 为支持逐帧倒退维护的 `recentFramesRing`（容量 30 帧）在正常连续播放时未区分状态，常态滞留了 30 帧未压缩 4K 10-bit `CVPixelBuffer`（每帧约 24.88MB），硬性锁定约 746MB 显存；
- **实施路径**:
  1. 引入双态缓冲机制：在正常连续播放中（`isPlaying == true`），环形缓冲区容量上限收拢为 3 帧（满足时钟微距校准所需）；
  2. 仅在用户主动暂停（`pause()`）或触发逐帧步进时，允许历史帧按需扩容至 10~15 帧；
  3. 恢复播放时立即将积压帧剪裁回 3 帧常态，释放显存并回收系统 IOSurface 句柄。

#### 2.3 模块 C：解复用条件变量与音画同步单次休眠（治理 300 次/秒微睡轮询）
- **问题根因**: 
  `SilkPlayerEngine` 的解复用背压使用 `usleep(6_000)`（166Hz 轮询加锁），视频时钟超前等待使用 8ms 切片循环，两线程每秒合计发生近 300 次上下文唤醒；
- **实施路径**:
  1. 解复用背压引入条件变量（`NSCondition`）：当队列达到 300 包且音频充裕时挂起，由渲染端消费降至 200 包以下时触发唤醒，废除 `usleep(6_000)` 忙轮询；
  2. 视频渲染时钟同步改为单次计算睡眠：对于超前时长一次性计算安全休眠时间，单次调用 `usleep`，废除 8ms 切片轮询。

#### 2.4 模块 D：空载 Logo 动效按需触发与播控栏时间订阅解耦（治理 11.4% 待机 CPU）
- **问题根因**: 
  [`SilkBrandLogoView.swift`](file:///Volumes/2T/Projects/SilkPlayer/SilkPlayer/Sources/SilkPlayer/Shared/SilkBrandLogoView.swift) 的 `.repeatForever(autoreverses: true)` 在空载时持续驱动 CoreAnimation；[`PlayerHUDView.swift`](file:///Volumes/2T/Projects/SilkPlayer/SilkPlayer/Sources/SilkPlayer/PlayerHUDView.swift) 在 body 中直接访问 `player.currentTime <= 3.0`，导致整个视图树被动以 15fps 高频重绘；
- **实施路径**:
  1. 品牌 Logo 外发光限制为鼠标悬停（`isHovered`）时按需触发，移除无限循环动画，空载时让图层彻底静止；
  2. 将 3 秒前置临界判定改为派生状态通知或下沉至按钮交互闭包内部，阻断 15fps 时间推进对整个播控栏视图树的被动重评。

### 3. 稳定性底线与不变量守护
1. **绝对不缩减前向防抖网络缓冲区**:
   - `maxVideoPackets = 300` 维持不变，确保外置机械硬盘、USB 硬盘盒与局域网 SMB 挂载 NAS 的抗抖动能力 100% 保持；
2. **绝对不削减 CoreAudio 音频队列容量**:
   - 维持现有的 64 个 AudioQueue Buffer（~2.7 秒音频安全时钟），确保外置磁盘寻道与音频主时钟稳定无爆音；
3. **保留硬件零拷贝渲染管线**:
   - 维持现有的 `IOSurface` $\to$ `MTLTexture` 直接映射与 Metal 渲染管线，不引入复杂的多级离屏渲染。

### 4. 验收标准
1. 纯音频播放无封面状态下，CPU 占用稳定回落至 10%~15% 区间，黑胶旋转与光晕律动流畅自然；
2. 连续播放 4K 10-bit 片源时，常驻物理足迹控制在 ~300 MB 水平，暂停后逐帧单步后退功能完全正常；
3. 播放器空载启动未载入文件时，持续 5 秒后 CPU 占用归零至 0.0%~0.5% 静止水准；
4. 局域网 SMB 挂载 4K 电影高频拖拽跳转与长时间连续播放均无卡顿、断音或音画失步；
5. 全量 59 项回归测试与 SwiftTestingSanityTests 100% 保持绿灯通过。

---

## 提案 018: 偏好设置模块 macOS HIG 规范化全量重构 (Native Settings HIG Architecture & Design Overhaul)

### 1. 提案背景与现存问题深度反思
- **排期规划**: **1.6.0 核心排期**；
- **核心问题诊断与设计纠偏**:
  1. **转嫁配置负担与冗余开关堆砌**: 现有设置项存在大量“理所应当默认开启”的功能被误做成用户开关（例如硬件加速解码本就应全局默认开启；起播防爆音淡入淡出本是播放管线基础工程；同名外挂字幕自动加载本是标准预期；音量持久化本应默认保持）。这些属于开发者的基础质量责任，绝不应做成开关转嫁给用户造成认知负担；
  2. **非行业标准造词与表达生硬**: 充斥着非标准的造词（如“音频起播防爆音安全平滑锁”、“Metal 零拷贝直显”、“双轨独立列表”等），脱离了 macOS 官方标准界面语义；
  3. **只读快捷键模块冗余**: 播控按钮悬停已具备快捷键 Tooltip，且已有全局 `⌘ /` 独立速查窗口，设置面板堆砌 20 行只读快捷键纯属功能重复；
  4. **视窗几何冲突与滚动条割裂**: 硬编码窗口尺寸限制导致每个页面均被生硬的系统滚动条切割，底部控件被视口腰斩；
  5. **关于页面的非标准与品牌失真**: 关于页面使用了与产品不相符的占位图形，缺乏官方 AppIcon 资产与 macOS 原生关于视窗的端庄克制。

### 2. 彻底重构准则与全新架构规范

#### 2.1 彻底收拢为 3 大标准标签页 (3-Tab Minimal Architecture)
- 彻底废除“音视频与字幕”选项卡（全部底层能力全局默认启用，不设繁琐开关）；
- 彻底废除只读“快捷键”选项卡（由鼠标悬停 Tooltip 及 `⌘ /` 浮动速查窗口承载）；
- 聚焦收拢为 3 个符合 macOS 标准规范的顶级图标选项卡：
  - `[gearshape]` 通用 (General)
  - `[play.circle]` 播放 (Playback)
  - `[info.circle]` 关于 (About)

#### 2.2 100% 行业标准术语规范 (Standard macOS Terminology)
- **通用 (General)**:
  - 外观模式：跟随系统 / 浅色 / 深色
  - 界面语言：简体中文 / English
  - 窗口模式：单窗口模式 (在单个窗口中播放视频)
  - 截屏配置：格式 (PNG / JPEG)；保存位置 (标准单行 Path Control: 文件夹图标 + 截断路径 + 选取按钮)
  - 播放历史：记住播放进度；清除播放历史…
- **播放 (Playback)**:
  - 自动播放：打开文件后自动播放
  - 连续播放：播放完成后自动播放下一个文件
  - 窗口适配：自动调整窗口大小以适应视频尺寸
  - 全屏显示：全屏时显示时钟
  - 双击操作：双击画面 (切换全屏 / 播放与暂停 / 无)
  - 步进时间：快进/快退间隔 (5 秒 / 10 秒 / 15 秒 / 30 秒)
- **关于 (About)**:
  - 官方真实 AppIcon 原生渲染 (Midnight Obsidian squircle + 流畅丝绸弧线与播放多边形)
  - 规范版本标识：SilkPlayer 1.6.0 (Build 2026.11) · Universal Binary
  - 平实标准操作：检查更新 / 项目主页 / 开源许可 (LGPL-3.0)
  - 版权信息：Copyright © 2026 meowvia. All rights reserved.
  - **文案与策略表述清理红线**: 全面移除旧版中“完全单机离线运行”、“零联网”、“纯本地”、“无任何网络遥测”等绝对化断言，为后续版本静默在线更新检测与授权服务做好策略承接；统一调整为“原生轻量与极简设计，无内置广告与冗余后台常驻进程”。

#### 2.3 视窗黄金比例与零滚动条设计 (Zero-Scroll Form)
- 窗口尺寸定格为标准的 `520 × 400 pt`；
- 移除所有外层黑底卡片，转为标准系统 Inset Grouped / Two-Column Key-Value 表单；
- 所有选项卡内容精准自适应视窗高度，全 Tab 绝无任何纵向滚动条。

### 3. 验收标准
1. 设置窗口全量收拢为“通用、播放、关于”3 个核心标签页；
2. 界面所有文字 100% 采用 Apple macOS 官方行业标准规范术语，杜绝任何非标准用语；
3. 关于页面准确呈现 SilkPlayer 官方真实 AppIcon 资产；
4. 窗口在 520 × 400 pt 尺寸下无任何内容截断与内部滚动条；
5. 所有底层基础功能（硬解、防爆音渐入、字幕同名自动载入）默认静默运行良好。

---

## 提案 019: 播放列表侧边拉手边框贴合与极简透明线框重构 (Playlist Drawer Handle Border-Flush & Transparent Stroke Redesign)

### 1. 提案背景与现存问题
- **排期规划**: **1.6.0 核心排期**（直接定点修改，无需额外渲染验证）；
- **核心痛点与用户诉求**:
  1. **独立悬浮与色块割裂 (像创口贴)**: 原版 `PlaylistDrawerHandleTab` 采用 19pt 宽度的深色实心圆角矩形，在窗口模式下有 8pt 外边距 (`padding(.trailing, 8)`)，独立悬浮在画面边缘，犹如贴在影片画面上的“创口贴”，严重破坏观影沉浸感；
  2. **正三角形态笨重粗糙**: 原版使用标准等边三角形，横向进深大、视觉侵占感强；
  3. **过度视觉遮挡**: 原版深色毛玻璃材质即便收窄，在暗色与亮色影片背景下依然形成局部遮挡。

### 2. 定稿设计规范与技术参数
- **全透明底色 (100% 镂空)**:
  - 彻底废除 `.ultraThinMaterial` 及任何深色背景填充，底色设为完全透明 (`Color.clear`)，画面内容 100% 穿透，彻底消除任何色块遮挡；
- **极简三边微轮廓线 (无右边线)**:
  - 仅保留顶边、底边与左侧微圆角线（单像素 1.0pt 细线，不加粗，`Color.white.opacity(0.75)`）；
  - **严禁白色发光/粗阴影**: 仅在必要时保留极微弱、浅淡的底层轻微阴影（如 `Color.black.opacity(0.25), radius: 0.5`）以防纯白画面下辨识困难，严禁添加任何白色光晕或厚重投影；
  - 右侧边缘与窗口边框平齐闭合（`rect.maxX` 0 半径无缝衔接，无右侧线条）；
- **扁平微型指示三角**:
  - 三角高度严格固定为 **9.5 pt**；
  - 横向进深压扁至 **2.0 pt**（扁平修长箭头，指向左侧 `◀`，明确表达展开意图且极度克制）；
- **尺寸与贴边状态**:
  - 侵入画面进深仅 **5.0 pt**；
  - 垂直高度翻倍至 **112 pt**（兼顾视觉修长感与盲操定位）；
  - 移除 `PlayerContainerView` 中的 `.padding(.trailing, player.isFullscreen ? 0 : 8)`，使拉手在窗口模式与全屏模式下均 100% 紧贴窗口右侧边框；
  - 交互热区保持 20pt 宽度（通过透明 `.frame(width: 20, height: 112, alignment: .trailing).contentShape(Rectangle())` 承载），操作便捷顺畅。

### 3. 验收标准
1. 播放列表拉手在窗口与全屏模式下均 100% 贴附右侧边框，无任何脱离悬浮感；
2. 胶囊底色 100% 透明穿透，仅见纤细三边轮廓线条与 9.5pt 微三角；
3. 线条不加粗、无白色阴影、仅浅淡微阴影；
4. 交互热区触碰灵敏，点击可正常展开播放列表，自动化测试 100% 绿灯。

---

## 提案 020: 智能静默更新检测、周级克制频控与用户数据无损在位覆盖安装 (Smart Silent Update, Weekly Cadence & Lossless In-Place Overwrite Installer)

### 1. 提案背景与设计哲学
- **排期规划**: **1.6.0 核心排期**；
- **核心原则 (极简与克制)**:
  1. **零侵扰观影**: 播放器是沉浸式观影工具，绝不允许任何侵入式、频繁打扰的弹窗破坏用户体验；
  2. **绝对尊重用户决策**: 提示简洁直观，仅提供“是”与“否”，用户拒绝即刻进入长达 7 天的绝对静默期；
  3. **用户资产 100% 无损保证**: 覆盖安装仅替换应用程序包本体，严禁清空用户的播放历史、播放列表及偏好设置；
  4. **全链路端内闭环**: 用户同意更新后，端内直接完成校验与在位覆盖，无需跳转浏览器或外部网页。

### 2. 交互规范与提示流程

#### 2.1 主动提示层（冷启动，周级频控）
- **触发时机**: 播放器进程冷启动完成后，后台异步发起单次轻量检测；
- **提示文案与交互选项**:
  - **提示标题/正文**: `有新版本是否立即更新`
  - **交互按钮**: 仅提供两个标准选项——`是` 与 `否`（无额外诱导文案或第三方链接）；
- **用户选择“否” (拒绝/忽略)**:
  - 立即记录当前时间戳 `lastColdStartReminderDate = Date()`；
  - **启动 7 天防打扰倒计时**: 在接下来的 7 天（7 × 24 小时）内，无论播放器被冷启动多少次，绝对不再主动弹出任何更新提示；
  - 主动提示窗口即刻平滑关闭，不阻碍任何后续播放操作。

#### 2.2 被动常驻层（设置面板小红点，用户自决）
- **模块文案精简**: 设置面板中的 `关于 SilkPlayer` 在 1.6.0 版本精简为 `关于`；
- **微型小红点常驻**:
  - 只要远端存在更高版本且本地未完成升级，设置面板中的“关于”Tab 图标右上角常驻渲染 6.0pt 极简微型红点；
  - **不受“否”的影响**: 即使用户在冷启动提示中点击了“否”，设置面板内的小红点依然安静常驻；
  - 不弹窗、不闪烁，将更新节奏的主动权 100% 交由用户自行决定。

#### 2.3 用户选择“是” (在位覆盖安装与数据无损底线)
- **无须跳转**: 客户端直接在端内发起当前芯片架构对应安装包的后台下载，界面呈现原生进度指示；
- **环境与资产保护底线**:
  - **范围边界**: 覆盖安装必须严格限定在 `/Applications/SilkPlayer.app` 应用程序包物理路径的原子替换；
  - **数据无损**: 严禁触碰或清空任何用户应用支持目录与偏好配置（包括 `~/Library/Application Support/SilkPlayer/` 中的音视频双播放列表、`~/Library/Preferences/` 中的播放进度与断点记录、偏好设置项等）；
  - **大版本迁移前置预警**: 若未来涉及颠覆性架构变更（如 2.0.0）必须重置环境时，必须在更新前弹出显式迁移提示与确认，普通迭代绝对保证无损平滑覆盖；
- **平滑重启**:
  - 下载与 SHA-256 校验完毕后，唤起微型外部辅助脚本；
  - 播放器主进程平滑退出；
  - 脚本将新版本解包并原子移入 `/Applications/SilkPlayer.app`，随后执行 `open /Applications/SilkPlayer.app` 唤醒新版本，完成整个无缝升级闭环。

### 3. 数据状态持久化规范 (UserDefaults)
- `SilkPlayer.Update.LatestVersion`: 远端检测到的最新版本号字符串（如 `1.6.0`）；
- `SilkPlayer.Update.HasPendingUpdate`: 布尔值，用于驱动“关于”模块小红点的常驻显示；
- `SilkPlayer.Update.LastColdStartReminderDate`: 上次用户点击“否”或主动提示触发的时间戳，用于实施 7 天静默门禁判定。

### 4. 验收标准
1. 冷启动检测在后台异步执行，对播放器起播与主线程渲染性能损耗为 0；
2. 弹窗文案严格为“有新版本是否立即更新”，且仅有“是”与“否”两个选项；
3. 点击“否”后，连续 7 天内无论冷启动多少次，均无任何弹窗打扰；
4. 点击“否”后，打开设置面板，“关于”模块小红点依然正常安静常驻；
5. 点击“是”后，在端内直接完成覆盖升级与重启，所有历史播放列表、播放记录与用户偏好 100% 完整保留。

---

## 提案 021: 播控栏与进度条无底框全景纯悬浮化重构 (Cinema-Embedded Canvas HUD)

### 1. 提案背景与设计哲学
- **排期规划**: **1.7.0 核心排期**；
- **核心原则**:
  1. **彻底消除盒感边界**: 窗口模式下彻底废除局部深色渐变底板修饰，消除因内边距（padding）产生的“长方形暗区框”，实现画面像素 100% 通透穿透；
  2. **元素级对比度自适应**: 进度条、时间数值与播控按钮改为原生嵌入视频画面，通过微观元素细投影确保在极端亮色片源（如雪景、强日光）下的清晰辨识；
  3. **视觉层次协调**: 确保纯悬浮化的进度条与底部字幕渲染层保持优雅的垂直间距，杜绝视觉元素打架。

### 2. 核心重构技术方案
- **剥离局部底板渐变**:
  - 移除 `bottomControls` 上的 `LinearGradient(colors: [Color.clear, Color.black.opacity(0.10), Color.black.opacity(0.40)], ...)`；
  - 容器背景设为完全透明（`Color.clear`），消除窗口模式下 8pt 外边距形成的截断式矩形暗区；
- **微观元素级对比度防护 (Element-Level Drop Shadow)**:
  - 时间文字与播控图标：统一配置抗高光阴影 `.shadow(color: .black.opacity(0.60), radius: 2.0, x: 0, y: 1.0)`；
  - 进度条轨道：采用双层对比度设计，底层采用微深色细轨（`Color.black.opacity(0.35)`），已播进度与缓冲条辅以极细轮廓描边或细微投影，确保在纯黑与纯白极端场景下均具备高辨识度；
- **垂直布局间距与字幕避让**:
  - 协调字幕层与底部悬浮进度条的垂直对齐间距，避免进度条纯悬浮后直接与双行字幕发生干涉。

### 3. 验收标准
1. 窗口模式下播放高亮度浅色片源时，底部不再呈现任何矩形长条色块或暗区边缘；
2. 进度条轨道、当前/剩余时间与所有播控图标 100% 纯净悬浮在视频内容上；
3. 在纯白或强光高亮背景下，进度条与文字依然清晰可读；
4. 字幕显示位置与底部悬浮控制栏层级分明，互不干扰；
5. 自动化测试用例全量通过。







