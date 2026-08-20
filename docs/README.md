# Godot My Farm 开发文档

本目录是 Codex 开发游戏时的唯一规范入口。目标是使用 **Godot 4.7 标准版与 GDScript**，在不依赖 Unity 运行时和 C#/.NET 的前提下，重建 `Archermmt/my_farm` 已有的玩法结构，并通过 godot-ai 驱动 Godot 编辑器完成场景搭建、运行验证和可视化验收。

## 1. 文档优先级

出现冲突时按以下顺序处理：

1. 当前用户明确提出的要求。
2. [01_TECHNICAL_RULES.md](./01_TECHNICAL_RULES.md) 的硬性技术规则。
3. [02_ARCHITECTURE.md](./02_ARCHITECTURE.md) 的模块边界和数据所有权。
4. [00_GAME_DESIGN.md](./00_GAME_DESIGN.md) 的玩法范围。
5. 当前任务卡。
6. [03_REFERENCE_MAPPING.md](./03_REFERENCE_MAPPING.md) 中的参考实现细节。

参考项目用于确认行为和职责，不是逐行移植规范。不得因为 Unity 参考代码的实现方式而违反本项目的 Godot/GDScript 规则。

## 2. 开发前阅读顺序

Codex 在首次开发前必须依次完整阅读：

1. 本文件。
2. [00_GAME_DESIGN.md](./00_GAME_DESIGN.md)。
3. [01_TECHNICAL_RULES.md](./01_TECHNICAL_RULES.md)。
4. [02_ARCHITECTURE.md](./02_ARCHITECTURE.md)。
5. [03_REFERENCE_MAPPING.md](./03_REFERENCE_MAPPING.md)。
6. [04_GODOT_AI_WORKFLOW.md](./04_GODOT_AI_WORKFLOW.md)。
7. [05_TEST_PLAN.md](./05_TEST_PLAN.md)。
8. [TASKS.md](./TASKS.md) 和当前唯一一个任务卡。

之后每次继续开发，先读取 [STATUS.md](./STATUS.md)。T01 会把文档阶段状态初始化为实际工程状态，之后持续维护当前任务、已验证能力、已知问题和下一步；它不能覆盖本目录中的设计决定。

## 3. 核心参考

| 参考 | 用途 | 固定基线 |
|---|---|---|
| [Archermmt/my_farm](https://github.com/Archermmt/my_farm) | 玩法、系统职责、交互节奏、场景组织的核心参考 | `bd808154b479f87efc4fc06ff42c683d7db351bc` |
| 本机 `/Users/tongmeng/Desktop/codes/my_farm` | 上述提交的只读代码级参考 | Unity/C#，仅供分析 |
| `/Users/tongmeng/Desktop/codes/farm-game-godot/docs` | Codex 任务拆分和验收文档格式参考 | 不直接继承其游戏范围 |
| [htdt/godogen](https://github.com/htdt/godogen) | 自主开发方法：持久状态、运行结果优先、视觉证明 | `05cebffc8b10c5817e8a3db495b82e7b6004ab84` |
| 本机 `/Users/tongmeng/Desktop/codes/godot-ai` | Godot 编辑器 MCP 工具能力与操作语义 | `d602a78322c66a24969f37f261e0364465cff464` |

## 4. 不可变约束

- 只使用 GDScript；禁止创建 `.cs`、`.csproj`、`.sln` 或依赖 Godot .NET。
- Godogen 上游的 Godot 引擎指南使用 C#/.NET 和构建期 scene builder；本项目只采用其开发/验收方法，不采用该技术栈或场景生成方式。
- 目标是相同的玩法和职责划分，不复制参考仓库的 C# 源码、Unity YAML、GUID、Prefab 或未确认授权的美术/音频。
- 没有明确授权时，使用程序化占位图或原创临时资源；首次调用付费资源生成服务前必须征得用户同意。
- 一次只实现一张任务卡。任务未通过自动化检查、运行检查和视觉检查，不得标记完成。
- 编译或脚本解析成功不等于完成。必须运行实际游戏并验证可见行为。
- 不擅自增加第三方插件。测试和运行时首先使用 Godot 内建能力；godot-ai 是开发辅助，不是游戏发布依赖。
- 不把 Debug 快捷键、临时作弊入口或测试节点留在发行场景，除非任务卡明确要求且默认关闭。

## 5. 每个任务的固定执行循环

1. **定位**：确认前置任务完成，读取任务卡、相关架构章节和 `STATUS.md`。
2. **检查**：通过 godot-ai 确认活动会话、Godot 版本、当前场景和编辑器 readiness。
3. **小步实现**：先数据/逻辑，后场景绑定，再表现；脚本每次写入都检查返回的 diagnostics。
4. **静态验证**：扫描文件系统，检查编辑器错误；能执行时运行 headless 测试。
5. **运行验证**：用 godot-ai 启动项目，读取 editor/game 日志。
6. **行为验证**：用稳定的 action 输入序列复现任务验收场景，检查运行时状态。
7. **视觉验证**：截取运行中游戏画面，检查空白、遮挡、越界、缩放和层级。
8. **记录**：只在全部通过后更新 `STATUS.md` 和 [TASKS.md](./TASKS.md) 的状态。

## 6. 完成定义

一张任务卡完成必须同时满足：

- 任务卡列出的文件和行为已实现，没有越界扩展。
- 新增或改变的领域逻辑有自动化测试，且测试通过。
- Godot 编辑器没有由本次修改产生的错误或警告。
- 项目可运行，game log 没有异常。
- 任务卡的手动/输入序列验收全部通过。
- 所有可见改动都由运行中游戏截图验证；交互或动画任务还需连续输入验证，最终整合任务需录制 15-20 秒证明片段。
- `STATUS.md` 记录验证命令、截图路径、遗留风险和下一张任务。

## 7. 文档索引

| 文档 | 内容 |
|---|---|
| [00_GAME_DESIGN.md](./00_GAME_DESIGN.md) | 玩法目标、功能边界、首日闭环和非目标 |
| [01_TECHNICAL_RULES.md](./01_TECHNICAL_RULES.md) | Godot/GDScript、场景、资源、输入、存档和质量规则 |
| [02_ARCHITECTURE.md](./02_ARCHITECTURE.md) | 总体架构、目录、模块职责、数据流和存档模型 |
| [03_REFERENCE_MAPPING.md](./03_REFERENCE_MAPPING.md) | Unity 成品到 Godot 的行为与结构映射 |
| [04_GODOT_AI_WORKFLOW.md](./04_GODOT_AI_WORKFLOW.md) | 使用 godot-ai 搭建和验证项目的标准流程 |
| [05_TEST_PLAN.md](./05_TEST_PLAN.md) | 自动化、集成、视觉验收和最终证明场景 |
| [TASKS.md](./TASKS.md) | 阶段、依赖、任务状态和执行顺序 |
| [STATUS.md](./STATUS.md) | 当前可恢复进度、验证证据、已知问题和下一步 |
| [tasks/](./tasks/) | 可独立交给 Codex 执行的任务卡 |
