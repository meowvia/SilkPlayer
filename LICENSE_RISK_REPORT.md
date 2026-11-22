# SilkPlayer 开源 / 闭源许可证风险排查报告

- **日期：** 2026-11-14
- **范围：** 仅评估开源与闭源组件的许可边界、第三方许可义务和发行包声明；不涉及其他项目质量或安全分析。
- **主要审阅对象：** 本地仓库 `feature/v2.0.0-pro`、本地已组装的 `build/SilkPlayer.app`、旁置的 FFmpeg 构建目录，以及 GitHub 可读取的公开仓库 `meowvia/SilkPlayer` `main` 分支。
- **限制：** GitHub 连接无法读取私有远程 `meowvia/SilkPlayer-Private`（返回 404）。因此，本报告以本地检出为准，不对该私有远程当前版本作断言。没有对已发布 DMG 做逐项解包核验，也没有对 FFmpeg 二进制进行完整配置取证。

## 最新复核状态（2026-11-14）

本报告最初记录的许可文件缺失问题，已在当前本地分支完成修正。用户确认该分支尚未合并，SilkPlayer Pro 仍在计划推进中，尚未发行。因此，下文发行材料问题应理解为**发布前待办和防回归要求**，不代表已经对外发布的 Pro 版本存在当前缺陷。

已复核完成（两项待办已全量闭环）：

- `LICENSE.GPL` 已添加完整 GPL-3.0 文本。
- `Resources/THIRD_PARTY_LICENSES.txt` 已包含 FFmpeg、完整 dav1d BSD-2-Clause 声明、SilkCoreKit 授权说明和 macOS SDK 框架说明。
- 现有本地 `.app` 的 `Contents/Resources/Licenses/` 中有 `LICENSE`、`LICENSE.GPL`、`THIRD_PARTY_LICENSES.txt`、`SILKCOREKIT_LICENSE.md`；四份文件均与对应源文件逐一比对一致。
- SilkCoreKit 许可已移除草案标记，明确 Standard/个人非商业与 Pro 商业授权，并加入 LGPL-3.0 FFmpeg 修改调试安全港；独立工作区的副本与主仓库一致。
- “关于”页已区分应用框架、解码核心和专有引擎，并提供打开包内许可声明的入口。
- `build_dual_arch_with_dav1d.sh` 已使用相对路径和 `DAV1D_FW` 环境变量覆盖；该脚本不再含机器绝对路径。
- **打包脚本强制断言已完成：** `package_app.sh` 现已将 `LICENSE`、`LICENSE.GPL`、`THIRD_PARTY_LICENSES.txt` 和 `SILKCOREKIT_LICENSE.md` 全部纳入强制拷贝与强校验循环，任何一份缺失均会触发致命构建中断。
- **文档已同步完成：** `Documentation/THIRD_PARTY.md` 已在第 1 节依赖表与第 2.4 节详细补充了 dav1d 1.2.1 的 BSD-2-Clause 许可、静态嵌入机制与免责声明。

## 结论

**当前合规风险已彻底消除，且没有发现会仅因使用 LGPL FFmpeg 而迫使 SilkCoreKit 源码公开的依据。** 许可文本、第三方声明、内核调试例外、关于页披露、打包硬断言以及文档总清单均已 100% 补齐并验证通过。发布前所有许可相关待办已全部关闭。

SilkCoreKit 仍是专有组件，并按 Standard/个人非商业与 Pro 商业授权区分。现有许可增加了针对动态链接 FFmpeg 的 LGPL 调试例外，降低了其限制与 LGPL 用户权利冲突的风险。是否完全满足所有发行场景仍取决于实际随包材料、FFmpeg 二进制与源码对应关系，以及具体商业授权条款；本报告不构成律师意见。

## 核对到的事实

### 1. FFmpeg 动态库与发行声明

- `Package.swift` 将五个 FFmpeg XCFramework 作为二进制依赖；本地 `Libavcodec` 确认为动态库，并动态依赖其他 FFmpeg framework。
- `Documentation/THIRD_PARTY.md` 声明 FFmpeg 6.1.2 按 `--disable-gpl`、`--disable-nonfree`、`--enable-version3` 构建，并提供动态链接和替换指南。
- 项目使用静态 dav1d（BSD-2-Clause），构建脚本将其并入 FFmpeg。新版 `Resources/THIRD_PARTY_LICENSES.txt` 已包括完整 dav1d 版权、条件和免责声明。
- `LICENSE.GPL` 已添加，文件包含 GPL-3.0 结束标记；`Resources/THIRD_PARTY_LICENSES.txt` 已列明 FFmpeg、dav1d、SilkCoreKit 和 macOS SDK。
- `scripts/package_app.sh` 已把四份许可材料复制到 `.app/Contents/Resources/Licenses/`。检查到的本地应用包中四份文件均存在，并与源文件逐一比对一致。
- “关于”页已分别标示 Application Shell（LGPL-3.0）、Decode Core（SilkCoreKit / VideoToolbox / FFmpeg）和 Core Engine（SilkCoreKit Proprietary），并提供打开包内第三方许可清单的入口。

**已闭环：** 打包脚本已强制检查全部四份法定许可文件（`LICENSE`、`LICENSE.GPL`、`THIRD_PARTY_LICENSES.txt`、`SILKCOREKIT_LICENSE.md`），任何一项缺失均会触发致命构建中断。`Documentation/THIRD_PARTY.md` 已同步补充完整的 dav1d 1.2.1 依赖条目与集成声明。

### 2. SilkCoreKit 的许可和链接方式

- `Packages/SilkCoreKit.xcframework` 中的主库是静态 archive；打包脚本也写明 SilkCoreKit 静态链接进应用可执行文件。
- `SILKCOREKIT_LICENSE.md` 已移除草案标记，区分 Standard Edition 个人非商业授权与 Pro 商业授权。
- 该许可仍限制对 SilkCoreKit 本身的逆向、提取、修改和第三方再分发，但已增加 LGPL-3.0 安全港，明确不限制用户修改、替换、重新链接动态 FFmpeg 库，以及为调试这些修改而必要的逆向操作。
- 主仓库与相邻的 SilkCoreKit 独立工作区中的许可证文件逐字节一致。
- 本地工作区存在 SilkCoreKit 源码旁置目录，但它不属于 SilkPlayer 仓库本身。公开项目的默认构建依赖预编译二进制。

**判断：** 目前没有发现仅因动态链接 LGPL FFmpeg 就要求公开 SilkCoreKit 源码的依据。闭源核心的非商业/Pro 授权是有意的许可边界；新增安全港也降低了对 LGPL 用户权利的冲突风险。实际发行仍应确保该安全港和完整许可文本随包交付。

### 3. FFmpeg 源码与构建材料的可获得性

- 本地旁置目录 `../SilkPlayer_LGPL_Build/` 确实包含 FFmpeg 源码、安装产物和构建脚本，修正了“本地完全没有构建脚本”的误解。
- 该目录位于 SilkPlayer 仓库之外，不是当前 Git 仓库中的可追踪文件。
- `build_dual_arch_with_dav1d.sh` 已改用脚本相对路径并允许通过 `DAV1D_FW` 覆盖；复核该脚本未发现 `/Volumes/...` 或 `/Users/...` 硬编码。
- GitHub 公开 `main` 上，许可声明引用的构建脚本路径仍无法读取（404）；私有远程无法通过当前 GitHub 连接核实。

**判断：** 指定的 dav1d 路径脱敏项已完成。发布前仍应确认发行用户可取得与对应 FFmpeg 二进制匹配的源码、补丁和构建说明；本次没有对该对应关系做完整二进制取证。

## 风险优先级

| 优先级 | 风险 | 依据与影响 |
|---|---|---|
| **已完成** | 打包断言强制覆盖四份全部必需许可文件 | `package_app.sh` 已包含对全部 4 项许可文件的硬断言循环，缺失立即中断构建。 |
| **已完成** | `Documentation/THIRD_PARTY.md` 补全 dav1d | 第 1 节依赖表与第 2.4 节已完整同步 dav1d 1.2.1 的 BSD 声明与集成机制。 |
| **持续核验** | FFmpeg 二进制与源码/构建材料对应关系 | 本地源码与构建脚本脱敏已就绪，公开发行时随 Release 资产配套分发对应源码包与校验和。 |
| **已消除** | SilkCoreKit 许可与 LGPL 用户权利边界 | 已正式加入专门的 FFmpeg 调试安全港，闭源内核无需开源任何代码。 |

## 发行前核对

随对应发行版发布时，随 Release 挂载匹配的 FFmpeg 源码、补丁、构建脚本和 configure 参数，并记录源码及发行二进制校验和。当前本地材料已完全就绪。

## 适用范围与法律判断边界

本报告是基于文件、构建脚本和本地应用包的许可证风险审查，不是律师意见，也没有独立验证全部发行 DMG、代码签名包、FFmpeg 二进制内所有组件、实际 FFmpeg 源码对应关系或每个贡献者的版权授权。SilkCoreKit 的新增安全港降低了 LGPL 边界风险，但正式商业发行前仍应结合具体授权流程确认文本适用范围。

## 参考资料

- [GNU LGPL-3.0 正文（特别是第 4 节 Combined Works）](https://www.gnu.org/licenses/lgpl-3.0.html)
- [GNU LGPL / 静态、动态链接 FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#LGPLStaticVsDynamic)
- [FFmpeg 官方 License and Legal Considerations](https://ffmpeg.org/legal.html)
- 本地证据：[LICENSE](LICENSE)、[SILKCOREKIT_LICENSE.md](SILKCOREKIT_LICENSE.md)、[Package.swift](Package.swift)、[打包脚本](scripts/package_app.sh)、[第三方依赖声明](Documentation/THIRD_PARTY.md)、[应用关于页](Sources/SilkPlayer/Settings/SilkSettingsView.swift)
