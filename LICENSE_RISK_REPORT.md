# SilkPlayer 开源 / 闭源许可证风险排查报告

- **日期：** 2026-11-14
- **范围：** 仅评估开源与闭源组件的许可边界、第三方许可义务和发行包声明；不涉及其他项目质量或安全分析。
- **主要审阅对象：** 本地仓库 `feature/v2.0.0-pro`、本地已组装的 `build/SilkPlayer.app`、旁置的 FFmpeg 构建目录，以及 GitHub 可读取的公开仓库 `meowvia/SilkPlayer` `main` 分支。
- **限制：** GitHub 连接无法读取私有远程 `meowvia/SilkPlayer-Private`（返回 404）。因此，本报告以本地检出为准，不对该私有远程当前版本作断言。没有对已发布 DMG 做逐项解包核验，也没有对 FFmpeg 二进制进行完整配置取证。

## 结论

**这不只是文案问题。** 本地证据显示，项目把 FFmpeg 作为 LGPL-3.0 动态库随应用分发，但当前打包脚本和本地 `.app` 产物没有附带 LGPL 文本或第三方许可声明；项目使用的 dav1d BSD 许可声明也未见于随包资源。这是当前最明确、应优先修正的发行合规风险。

SilkCoreKit 则是实际受限的专有组件：它以静态库方式链接进主程序，许可仅授予个人、非商业用途，并限制逆向、修改和再分发。这些限制本身可能是有意的商业策略，但与“应用显示 LGPL-3.0”和 LGPL 对 FFmpeg 修改、重新链接及调试的权利要求之间，存在需要通过许可文本明确解决的边界风险。**仅凭当前资料无法断言已经构成 LGPL 违规；但也不能把风险归结为措辞不够清楚。**

## 核对到的事实

### 1. FFmpeg 动态库与发行声明

- `Package.swift` 将五个 FFmpeg XCFramework 作为二进制依赖；本地 `Libavcodec` 确认为动态库，并动态依赖其他 FFmpeg framework。
- `Documentation/THIRD_PARTY.md` 声明 FFmpeg 6.1.2 按 `--disable-gpl`、`--disable-nonfree`、`--enable-version3` 构建，并提供动态链接和替换指南。
- 项目还使用静态 dav1d（BSD-2-Clause），构建脚本将其并入 FFmpeg。根据 BSD 条款，二进制分发应附上版权声明、条件和免责声明。
- 本地 `scripts/package_app.sh` 组装应用时复制图标、本地化资源和素材，没有复制根目录 `LICENSE`、`Documentation/THIRD_PARTY.md` 或第三方许可清单。`Resources/THIRD_PARTY_LICENSES.txt` 不存在。
- 检查到的 `build/SilkPlayer.app/Contents/Resources` 只有图标、素材和本地化文件，没有许可证或第三方声明文件。
- 应用“关于”页只显示“GNU LGPL v3.0”，并链接到 GitHub 上的根 `LICENSE`；没有在应用内显示 FFmpeg/dav1d 许可声明或本地提供完整许可文本。

**判断：** 对当前已组装应用，这是高优先级、可直接复核的合规缺项。LGPL-3.0 第 4 节要求组合分发满足相应许可文本和用户权利条件；FFmpeg 官方清单也建议随应用提供与实际二进制匹配的源码、改动和构建说明。若 DMG 没有通过其他方式同时附带这些材料，应视为发行合规风险，而非单纯文案问题。

### 2. SilkCoreKit 的许可和链接方式

- `Packages/SilkCoreKit.xcframework` 中的主库是静态 archive；打包脚本也写明 SilkCoreKit 静态链接进应用可执行文件。
- `SILKCOREKIT_LICENSE.md` 标为草案，授予个人、非商业用途，并限制逆向、解密、提取、修改、独立再分发和在第三方应用中的嵌入。
- `README.md` 说明项目开源前端采用 LGPL-3.0，而 SilkCoreKit 另受专有许可约束；应用“关于”页却以单一“GNU LGPL v3.0”标示应用协议。
- 本地工作区存在 SilkCoreKit 源码旁置目录，但它不属于 SilkPlayer 仓库本身。公开项目的默认构建依赖预编译二进制。

**判断：** 非商业、禁止再分发等是实际许可限制，会影响默认构建应用及其 fork 的使用方式。LGPL-3.0 对与 LGPL 库组合分发提出条件：组合条款应保留对 LGPL 部分进行修改，以及为调试这些修改而逆向的权利；采用静态链接时还涉及重新链接机制。SilkCoreKit 的宽泛限制可能被理解为影响这些权利。建议明确加入 LGPL 权利保留条款，并清晰限定禁止逆向条款不适用于为调试、替换或重新链接 FFmpeg 而进行的必要操作。是否构成法律上的冲突，需由熟悉 LGPL 的律师结合实际发行条款确认。

### 3. FFmpeg 源码与构建材料的可获得性

- 本地旁置目录 `../SilkPlayer_LGPL_Build/` 确实包含 FFmpeg 源码、安装产物和构建脚本，修正了“本地完全没有构建脚本”的误解。
- 该目录位于 SilkPlayer 仓库之外，不是当前 Git 仓库中的可追踪文件；其双架构构建脚本还引用了机器专属的绝对路径。
- GitHub 公开 `main` 上，许可声明引用的 `SilkPlayer_LGPL_Build/build_dual_arch_with_dav1d.sh` 和 `package_xcframeworks.sh` 路径无法读取（404）。

**判断：** 本地维护者有构建材料，不等于发行用户能取得与已分发 FFmpeg 二进制对应的完整源码、补丁和构建说明。应把必要材料放进公开仓库或与每个发行包配套发布，并去除机器专属路径。需要进一步核实本地 `src` 是否未经修改，以及其版本、补丁和配置是否与当前 XCFramework 完全对应。

## 风险优先级

| 优先级 | 风险 | 依据与影响 |
|---|---|---|
| **P1** | 发行 `.app` 缺少 LGPL 和第三方许可材料 | 打包脚本未复制许可证；当前应用资源也未包含声明。分发者可能无法证明满足许可文本及归属声明义务。 |
| **P1** | SilkCoreKit 专有条款可能限制 LGPL 权利 | SilkCoreKit 静态链接，许可宽泛限制逆向/修改；可能影响调试和重新链接 FFmpeg 修改的权利。属实质条款风险，法律结论待确认。 |
| **P1** | FFmpeg 对应源码和构建配方未随公开仓库提供 | 本地 sidecar 目录不在仓库内，公开路径缺失；下游用户难以验证或重建已发行二进制。 |
| **P2** | 应用协议展示可能让用户误以为整个应用均为 LGPL | README 将 LGPL 限定于前端，而应用内只显示单一 LGPL 标识；容易混淆专有核心的授权限制。 |
| **P2** | SilkCoreKit 许可仍为 Draft 且授权范围不够明确 | “个人非商业”与“嵌入 SilkPlayer”并列，但未清楚说明官方发行、fork、开发、测试、企业内部使用及再分发的边界。 |

## 建议处理顺序

### 立即：修复发行包的许可材料

1. 在 `.app` 的 `Contents/Resources` 中随包放置完整 LGPL-3.0 文本、GNU GPL-3.0 文本、FFmpeg 和 dav1d 的版权/许可声明，以及 SilkCoreKit 的适用许可说明。
2. 更新 `scripts/package_app.sh`，让每次构建都复制同一份维护的第三方许可清单，并确保该文件纳入签名后的发行 `.app` 和 DMG。
3. 在应用“关于 / 许可”入口说明 FFmpeg 的 LGPL 身份、源码获取位置和 SilkCoreKit 的专有授权边界。不能只展示“GNU LGPL v3.0”而不解释该标识涵盖哪些部分。

### 高优先级：厘清开源与专有组件的权利边界

1. 将 SilkCoreKit 草案定稿，并在根许可证、README、第三方清单、二进制包和应用 UI 中统一许可范围：明确 LGPL 适用于哪些源文件；明确 SilkCoreKit、资源和发行包分别由何种许可覆盖。
2. 在 SilkCoreKit 许可中增加明确例外：其逆向、修改、签名和再分发限制不妨碍用户依据 LGPL 修改、替换、重新链接或为调试 FFmpeg 修改而进行必要操作。
3. 确认下游用户能否用修改后的 FFmpeg 运行组合应用。若现有静态 CoreKit 和限制条款使此操作不可行，应调整授权/链接架构或取得律师对具体方案的书面意见。
4. 诚实标示默认构建条件：若官方二进制只授权个人非商业使用，应明确说明商业 fork 或商业分发需要另行授权，不能让 LGPL 徽标造成“整包可自由商用”的印象。

### 高优先级：让源码义务可验证

1. 将 FFmpeg 6.1.2 的确切源码、所有本地补丁、dav1d 版本、configure 参数、构建脚本和 framework 打包脚本发布到可长期访问的位置，并与对应二进制版本绑定。
2. 记录并发布每次发行使用的源码 commit/校验和、`ffmpeg -buildconf` 或等价配置输出、源码补丁差异及二进制校验和。
3. 将脚本改成不依赖 `/Volumes/...` 等维护者本机绝对路径的可复现构建方式。

## 适用范围与法律判断边界

本报告是基于文件、构建脚本和本地应用包的许可证风险审查，不是律师意见，也没有独立验证全部发行 DMG、代码签名包、FFmpeg 二进制内所有组件或每个贡献者的版权授权。尤其是 SilkCoreKit 条款是否与 LGPL 第 4 节产生法律冲突，应结合实际分发许可、安装方式和用户重链接流程由律师确认。

## 参考资料

- [GNU LGPL-3.0 正文（特别是第 4 节 Combined Works）](https://www.gnu.org/licenses/lgpl-3.0.html)
- [GNU LGPL / 静态、动态链接 FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#LGPLStaticVsDynamic)
- [FFmpeg 官方 License and Legal Considerations](https://ffmpeg.org/legal.html)
- 本地证据：[LICENSE](LICENSE)、[SILKCOREKIT_LICENSE.md](SILKCOREKIT_LICENSE.md)、[Package.swift](Package.swift)、[打包脚本](scripts/package_app.sh)、[第三方依赖声明](Documentation/THIRD_PARTY.md)、[应用关于页](Sources/SilkPlayer/Settings/SilkSettingsView.swift)
