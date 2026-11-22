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

### 1.3 双轨制能力交付、权限归属与统一版本规范
- **统一版本号与单包双轨架构（自 2.0.0 起）**：
  - 安装镜像统一命名为 `SilkPlayer-<version>-universal.dmg`（如 `SilkPlayer-2.0.0-universal.dmg`），**统一去除 `v` 前缀与 `-pro` 后缀**。
  - 单一安装包内根据用户授权状态动态切换能力集：未激活态运行免费标准模式（无广告、无催付弹窗、核心音画能力不阉割；商业授权严格实行**一机一码硬件绑死**，不开放用户端停用解绑），激活态就地解锁 Pro 增强能力集（局域网 SMB/NFS 媒体库、独立折叠音乐模式、多声道离散直通、四色全局主题等）。
  - **功能下放与共享指令门控**：推进新特性或体验优化时，若用户明确指示“该功能/优化同步给免费版”，须同时对未激活标准模式开放，持续维护免费版的实用体验与口碑。
  - 历史 `1.x` 开源主干保留于 `main` 分支；`2.x` 系列在独立发布分支（如 `release/2.0.0`）演进，严禁将 `SilkCoreKit` 闭源源码提交至公开仓库。

### 1.4 官网克制原则与极简更新说明规范 (Restrained Release Notes Standard)
- **官网不堆砌版本日志**：官方网站（`silkplayer.1999909.xyz`）定位为稳定的成品展示、高速下载与购买转化主入口；日常版本迭代仅通过 `sync_release.sh` 静默替换安装包并自动更新按钮版本号，不在官网罗列琐碎更新记录（仅在跨代大功能落地时调整官网版块）。
- **更新说明极简克制、只写结果**：
  - 自 `2.0.0` 商业化起，GitHub Releases 与 `RELEASE_NOTES` 大幅缩减篇幅，**严禁写成开发工作流水账，严禁披露 `SilkCoreKit` 闭源商业模块的底层实现细节、参数策略或内部重构过程**；
  - 摒弃生硬凑字数的六宫格固定模板，全文聚焦用户可直观感知的结果（日常维护版通常控制在 2～5 行精炼短句，底层调优与常规修补合并为一句话概括）；
  - **清晰点明免费版受益项**：当版本中包含明确同步给免费版的新功能或体验改进时，简明区分标注 **【通用 / 免费版同步更新】** 与 **【Pro 增强】**（若某次小更新仅涉及单一侧，按实简写即可，不强凑空项），让免费版用户直观感受到基础体验仍在持续演进，同时保持克制、平实的成熟产品调性。

### 1.5 Git 提交规范与作者标准
- 所有 Git 提交必须统一显式指定提交作者：`--author="meowvia <meowvia@users.noreply.github.com>"`。
- 提交信息必须遵循 Conventional Commits 格式（如 `fix(theme): ...`、`feat(library): ...`），简明扼要表达变更内容。

### 1.6 用语与文档表达纪律
- **彻底去除 Emoji**：所有代码注释、提交信息、交付文档、发布说明及交互沟通中，严禁出现任何 Emoji 图标。
- **严禁中二造词与夸大吹嘘**：严禁使用夸张造词（如“最高宪法”、“工业级基石”、“彻底焊牢”、“原子级”、“核心病灶”、“把脉开方”等），必须 100% 采用客观、精确、平实的行业标准工程师术语。

---

## 2. 任务执行防失控与免盯屏直通铁律 (Execution Control Safeguards)

为同时杜绝“后台死循环烧钱”与“频繁停顿逼迫用户盯屏点继续”两大痛点，执行任何任务必须遵守以下**“正向直通、异常即停”**铁律：

### 2.1 双轨响应：探讨零工具，明确任务单轮直通闭环
- **探讨与咨询轨（Zero-Tool Gate）**：理论、机制、架构评估与方案咨询**严禁调用任何工具**，直接基于现有上下文客观作答，严禁借口防幻觉翻查代码。
- **实施与排查直通轨（免盯屏一气呵成）**：当用户下达明确的审查、定位、修改、测试或打包指令（尤其明确要求“一并执行”时），只要每一步正向顺利推进，**严禁机械按固定步数半途停下索要“继续”**，应在单回合内一口气走完「精准定位 → 定点修改 → 定向验证」直接交付最终结果（常规任务控制在 **6 步以内**一气呵成）。仅当跨越多个重型底层模块重构且风险极高时，才拆分阶段推进。

### 2.2 异常即停熔断器：按“卡壳与报错”精准拦截（防烧大钱）
- **盲搜 2 步熔断**：定位目标代码最多允许 **2 步**；若 2 步仍未锁定准确文件与函数，必须立即停手向用户确认，严禁无目的全局 `grep` / `find` 乱翻。
- **试错 2 败熔断**：修改后若编译或测试报错，最多允许自我修正重试 **1 次**；若连续 **2 次**未通过，**无条件立即终止尝试**并向用户汇报卡点，严禁在后台死磕第 3 次。
- **高危必停与同步提速**：涉及删除用户数据、强杀/覆盖正在运行的自用进程或未授权变更线上环境时必停请示；日常局部验证优先使用 `swift test --filter <目标测试类>` 秒级同步拿结果，避免短任务超时转后台引发二次唤醒计费。

### 2.3 外科手术式定点排查三步法（排查门控）
- **单点定位**：直接定位到触发问题的单一入口函数，只读取该函数及必要上下文代码。
- **边界隔离**：严禁跨业务边界翻查无关文件（例如：排查外观主题冲突时，严禁翻阅播放器解码管线或音频着色器代码）。
- **定向落笔**：理清时序后再修改代码，修改必须最小化且一次到位验证。

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

### 3.5 发版后官网一键同步与防失误核验铁律（严禁遗漏）
每当客户端发布新版本（或用户告知已更新 GitHub Release）时，**严禁靠人工记忆逐个改文件**，必须执行官网内置的一键防呆同步脚本，确保中国大陆用户通过官网与客户端内检查更新均 100% 命中最新 Cloudflare 边缘静态直链（杜绝落回旧版包或直连 GitHub 超时）：
```bash
/Volumes/2T/Projects/SilkPlayer/Website/scripts/sync_release.sh <version> [path_to_universal_dmg]
```
该脚本自动闭环执行以下全部动作并做强校验（任一步失败立即报错中止）：
1. 对 DMG 执行 `hdiutil verify` 完整性校验，覆盖更新 `Website/downloads/SilkPlayer-{universal,arm64,x86_64}.dmg`；
2. 自动同步更新 `Website/functions/api/download.js` 与 `version.js` 中的 `LOCAL_EMBEDDED_TAG` 及静态资源缓存时间戳；
3. 自动执行 `wrangler pages deploy` 与 Cloudflare 全局缓存刷新；
4. 自动拉取线上 `https://silkplayer.1999909.xyz/api/version` 与 `/api/download`，实测比对版本号、`Content-Length` 与完整 **SHA-256 哈希 100% 一致**后才允许汇报完成。

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
