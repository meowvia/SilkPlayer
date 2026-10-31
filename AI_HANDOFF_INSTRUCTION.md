# SilkPlayer 工程移交接力规范与标准化模板 (Master AI Handoff Specification)

本文档为 SilkPlayer 项目所有 AI 会话窗口交接、任务移交以及多 Agent 协同的**最高执行规范**。任何新会话或接手 Agent 必须 100% 严格执行本文档中的四项工程铁律与标准化移交模板，严禁擅自删减或变更格式。

---

## 一、 四大工程铁律 (The Four Cardinal Rules)

### 铁律 1：文档管理责任归口与防混乱纪律
为防止各 Agent 格式不一、碎片化记录导致项目状态严重倒挂，全工程仅设立两大核心事实源文档：
1. **`Documentation/FEATURE_PROPOSALS.md`（唯一定点功能规划与提案库）**：
   - 所有未经落地的新功能、体验优化与技术攻关提案，必须在此按“提案 xxx”统一编号登记；
   - 方案落地并通过测试验证后，必须在此文档中划掉销项，并明确注明落地的具体版本号（如 `~~提案 006~~ 已落地销项 (v1.4.0)`）；
2. **`Documentation/KNOWN_ISSUES.md`（唯一定点缺陷追踪表）**：
   - 所有缺陷报障、排查根因、复现步骤与技术修复路径统一按“ISSUE-xxx”编号登记；
   - 修复合入主分支并全量测试通过后，状态必须明确更新为“已修复 (版本号)”，严禁遗漏销项；
3. **严禁私自建立临时性散落文档**：
   - 绝对禁止在项目根目录、Documentation 或其他目录私自新建任何临时任务清单、修复总结或碎片化备忘；
   - 严禁凭空臆断，必须以实际源码（Single Source of Truth）为准。

### 铁律 2：Token 消耗控制与外科手术式修改纪律
当前版本已步入稳定迭代期，为彻底杜绝 Token 无效膨胀，必须严格遵循以下执行纪律：
1. **外科手术式定点排查，绝对禁止全库盲搜**：
   - 严禁无脑使用递归全库 `grep`、`find` 或通读无关的大型代码文件；
   - 严格根据报障与需求现象，直接定位到具体目标文件与函数（如：音频时钟定位 `SilkAudioEngine.swift`、窗口尺寸与最大化定位 `PlayerWindowManager.swift`、Metal 着色器定位 `VideoShaders.metal`）；
2. **杜绝冗余上下文复述与废话套话**：
   - 移交清单与交接回复直奔主题，严禁大段倾倒已有历史背景、哲学阐述或无意义的寒暄模板；只陈述精确路径、变更逻辑要点与测试数据；
3. **测试与日志输出静默化过滤**：
   - 运行构建与测试脚本时，禁止将数百行原始 log 原样倾倒进聊天上下文，仅提取失败项或最终统计摘要（如 `59/59 Passed`）；
4. **单目标聚焦闭环**：
   - 单次迭代聚焦 1~2 个明确靶点，完成即测试验证并收尾，避免多任务并发引发巨额上下文堆叠；
5. **禁止挂载后台常驻轮询与死循环脚本**。

### 铁律 3：双版本与双架构迭代一致性对齐纪律
SilkPlayer 实行双版本支持与双端协同架构：
1. **双芯片架构对称支持**：
   - 核心构建与二进制支持涵盖 Apple Silicon (`arm64`) 与 Intel (`x86_64`)；
   - 每一项新功能或底层改动推进时，必须同步核验两个架构的兼容性与构建一致性，严禁出现仅在单架构生效而在另一架构崩溃或闪退的情况；
2. **开源前端与闭源内核严格对齐**：
   - 开源前端（`/Volumes/2T/Projects/SilkPlayer/SilkPlayer`）与闭源内核（`/Volumes/2T/Projects/SilkPlayer/SilkCoreKit`）严格解耦；
   - 接口契约变更必须同步保持向下兼容与版本号一致，严禁私自修改内核未暴露签名，内核代码严禁提交至公开仓库。

### 铁律 4：编译与交付测试铁律（未定稿前禁止编译 DMG）
1. **未定稿前禁止编译 DMG**：
   - 研发与阶段性测试期间，绝对禁止执行 DMG 镜像打包（`hdiutil` 耗时长、I/O 负载重且易堆叠中间镜像）；
   - **仅在版本最终定稿发版时，才执行全量签名与 DMG 制作**；
2. **阶段性测试交付标准流程**：
   - 代码定点修改完成并通过 `./scripts/run_tests.sh` 单元测试后，执行快速测试部署：
     1. 仅编译并组装 `.app` 产物（跳过 DMG 构建）；
     2. 运行 `./scripts/clean_installed_app.sh` 彻底清理运行进程、旧版安装包、LaunchServices 缓存与测试临时配置；
     3. 运行 `./scripts/install_to_applications.sh` 将新 `.app` 安装至 `/Applications/SilkPlayer.app` 并刷新 Dock 缓存；
     4. 执行 `open /Applications/SilkPlayer.app` 拉起新版本交付用户体验测试；
   - 可直接使用一键集成脚本：`./scripts/deploy_dev_test.sh [arm64|x86_64]`。

---

## 二、 每次移交接力清单格式化标准 (Mandatory Handoff Template)

任何会话发起交接时，**必须且只能**采用以下标准模板输出，包含所有指定要素，不允许任何删减：

```markdown
# SilkPlayer 工程移交接力清单 (Handoff Prompt)

## 1. 当前物理基准与版本状态
- **工程路径**: `/Volumes/2T/Projects/SilkPlayer/SilkPlayer` (开源前端) · `/Volumes/2T/Projects/SilkPlayer/SilkCoreKit` (闭源内核)
- **Git 状态**: 分支 `<branch_name>` · Commit `<commit_hash>` · 工作区状态（Clean / Modified）
- **当前版本基准**: `v<current_version>` (双架构支持: Apple Silicon arm64 & Intel x86_64)
- **自动化测试基线**: `./scripts/run_tests.sh` -> 59/59 Passed (0 failures)

## 2. 文档事实源与跟踪状态
- **功能规划库 (`Documentation/FEATURE_PROPOSALS.md`)**:
  - 当前进行中排期: <当前排期任务编号与名称，例如 提案 013 HDR 动态 EDR 高光压制>
  - 下一阶段候选池: <候选任务编号>
- **缺陷跟踪库 (`Documentation/KNOWN_ISSUES.md`)**:
  - 现存未解决缺陷: <列出未解决编号，若无则注明“全量闭环”>
  - 最新闭环缺陷: <列出近期闭环的 ISSUE 编号与解决版本>
- **文档维护铁律**: 严禁私建临时文档；新功能落地后必须在 FEATURE_PROPOSALS.md 划销；新缺陷与修复必须在 KNOWN_ISSUES.md 编号销项。

## 3. 双架构与双版本对齐基准
- **架构对称性检查**:
  - Apple Silicon (arm64): 编译与运行状态对齐
  - Intel (x86_64): 编译与运行状态对齐
- **内核与前端契约**:
  - SilkCoreKit 暴露接口版本号与引用保持一致
  - 闭源内核物理隔离，严禁源码泄露或推送到公开仓库

## 4. 本次移交核心任务与定点实施方案
- **核心目标**: <1~2 句话客观描述本次需要攻关的核心任务>
- **定点代码位置**:
  - 文件 1: `<绝对路径或相对路径>` (定位到具体函数与行号)
  - 文件 2: `<绝对路径或相对路径>` (定位到具体函数与行号)
- **实施技术路径**:
  - <定点修改思路与算法，杜绝中二用词，使用客观工程术语>

## 5. Token 控制与执行纪律约束
- **排查约束**: 严禁无脑全库 grep/find，必须直奔上述定点文件；
- **输出约束**: 测试脚本运行只报告摘要计数与失败项，禁止倾倒长篇日志；
- **边界约束**: 禁止改动无关的成熟业务逻辑，严禁挂载后台死循环。

## 6. 测试交付与验证流程（严禁未定稿编译 DMG）
- **步骤 1**: 定点编码完成后，执行 `./scripts/run_tests.sh` 确保回归测试 100% 绿灯；
- **步骤 2**: 执行测试部署（不编 DMG）：
  `./scripts/deploy_dev_test.sh $(uname -m)`
  *(自动执行: package_app --app-only -> clean_installed_app -> install_to_applications -> open)*
- **步骤 3**: 直接拉起 `/Applications/SilkPlayer.app` 交付用户实机测试验收；
- **步骤 4**: 仅在用户最终明确下达定稿发版指令后，方可执行正式 DMG 编译。
```
