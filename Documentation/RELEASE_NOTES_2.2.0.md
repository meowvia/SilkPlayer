# SilkPlayer 2.2.0 更新说明 / Release Notes

## 版本概括 / Overview
SilkPlayer 2.2.0 重点围绕 Pro 媒体库实用范围扩展、高规格观影氛围增强与底层播放稳定性带来多项重要升级。本版本正式将 Pro「媒体库」从局域网打通至电脑本地文件夹与外置移动硬盘，新增 Pro 专属黑边环境光柔化开关与端内更新说明展示；同时优化回归全屏右侧悬停展开播放列表交互、媒体库详情页原生音视频规格探测及网络目录防呆引导，并修复 Pro 关闭媒体库后标准播放列表记忆异常及共享盘断流超时问题。

SilkPlayer 2.2.0 highlights major Pro Media Library expansions, theater ambience rendering, and playback resilience improvements. Pro Media Library now works across local folders and external drives in addition to NAS shares, alongside an optional Pro Ambient Letterbox Fill shader and in-app update highlights. This update also restores fullscreen right-edge hover expansion for the playlist drawer, switches detail views to direct FFmpeg stream probing, adds Finder network share safeguards, and fixes standard playlist persistence when Media Library is turned off as well as 8-second network disconnect timeouts.

---

## 更新 / What's New

### Pro 媒体库全面打通本地与外置存储 / Pro Media Library for Local & External Storage
- **中文**：打破此前“仅限局域网”的限制，「局域网」正式升级更名为「媒体库 / 媒体源」，Pro 用户现可直接导入电脑本地文件夹与外置移动硬盘生成海报墙，并支持一次性多选多个文件夹批量入库。
- **English**: Renamed "LAN" to "Library / Media Sources" to remove LAN-only restrictions—Pro users can now import local Mac folders and external drives into the Poster Wall with multi-folder batch selection.

### Pro 专属观影氛围扩展：黑边环境光柔化 / Pro Ambient Letterbox Fill
- **中文**：在「设置 → 播放」新增 Pro 专属可选项（默认关闭）。全屏或窗口观看宽银幕电影存在上下/左右留白黑边时，可按喜好开启柔和的画面延展微光，不影响主画面锐度与对比度。
- **English**: Added an optional Pro setting in Settings -> Playback (disabled by default). When widescreen films leave top/bottom or left/right black bars, projects a soft ambient glow into the margins without affecting main picture sharpness or contrast.

### 端内版本更新说明 / In-App Update Highlights
- **中文**：版本更新弹窗可直接显示新版重点内容，升级前即可直观了解主要改动。
- **English**: Update prompts now display key release highlights directly inside the dialog before installing.

---

## 优化 / Improvements

### Pro 媒体库多处核心体验打磨 / Pro Media Library Refinements
- **中文**：
  - **网络目录防呆引导**：在「添加本机目录」中误选访达临时挂载的网络共享目录时，主动提醒休眠或重启后可能断链失效的风险，并一键引导转入支持自动重连的「SMB / NFS」添加；
  - **影片格式真实识别与详情页精简**：详情页取消按文件名猜测，改为直接读取视频实际音视频参数（准确识别 4K/8K、杜比视界、HDR、杜比全景声 Atmos 等真实规格）；移除详情页冗余的「从头播放」按钮，保留卡片右键里的对应入口。
- **English**:
  - **Network Share Safeguard**: Selecting a Finder-mounted network folder in the local picker now warns about sleep/reboot disconnects and redirects to "SMB / NFS" for automatic reconnection;
  - **Accurate Media Specs & Cleaner Detail View**: Replaced filename-guessing with direct stream-header probing (4K/8K, Dolby Vision, HDR, Dolby Atmos, etc.) and removed the duplicate detail-view "Play from Beginning" button while keeping the context-menu action.

### 全屏右侧悬停展开播放列表回归 / Restored Fullscreen Hover Playlist Drawer
- **中文**：全屏看片时，鼠标移至右侧边沿拉手处稍作停留即可自动展开播放列表，移开自动收起（窗口模式仍保持手动点击或 `P` 键切换）。
- **English**: Restored automatic playlist drawer expansion when hovering over the right-edge handle in fullscreen (~100ms), collapsing cleanly after pointer exit (windowed mode remains manual click / `P`).

### 免费版启动页与设置引导理顺 / Cleaner Free-Tier Onboarding & Settings State
- **中文**：免费版启动页底部新增一次性轻引导条（未点过前微光提示且不可关闭，点击前往「设置 → 媒体库」查看过一次后才出现 `×` 可手动关掉）；未激活状态下设置页所有 Pro 开关清晰展示为关闭状态，并在「媒体库 [PRO]」后方直接提供跳转官网价格区的入口。
- **English**: Added a one-time bottom onboarding pill on the free-tier launch canvas (glowing gently until clicked to visit Settings -> Library, then dismissible via `x`). Unlicensed Pro toggles now render clearly as OFF, with a direct link to website pricing next to the Library [PRO] header.

---

## 修复 / Bug Fixes

### Pro 关闭媒体库后回归基础播放列表逻辑 / Standard Playlist Persistence When Media Library Is Off
- **中文**：已激活 Pro 但主动关闭「启用媒体库」时，在保留 Pro 启动页视觉的同时，启动页右侧播放列表抽屉与队列持久化记忆完整回归，关闭窗口或退出播放不再丢失队列记录。
- **English**: When "Enable Media Library" is turned off on an active Pro license, the Pro launch appearance stays intact while restoring the standard right-edge playlist drawer and persistent queue history across window and playback closes.

### 网络共享盘或流媒体断流超时保护 / Network Share & Stream Disconnect Watchdog
- **中文**：当 NAS 断连或网络地址无响应时，超过 8 秒自动安全超时中断，不再长时间卡死无反应。
- **English**: Enforces an 8-second I/O timeout watchdog when a NAS share disconnects or a remote stream stops responding, preventing indefinite hangs.

---

## 系统要求 / System Requirements
- **macOS**：macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- **架构 / Architecture**：Universal 通用二进制（原生支持 Apple Silicon M 系列与 Intel 64 位芯片） / Universal binary (Native support for Apple Silicon M-series and Intel 64-bit processors)
- **推荐硬件 / Recommended Hardware**：配备 Apple Silicon 芯片（M1 / M2 / M3 / M4 系列）的 Mac 设备以获得最佳硬件解码与 Metal 渲染效能 / Mac with Apple Silicon (M1/M2/M3/M4) for optimal hardware decoding and Metal rendering efficiency

---

## 安装方式与说明 / Installation

### 中文安装教程
1. 下载 `SilkPlayer-2.2.0-universal.dmg` 安装镜像（镜像内已附带双语 `安装指南_Installation_Guide.txt`）。
2. 双击打开 DMG 镜像，将左侧的 `SilkPlayer.app` 拖移至右侧 `Applications`（应用程序）文件夹即可完成安装；**请勿直接在 DMG 内双击运行**，否则偏好设置与文件关联无法保存。
3. **macOS Gatekeeper 安全提示处理**：首次打开如系统提示「无法打开，因为 Apple 无法检查其是否包含恶意软件」或「已损坏」，可通过以下任一方式信任放行：
   - **方法一（推荐）**：在「访达 → 应用程序」中按住键盘 `Control` 键并用鼠标点击 `SilkPlayer`，选择「打开」，在弹出确认框中再次点击「打开」。
   - **方法二**：打开「系统设置 → 隐私与安全性」，向下滚动至安全性区域，点击旁边的「仍要打开」。
   - **方法三（终端命令）**：在终端执行并输入 Mac 开机密码（盲输后按回车）：
     `sudo xattr -rd com.apple.quarantine /Applications/SilkPlayer.app`
4. **Pro 授权激活**：前往官网 `https://silkplayer.com/#pricing` 获取激活密钥后，在应用内打开「设置（`Cmd + ,`）→ 关于」，输入激活码点击「激活」即可解锁全部 Pro 功能。

### English Installation Guide
1. Download `SilkPlayer-2.2.0-universal.dmg` (the bilingual `安装指南_Installation_Guide.txt` is also included inside the disk image).
2. Open the DMG image and drag `SilkPlayer.app` into the `Applications` folder to complete installation. **Do not run directly inside the mounted DMG**, as settings persistence and file associations require installation in `/Applications`.
3. **macOS Gatekeeper Security Prompts**: If macOS displays a warning that the app "cannot be opened because Apple cannot check it for malicious software" or appears "damaged", approve it using any of the following methods:
   - **Method 1 (Recommended)**: Open `Applications` in Finder, hold `Control` while clicking `SilkPlayer`, select "Open", and click "Open" in the confirmation dialog.
   - **Method 2**: Open "System Settings -> Privacy & Security", scroll down to Security, and click "Open Anyway".
   - **Method 3 (Terminal)**: Run the following command and enter your login password:
     `sudo xattr -rd com.apple.quarantine /Applications/SilkPlayer.app`
4. **Pro Activation**: Obtain a license key at `https://silkplayer.com/#pricing`, then open "Settings (`Cmd + ,`) -> About" inside SilkPlayer, enter the key, and click "Activate".

### 校验和 / Checksum
- **SHA-256**: `9282cfac7493d7ce191577566f28e158a1b2423b6a8dce9fd8e0195a83b4e570`
