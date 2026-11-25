# Musaic

Flutter 应用，支持 Android 和 iOS。

包名：`com.deskbtm.musaic`。

## 架构：功能优先（Feature-first，强制要求 AI Agent 遵循）

**本项目采用 Feature-first（功能优先）架构。所有 AI Agent 在新增、移动或重构代码时，都必须遵守以下架构边界。**

- 按照代码所属的功能职责组织代码，而不是按照使用它的页面组织代码。即使某个功能只被一个页面使用，也必须放在 `lib/features/` 下。
- `lib/pages/` 仅用于存放页面入口、页面及 Sheet 的布局组装、事件连接，以及必要的页面生命周期逻辑。
  - `lib/pages/home/` 仅存放 `home_page.dart` 和 `home_sheet.dart`。
  - 禁止在页面目录中新增功能控制器（Feature Controller）、规划器（Planner）、资源管线（Resource Pipeline）或转场引擎（Transition Engine）。
  - 禁止将这些模块的具体实现移动到页面文件中。
- `lib/features/<feature>/` 负责管理所属功能相关的状态、类型、控制器、流程编排、视觉行为和交互逻辑。
  - 保持每个 Feature 内部的高内聚。
  - 不要为了存放 Home 页面使用的各种无关功能，而创建通用的 `features/home/` 目录。
- `lib/ui/` 用于存放共享 UI 基础组件、通用视觉计算逻辑和主题。
  - 功能专属的工作流和转场状态机必须保留在其所属的 Feature 中。
- 以下目录必须各司其职：
  - `lib/app/`：应用组装和生命周期管理。
  - `lib/services/`：现有业务服务和外部集成。
  - `lib/storage/`：持久化存储。
  - `lib/config/`：配置管理。
  - `lib/l10n/`：国际化和本地化。
- Feature 不得导入 Pages 或应用组装层。
- Services 和 Storage 不得导入 Pages、UI 或应用组装层。
- 新增或移动文件之前，必须先确定该文件所属的 Feature，并检查依赖导入方向。
- 测试文件必须放在 `test/` 下，并保持与源代码目录结构对应。

## 开发工作流

- 使用 `mise install` 安装 `mise.toml` 中指定版本的 SDK。
- 使用最新的 Flutter 官方文档和 Context7 获取库/API 文档、代码生成、环境搭建及配置相关信息。
- 跨页面共享的状态使用 `signals_flutter`。
- 自包含 UI（例如 Dialog、Sheet、动画和输入组件）应当通过 `StatefulWidget` 和局部控制器自行管理状态。
- 服务依赖通过构造函数传入。
- 路由页面统一使用 `*_page.dart` 命名。
- 遵循 `analysis_options.yaml` 中的规范。
- 应用 UI 图标统一使用 Phosphor Icons。
- Flutter 命令必须串行执行：
  - `flutter analyze`
  - `flutter test`
  - 各平台构建命令。
- 修改 ARB 文件后，运行 `flutter gen-l10n`。
- 修改 Drift、Envied 或 Dart Mappable 源文件后，运行 `dart run build_runner build`。
- 绝对不要提交 `.env`、签名材料、生成的环境变量值或机器本地路径。
- 严格控制修改范围，不要进行与当前任务无关的修改。
- 用户要求提交代码时，使用 Conventional Commits 规范；不要自动提交。
- 如果项目中存在 `.codegraph/`，在搜索或读取应用代码之前，必须先使用 CodeGraph。

## 代码设计规范

- 应用 UI 和静态页面样式必须遵循 [设计规范文档](docs/design-guidelines.md)。
- 编写优雅、易读的代码：
  - 使用准确、明确的命名。
  - 保持控制流程简单直接。
  - 明确表达状态转换。
- 保持高内聚：
  - 每个模块只负责一个清晰的职责。
  - 将相关状态和行为放在一起管理。
- 保持低耦合：
  - 通过精简、明确的接口进行模块间通信。
  - 通过构造函数传递依赖。
  - 将实现细节保持为私有。
- 根据职责边界和变更边界拆分文件、组件和函数。
  - 选择有利于理解逻辑的合理代码规模。
  - 只有当抽象能够明确当前设计，或者消除有实际意义的重复代码时，才引入抽象。
- 在保证正确性和代码清晰度的前提下，追求尽可能高的实际性能：
  - 减少重复计算。
  - 减少不必要的 Widget 重建。
  - 减少不必要的重绘。
  - 减少不必要的内存分配和 I/O。
  - 将耗时操作放在 UI 线程之外执行。
  - 使用性能分析工具验证性能优化是否真正有效。

## 自动化测试策略（Automated Testing Policy）

### 默认规则：禁止自动运行测试

除非用户在当前任务中明确要求执行测试或验证，否则**不得主动运行自动化测试或验证命令**。

包括但不限于：

- `flutter test`
- `dart test`
- `flutter analyze`
- `dart analyze`
- `flutter build`
- 集成测试（Integration Tests）
- Golden 测试（Golden Tests）
- 性能基准测试（Performance Benchmarks）
- 其他自动化测试或验证套件。

### 开发工作流

执行开发任务时：

1. 阅读并理解相关源代码。
2. 实现用户要求的修改。
3. 检查修改过的代码和 Git Diff。
4. 通过代码审查检查明显的逻辑错误、缺失的引用以及非预期的修改。
5. 不要自动运行测试、构建或代码分析命令。

### 由用户主导测试

- 默认将实际测试工作交给用户执行。
- 只有用户明确要求时，才运行测试。
- 如果认为必须通过测试才能确认某个疑似问题，应先向用户说明原因，并征得用户同意后再运行。
- 未经授权，不要反复运行测试或验证命令。

### 任务完成报告

每项任务结束时：

- 明确说明尚未执行自动化测试。
- 总结本次实现的内容。
- 列出需要用户重点进行人工验证的部分。
- 如果实际上没有运行测试，绝对不要声称代码已经通过测试。

### 重要原则

将代码实现质量和代码审查放在不必要的自动化测试之前。

当用户计划自行进行人工验证时，避免在重复的测试和构建循环中浪费模型额度。
