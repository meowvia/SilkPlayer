# SilkPlayer v2.0.0 系统性重构协同方案与执行备忘录 (Archived)

> 状态声明 (STATUS & BOUNDARY)：
> 1. **独立冻结归档**：本文档仅作为此前与第三方协同梳理的“v2.0.0 系统性全架构重构方案”的独立技术备忘，处于**完全挂起与冻结状态**。
> 2. **物理隔离防混淆**：本文档与当前稳定版本（v1.1.0）日常收集的用户报障、轻量微调及热修复**严格隔离**，严禁混杂执行，防止对现有稳定架构造成打散风险。
> 3. **执行门禁**：在用户没有明确下达启动重构指令前，任何会话与开发者均**不得擅自推进或执行本文档中的大规模改动**。未来若重启重构，必须新切独立分支（`feature/v2.0.0-release`）进行。

---

## 目录索引
1. 系统深度体检总表（6 大模块 · 22 项核验明细）
2. 五步闭环演进路线图（Master Roadmap Step 0 ~ Step 5）
3. Step 0 / Step 1 纯前端定点施工方案细则
4. Step 2 / Step 3 交互治理与生命周期修复细则
5. Step 4 / Step 5 内核杜比视界、防断音与抽帧优化细则

---

## 一、 系统深度体检总表（6 大模块 · 22 项核验明细）

经实机逐行代码核查，以下 22 项问题已 100% 确认存在于本地代码库中：

### 模块一：设置面板（Settings）与菜单栏（Commands）空壳审计
1. **多窗口模式开关形同虚设 (P0)**：
   - 定位：`PlayerWindowManager.swift` (L493~519)、`PlayerCommands.swift` (L33)；
   - 根因：管理器硬编码 `Strictly Single Window`，未读取 `AppSettings.shared.singleWindowMode`，菜单栏抹除了系统新建窗口项。
2. **记住音量设置开关完全为空壳 (P1)**：
   - 定位：`AppSettings.swift` (L234~241)、`PlayerCore.swift` (L91, L567~579)；
   - 根因：`PlayerCore.volume` 初始化硬编码 `100.0`，`setVolume` 未持久化保存。
3. **默认字幕字号冷启动不生效 (P1)**：
   - 定位：`AppSettings.swift` (L231)、`PlayerCore.swift` (L127)；
   - 根因：初始化硬编码 `subtitleScale = 1.0`，未读取 `AppSettings.shared.defaultSubtitleScale`。
4. **冷启动断点恢复播放状态倒挂 (P1)**：
   - 定位：`AppShellView.swift` (L500, L506)、`PlayerCore.swift` (L319, L1437)；
   - 根因：恢复播放时传入 `autoPlay: false`，但在 `.readyToPlay` 被 `autoPlayOnLoad` 覆盖设为 `isPlaying = true`。
5. **窗口置顶存在三套不同步状态源 (P1)**：
   - 定位：`PlayerHUDView.swift` (L123~128)、`PlayerCommands.swift` (L419~420)、`AppShellView.swift` (L166)；
   - 根因：HUD、菜单栏、视图层状态源割裂，窗口挂载缺少重放。
6. **偏好设置窗口语言切换自身不刷新 (P1)**：
   - 定位：`SilkSettingsView.swift` 根视图缺少 `.id(settings.appLanguage)`。
7. **6 个未接通底层的空壳功能 (P2)**：
   - 定位：`PlayerCore.swift` (L839, L848, L926~938, L948, L994)；
   - 涵盖：画面锐化/对比度/亮度、去色带 (Deband)、HDR 切换、音频延迟微调、夜间模式人声增强。

### 模块二：全局快捷键与鼠标交互系统审计
8. **`handleKeyDown` 缺乏修饰键过滤引发大面积吞键 (P0)**：
   - 定位：`PlayerCore.swift` (L1359~1410)；
   - 根因：按键 switch 未检查 `modifierFlags`，导致 `Cmd + 方向键`（切歌）被拦截为快进退，`Cmd + M`（最小化）被拦截为静音，`Cmd + Shift + R` 被拦截为顺时针旋转。
9. **速查表宣称的快捷键在按键分发中遗漏 (P1)**：
   - 定位：`PlayerCore.swift` (L1359~1410)；
   - 根因：缺少 `Z`、`X`、`H`、`[`、`]` 的键值分支。
10. **长按右方向键 2x 快进前先突兀跳跃 5 秒 (P1)**：
    - 定位：`PlayerWindowManager.swift` (L261~282)；
    - 根因：首击（`isARepeat == false`）穿透触发了普通快进 5 秒。
11. **鼠标指针隐藏 API 混用引发 AppKit 计数失衡 (P2)**：
    - 定位：`PlayerHUDView.swift` (L756, L762)；
    - 根因：混用 `setHiddenUntilMouseMoves(true)` 与 `unhide()`。

### 模块三：播放生命周期、播放列表与字幕系统审计
12. **视频自然播完连续触发两次回调引发连跳两集 (P0)**：
    - 定位：`PlayerCore.swift` (L1468, L1494)；
    - 根因：在 `.playedToTheEnd` 与 `player(layer:finish:)` 均无保护调用了 `onPlaybackEndedNaturally?()`。
13. **断点续播双重 Seek 引发瞬态画面闪烁 (P1)**：
    - 定位：`PlayerCore.swift` (L296~297, L1431~1435)。
14. **拖入已有文件重复追加与启动队列残留 (P1)**：
    - 定位：`AppShellView.swift` (L342)、`AppDelegate.swift` (L28, L34)。
15. **纯音频模式下右键与更多菜单出现视频选项穿帮 (P1)**：
    - 定位：`PlayerContainerView.swift` (L41~60)、`PlayerHUDView.swift` (L613~648)。
16. **字幕清洗无视格式误伤带逗号的普通台词 (P2)**：
    - 定位：`SilkSubtitleModel.swift` (L351~356)；
    - 根因：逗号数量 `>= 9` 即切除前 8 段，未校验 ASS 事件头。

### 模块四：窗口交互与自适应几何系统审计
17. **窗口几何与音频穿模 5 处代码缺陷定位 (P0)**：
    - 缺陷 A：`AppShellView.swift` 根视图 `.frame(minWidth: 640)` Auto Layout 强锁；
    - 缺陷 B：`PlayerCore.swift` (L291, L1529) `wasAudioMode` 短路导致音频尺寸自适应失效；
    - 缺陷 C：`PlayerWindowManager.swift` (L650) 视频分支硬编码 `minW = 640` 导致 9:16 竖屏最小高误算为 1138pt 拖拽跳变；
    - 缺陷 D：`AudioArtworkView.swift` 缺乏 HUD 108pt 安全区且盘片下限锁死 240pt 导致歌名穿模；
    - 缺陷 E：`PlayerCore+WindowGeometry.swift` (L121) 切回视频未解锁正方形 `maxSize`。

### 模块五：进度条悬停预览系统审计
18. **竖屏视频缩略图显示错误与“邮票化” (P0)**：
    - 定位：`PlayerScrubberView.swift` (L378~408)；
    - 根因：仅靠 `isPerpendicular` 无法识别原生竖屏，且 SwiftUI `.rotationEffect` 不变包围盒导致图层塌陷为 36×64 极小尺寸，占位符硬编码撑破卡片。
19. **抽帧引擎初次悬停双重 Seek 与长 GOP 预算不足 (P1)**：
    - 定位：`SilkThumbnailEngine.swift` (L320, L873, L882)、废弃未调用的 `ThumbnailLRUCache.swift`。

### 模块六：底层渲染与音视频引擎审计（SilkCoreKit）
20. **后台 100% 物理遮挡导致 Metal 阻塞与断音死锁 (P0 - ISSUE-005)**：
    - 定位：`SilkMetalRenderView.swift` (L198)、`SilkPlayerEngine.swift`；
    - 根因：`nextDrawable()` 挂起 1 秒塞满 24 个视频包反压停止解复用。
21. **杜比视界 P5 动态矩阵重复相乘与 MMR 色度归零坍塌 (P0)**：
    - 定位：`DolbyVisionReshape.swift` (L126)、`Shaders/kernel.metal` (L77~85)；
    - 根因：重复相乘 `dovi_lms2rgb` 导致偏色；MMR 模式（`mapping_idc == 1`）未处理导致色度通道全 0 变紫绿。
22. **首帧渲染宽高比反转与音频律动锁数据竞争 (P1)**：
    - 定位：`SilkPlayerEngine.swift` (L170~172)、`SilkAudioEngine.swift` (L563~618)。

---

## 二、 五步闭环演进路线图（Master Roadmap）

```
[v1.1.0 基准分支]
      │
      ▼
【Step 0】分支隔离：切出 feature/v2.0.0-release，锁定 52/52 绿灯基准
      │
      ▼
【Step 1】纯前端：窗口几何、音视频切换与音频 HUD 安全区重构 (5个文件定点修复)
      │
      ▼
【Step 2】纯前端：进度条悬停预览卡片修复与全局快捷键/鼠标事件治理
      │
      ▼
【Step 3】纯前端：播放生命周期（防连跳两集）、播放列表（ISSUE-002 Fisher-Yates 洗牌与历史栈）与设置面板状态同步
      │
      ▼
【Step 4】专有内核 SilkCoreKit：杜比视界 P5 色彩修正、窗口 100% 遮挡防断音 (ISSUE-005)、音频倍速支持 (ISSUE-001) 与网络流缓冲深度扩容 (ISSUE-006)，独立编译 .xcframework
      │
      ▼
【Step 5】专有内核 SilkCoreKit：抽帧引擎极速优化、字幕清洗保护、死代码清理与全量单元测试扩充，封版验收
```

---

## 三、 Step 0 / Step 1 施工细则备忘

### 1. Step 0 分支命令
```bash
git checkout -b feature/v2.0.0-release
```

### 2. Step 1 涉及的 5 个前端文件修改方案
1. **`AppShellView.swift`**：
   - 根视图新增计算属性 `rootMinWidth` / `rootMinHeight`（空闲 640/360，音频 380/380，视频 200/200）；
   - 替换 L136 的硬编码；
   - `handleWindowAcquired` (L430) 增加 `applyAudioWindowGeometry` 与 `applyAdaptiveWindowGeometry` 的挂载补偿。
2. **`PlayerCore.swift`**：
   - `detectMetadata(for:)` 移除 `if !wasAudioMode`，进入音频分支无条件执行 `applyAudioWindowGeometry(animated: false)`。
3. **`PlayerCore+WindowGeometry.swift`**：
   - `applyAdaptiveWindowGeometry` 将尺寸校验前置，在 `guard AppSettings.shared.autoResizeWindow` 之前先重置 `minSize` 与 `maxSize = screenFrame.size`。
4. **`PlayerWindowManager.swift`**：
   - `windowWillResize` 视频分支移除硬编码 `let minW = 640`，统一调用 `PlayerGeometry.minimumContentSize` 计算 `minW` 与 `minH`。
5. **`AudioArtworkView.swift`**：
   - 顶部定义 `topSafeInset = 58.0`、`bottomSafeInset = 108.0`；
   - 移除 240pt 硬编码下限，移除 `.offset(y: -8)`，应用 `.frame(width: availableW, height: safeH, alignment: .center)` 与内边距保护。

---

## 四、 极简回执协议与执行准则

当未来用户正式下达启动指令后，每个 Step 完成时必须严格遵循以下规则：
1. 严禁输出任何 Emoji 符号；
2. 严禁贴出长篇大论的代码或分析；
3. 必须在 15 行以内按标准模板汇报结果：
```
【Step X 执行回执】
1. 分支与 Commit: feature/v2.0.0-release @ <commit_hash>
2. 修改文件统计 (git diff --stat):
   - <文件路径>: +X / -Y lines (简要说明)
3. 本地编译与测试结果: ./scripts/run_tests.sh -> 52/52 Passed (耗时 Xs)，Swift 6 警告数: 0
4. 遗留异常或偏离说明: 无
```
