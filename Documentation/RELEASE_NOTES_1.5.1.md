# SilkPlayer 1.5.1 版本更新说明 / Release Notes

## 简体中文

SilkPlayer 1.5.1 为维护性更新版本，解决了部分视频文件在播放时仅有声音、视窗无画面渲染的问题。

### 缺陷修复

- 修复 AV1 视频编码画面无法显示的问题：底层解码引擎集成 libdav1d 解码库并配置多线程切片软解，完整支持封装 AV1 视频轨的 MKV、MP4 及 WebM 文件正常解码与视频画面流畅渲染。

### 系统要求
- 操作系统：macOS 14.0 (Sonoma) 或更高版本
- 架构支持：Universal 通用（推荐）、Apple Silicon (M1-M4)、Intel 64 位
- 图形显示：支持 Metal 硬件加速与 HDR / EDR 显示

### 安装方式
1. 下载 DMG 镜像（推荐 Universal 通用版 SilkPlayer-1.5.1-universal.dmg）。
2. 打开 DMG，将 SilkPlayer.app 拖入 Applications（应用程序）文件夹即可完成安装。
