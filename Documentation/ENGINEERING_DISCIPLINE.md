# SilkPlayer 工程纪律与协作规范 (Engineering Discipline & Handoff Standard)

本文档是 SilkPlayer 项目全生命周期工程开发、跨会话协作与质量保证的唯一常态基准。所有参与本项目开发、调试、发版或排查的 Agent，在进入新会话承接任何任务前，**必须无条件首先全文阅读本文档**；在执行任务期间，必须严格遵守本文档规定的所有边界与门控。

---

## 1. 核心红线与物理边界 (Core Boundaries & Physical Isolation)

### 1.1 闭源内核物理隔离
- **开源前端仓库**：`/Volumes/2T/Projects/SilkPlayer/SilkPlayer`（LGPL-3.0 协议，公开发布）。
- **闭源商业内核**：`/Volumes/2T/Projects/SilkPlayer/SilkCoreKit`（专有商业授权，本地独立物理目录隔离）。
- **隔离红线**：严禁将 `SilkCoreKit` 的源代码、私有协议实现或内部数据结构提交或反向合并至开源前端仓库。二者仅通过预编译二进制包 `Packages/SilkCoreKit.xcframework` 进行符号链接与桥接。

### 1.2 本地敏感路径绝对禁区
- **严禁访问路径**：严格禁止通过任何命令（包括 `find`、`grep`、`ls`、Shell 脚本或文件读取工具）访问、扫描、读取或修改 `/Volumes/HDD1T` 与 `/Volumes/HDD2T/临时下载` 目录。
- **最小化扫描范围**：除用户明确指示的业务挂载路径外，严禁对宿主机根目录或非本工程目录进行大范围递归扫描与遍历。

### 1.3 双轨制产品矩阵与命名规范
- **免费版（Community / Standard Edition）**：
  - 产品命名：严格使用 `SilkPlayer`（严禁附带 Pro 后缀）。
  - 版本号规范：严格限定在 `1.x` 序列（如 `1.6.0`、`1.7.0`），主干分支为 `main`。
  - 特性边界：开源前端，无商业授权锁、无强制付费限制，坚守永久免费承诺。
  - 发布镜像：统一命名为 `SilkPlayer-<version>-universal.dmg`。
- **专业版（Pro Edition）**：
  - 产品命名：商业发行命名为 `SilkPlayer Pro`，但**版本号严禁附加 `-pro` 标识**，直接使用标准语义化版本号 `2.0.0`（严禁写成 `2.0.0-pro`）。
  - 版本号规范：版本号起步为 `2.0.0`，严格归入 `2.x` 及后续大版本序列（严禁占用 1.x 次版本号）。
  - 分支维护：在独立下游分支（如 `feature/v2.0.0`）持续维护，严禁将 Pro 商业授权代码与闭源内核反向合入开源 `main` 主干。
  - 发布镜像：统一命名为 `SilkPlayer-Pro-<version>-universal.dmg`（如 `SilkPlayer-Pro-2.0.0-universal.dmg`）。
- **版本号格式**：版本命名统一去除 `v` 前缀（例如使用 `2.0.0`，不使用 `v2.0.0` 或 `2.0.0-pro`）。

### 1.4 双轨更新说明阐述规范 (Dual-Track Release Notes Standard)
- 自 `2.0.0` 起，随着版本的持续迭代，所有公开发布的更新说明（Release Notes 与 Changelog）**必须强制结构化分列免费版与 Pro 版**，分别按以下三要素进行客观阐述，严禁混淆：
  1. **【免费版 / Standard Edition】**：
     - 新增特性 (Features)
     - 优化改进 (Improvements)
     - 问题修复 (Bug Fixes)
  2. **【专业版 / Pro Edition】**：
     - 新增特性 (Features)
     - 优化改进 (Improvements)
     - 问题修复 (Bug Fixes)
- 无论是在 GitHub Releases、官网还是客户端内更新提示，均严格遵循此双轨分列结构。

### 1.5 Git 提交规范与作者标准
- 所有 Git 提交必须统一显式指定提交作者：`--author="meowvia <meowvia@users.noreply.github.com>"`。
- 提交信息必须遵循 Conventional Commits 格式（如 `fix(theme): ...`、`feat(library): ...`），简明扼要表达变更内容。

### 1.5 用语与文档表达纪律
- **彻底去除 Emoji**：所有代码注释、提交信息、交付文档、发布说明及交互沟通中，严禁出现任何 Emoji 图标。
- **严禁中二造词与夸大吹嘘**：严禁使用夸张造词（如“最高宪法”、“工业级基石”、“彻底焊牢”、“原子级”、“核心病灶”、“把脉开方”等），必须 100% 采用客观、精确、平实的行业标准工程师术语。

---

## 2. 任务执行防失控与防空转铁律 (Execution Control Safeguards)

为彻底杜绝大任务无限自旋、Token 巨额浪费与漫长未知结果的严重事故，执行任何任务必须无条件遵守以下四条硬性铁律：

### 2.1 任务强制切片，严禁单回合多模块并发（范围拦截）
- 单次回合内只允许承接**一个明确定义的独立子任务**（例如：只调整设置项外观与主题逻辑，绝不同时重构播放管线或音频解码器）。
- 收到包含多个架构级特性的复合需求时，首轮必须输出阶段切片清单（Phase 1 / Phase 2 / Phase 3），且**仅锁定执行 Phase 1**。
- 每一个 Phase 必须完成定向验证并向用户交付成果，经确认后方可进入下一个 Phase。

### 2.2 实施 15 步 / 10 分钟强制拦截门控（时间与调用拦截）
- 任何调试、排查或代码编写任务，若工具调用步数达到 **15 步** 或执行耗时预计达到 **10 分钟** 且尚未完成修改，**必须立即终止自动尝试**。
- 必须在界面上主动向用户汇报：① 当前已确认的事实；② 已排除的根因；③ 下一步精确定向方案；严禁陷入黑盒静默自旋。

### 2.3 外科手术式定点排查三步法（排查门控）
- **单点定位**：直接定位到触发问题的单一入口函数，只读取该函数及上下文 50 行以内代码。
- **边界隔离**：严禁无目的全库 `grep`、全局 `find` 或跨业务边界翻查无关文件（例如：排查外观主题冲突时，严禁翻阅播放器解码管线或音频着色器代码）。
- **定向落笔**：理清时序后再修改代码，修改必须最小化且定向验证。

### 2.4 奥卡姆剃刀方案门控（过度工程拦截）
- 凡是通过系统原生工具、Shell 管道、简短脚本即可解决的周边需求，严禁擅自上升为后台服务、额外插件或重型架构。
- 严禁扫描与当前任务无关的本地工程或系统目录。

---

## 3. 标准构建、测试与发版流水线 (Build, Test & Packaging Pipelines)

### 3.1 内核联调与 xcframework 编译流水线
当对 `SilkCoreKit` 内部源码进行修改后，必须重新编译并同步框架二进制：
```bash
cd /Volumes/2T/Projects/SilkPlayer/SilkCoreKit && ./build_framework.sh
```
该脚本执行以下闭环操作：
1. 交叉编译 macOS `arm64` 与 `x86_64` Release 架构目标；
2. 提取并生成通用 Swift Module 接口与 ABI 描述；
3. 组装双架构 `SilkCoreKit.xcframework`；
4. 自动覆盖同步至前端工程目录 `/Volumes/2T/Projects/SilkPlayer/SilkPlayer/Packages/SilkCoreKit.xcframework`。

### 3.2 自动化回归测试流水线
任何前端代码或框架更新后，必须执行全量自动化测试，确保零回归：
```bash
cd /Volumes/2T/Projects/SilkPlayer/SilkPlayer && ./scripts/run_tests.sh
```
标准交付要求：所有测试用例（如 63/63 套件）必须 100% 通过（0 failures）。

### 3.3 本地打包与实机安装流水线
本地快速实机验证：
```bash
cd /Volumes/2T/Projects/SilkPlayer/SilkPlayer
./scripts/package_app.sh 2.0.0-pro universal --app-only
./scripts/install_to_applications.sh
```
正式 Universal 镜像构建（含签名与打包）：
```bash
./scripts/package_app.sh <version> universal
```

### 3.4 动态库依赖与签名审计
- 嵌入的第三方多媒体框架（如 `Libavcodec`、`Libavformat` 等）必须严格对齐 `@rpath`；
- 静态核心 `SilkCoreKit` 不得携带任何宿主机私有绝对路径；
- 二进制签名状态必须校验通过（`codesign -vvv /Applications/SilkPlayer.app`）。

---

## 4. 文档归口与资产沉淀原则 (Documentation Anchoring)

为杜绝在聊天窗口倾倒大段冗余信息，所有工程成果必须沉淀到指定文件：
- **版本发版说明**：沉淀于 `Documentation/RELEASE_NOTES_<version>.md`；
- **交付归档与变更记录**：沉淀于 `Documentation/DELIVERY_ARCHIVE_<version>.md` 与 `CHANGELOG.md`；
- **官方网站维护手册**：沉淀于 `Website/README.md`；
- **已知缺陷与排查记录**：沉淀于 `Documentation/KNOWN_ISSUES.md`。

---

## 5. 跨会话接力协议与接手 Agent 行为准则 (Handoff Protocol & Agent Behavior)

### 5.1 接手 Agent 行为准则
新会话中的接手 Agent 接收到接力指令后，必须严格遵循以下行为步骤：
1. **强制阅读纪律文档**：第一步必须完整读取本文档（`Documentation/ENGINEERING_DISCIPLINE.md`）；
2. **静默状态检查**：仅执行 1-2 条只读状态核验命令（确认 Git 分支、最新 Commit 与工作区干净状态）；
3. **输出标准 3 行接力对齐回复**：
   - 第一行：确认工程基准对齐（当前分支与 Commit 哈希）；
   - 第二行：确认纪律文档已加载，当前测试状态已确认；
   - 第三行：陈述当前已锁定的下一步单一切片任务（如 Phase 1 目标），明确表示进入静止等待状态，等待用户输入；
4. **绝对静止原则**：在用户给出明确开始指令前，**严禁擅自修改任何代码、创建文件或执行写操作**。

### 5.2 轻量化接力清单输出标准
交接发起方在生成接力清单时，严禁重复倾倒静态纪律全文，必须严格收拢在**单个 Markdown 代码块**内，控制在 25-35 行，仅包含以下 4 项动态要素：
1. **【工程当前基准与资产状态】**：双库路径、分支、最新 Commit、测试状态；
2. **【强制遵循的工程纪律事实源】**：明确指向 `Documentation/ENGINEERING_DISCIPLINE.md`；
3. **【核心共识与待办切片】**：已确认事实、已排除方案、下一 Phase 定向任务切片；
4. **【接手行为指令】**：指示接手 Agent 执行静默对齐、输出 3 行回复并保持静止等待。
