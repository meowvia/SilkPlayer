# SilkPlayer 1.7.0 交付成果与技术归档 (Delivery Archive)

本文档归档 SilkPlayer 1.7.0 版本全量开发成果、技术实现路径、测试验证数据及版本交付资产。

---

## 1. 核心待办实施成果归档

### 1.1 待办 1: 播放列表 ⌘F 即时搜索与拼音首字母过滤 (提案 022)
- **目标与根因**:
  - 当播放列表容纳大量曲目或剧集时，缺乏快速查找定位机制，用户只能依赖鼠标滚轮翻找。
- **技术实现路径**:
  - 在 `SilkUnifiedDrawerView.swift` 中引入响应式快捷搜索面板，支持快捷键 `⌘F` 打开与 `Esc` 退出；
  - 集成中文全拼、拼音首字母简拼算法（例如输入 `zwy` 精准匹配《谢安琪 - 钟无艳》）与不区分大小写的英文字符匹配；
  - 过滤结果支持键盘上下键选曲播放、列表即时高亮与单曲移除，退出搜索时无损恢复完整队列。
- **交付资产**:
  - Commit: `0d9baa8` (`feat(playlist): add multimodal ⌘F instant search and pinyin matching (PROPOSAL-022)`)。

---

### 1.2 待办 2: 外挂字幕多级目录递归检索挂载 (提案 008)
- **目标与根因**:
  - 传统媒体外挂字幕往往集中放置于媒体同级的 `Subs/`、`subtitles/` 或 `Sub/` 等专门子文件夹下，原解析器仅搜索同级目录导致字幕无法自动挂载。
- **技术实现路径**:
  - 在 `PlayerModels.swift:findCompanionSubtitles` 中扩展搜索路径，自动检索同级及潜在子文件夹；
  - 递归索引并绑定常见的 `ASS`、`SSA`、`SRT`、`VTT`、`SUB` 等格式外挂字幕，通过文件名相似度算法完成自动挂载。
- **交付资产**:
  - Commit: `5378cca` (`feat(subtitle): recursive Subs directory search in companion subtitle locator (PROPOSAL-008)`)。

---

### 1.3 待办 3: 影院级纯透明悬浮播控栏与防误触清空保护 (提案 021)
- **目标与根因**:
  - 原播控栏下方包含一条深灰半透明渐变色块（`LinearGradient`），视觉上形成沉重的深色横条边框，阻碍观影与毛玻璃通透感；播放列表底部清空按钮缺少二次确认易误触。
- **技术实现路径**:
  - 在 `PlayerHUDView.swift` 将 `bottomControls` 外层背景由渐变深灰框彻底替换为 `.background(Color.clear)`，控件追加 `shadow(0.60)` 原生投影，实现 100% 悬浮观感；
  - 增强 `PlayerScrubberView.swift` 时间文字与底轨的黑色投影对比度，浅色或透明背景下均锐利可见；
  - 在抽屉清空按钮引入 3 秒倒计时两步确认状态机，防止用户误清空播放队列。
- **交付资产**:
  - Commit: `2cac983` (`feat(playlist): add two-step confirmation with 3-second timeout for playlist clearing`)
  - Commit: `01be59f` (`feat(hud): eliminate clunky bottom box and enable cinema-embedded floating controls (PROPOSAL-021)`)。

---

### 1.4 待办 4: 全格式高清音频解复用与多声道防爆音软限幅
- **目标与根因**:
  - DTS-CD（DTS-ES 6.1 等）由于 FFmpeg 编解码器缺口容易被系统当成标准 PCM 直推声卡产生啸叫；在立体声物理设备上下混时，声道能量累加易导致 DAC 发生方波削顶（Clipping）爆音；而音频管线中粗暴的 2 字节嗅探容易对标准 PCM 产生假阳性误判重置解码器（导致《钟无艳》49 秒杂音）。
- **技术实现路径**:
  - 编入包含 `dts`、`dtshd`、`truehd`、`mlp` 解复用器与对应解码器的 Universal FFmpeg 依赖库；
  - 在 `SilkDemuxer.swift` 前置配置 `10_000_000`（10MB）探测缓冲区与 `2_000_000` 微秒分析时长，流类型识别 100% 收拢于打开阶段；
  - 在 `SilkAudioEngine.swift` 中彻底剔除 2 字节单包探测逻辑，保护 PCM 纯净直通；
  - 在 `SilkAudioEngine.swift` 实现 `applySoftLimiter` 软限幅算法，将浮点电平平滑收敛在 0 dBFS 以内，消除削顶爆鸣。
- **交付资产**:
  - `SilkCoreKit` Commit: `bac0577`
  - `SilkPlayer` Commit: `0a30fe7`。

---

### 1.5 待办 5: 社区 Issue 与视窗交互硬化 (ISSUE-017, ISSUE-018, ISSUE-021, ISSUE-022)
- **目标与根因**:
  - 多屏扩展下副屏鼠标移动误唤醒主屏全屏播控（GitHub Issue #7 / ISSUE-021）；
  - 播放竖屏视频退出后，空状态视窗残留在手机比例（GitHub Issue #9 / ISSUE-022）；
  - 快速拖动窗口时起手存在轻微粘滞感（ISSUE-017）；
  - macOS 系统平铺记忆导致冷启动可能异常铺满屏（ISSUE-018）。
- **技术实现路径**:
  - `PlayerHUDView.swift:setupMouseMonitor` 增加物理屏幕绝对坐标矩形命中检测，屏蔽副屏鼠标移动；
  - `AppShellView.swift:onChange(of: isPlaying)` 增加纵横比保护门控，退出播放时将竖屏残余尺寸平滑复位为标准 16:9 桌面尺寸（`960 × 540`）；
  - `VideoView.swift` 将窗口拖拽启动阈值调整为 4.0pt 并向系统传递原始事件；
  - `SilkPlayerApp.swift` 在冷启动时主动清除持久化的窗口平铺属性。
- **交付资产**:
  - Commit: `423dec7` (`perf(drag): optimize window drag initiation threshold for responsive cursor tracking (ISSUE-017)`)
  - Commit: `16d8100` (`fix(hud): ignore cursor motion outside player window on secondary displays (ISSUE-021)`)
  - Commit: `4d5e192` (`feat: align version to 1.7.0, add vertical reset and startup window isolation`)。

---

## 2. 自动化测试与工程验证结果

- **单元测试执行情况**:
  - 测试命令: `swift test`
  - 结果: 8 个测试套件，共 63 项测试用例全部通过（`0 unexpected failures`），用时 0.59 秒；
- **动态库依赖审计 (`@rpath`)**:
  - 针对通用镜像包内所有动态库严格执行 `@rpath` 检查，无任何开发宿主机绝对路径泄漏；
- **代码签名与 Gatekeeper 兼容性**:
  - 深度代码签名校验通过（`valid on disk`，`satisfies its Designated Requirement`）；
- **本地应用替换验证**:
  - `/Applications/SilkPlayer.app` 替换安装成功，LaunchServices 缓存刷新成功，实机启动进程正常。

---

## 3. 最终发布镜像交付资产

- **目标版本**: `1.7.0` (Build `2026.11`)
- **芯片架构**: Universal Binary (`arm64` + `x86_64`)
- **发布安装镜像**:
  - 物理路径: `/Volumes/2T/Projects/SilkPlayer/SilkPlayer/build/SilkPlayer-1.7.0-universal.dmg`
  - 镜像大小: 约 80 MB
  - **SHA-256 校验和**: `dfc17814966067194da72a14be3406787baff12b747252d01a9a69bd2e009e60`
