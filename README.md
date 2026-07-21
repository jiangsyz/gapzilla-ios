# Gapzilla iOS

Gapzilla 的原生 iOS 客户端。产品用事实记录破例与被控制住的冲动，通过间隔变化帮助用户看见长期改善。

本项目以 Gapzilla Web 的品牌调性和业务功能为基础，但采用原生 iOS 信息架构、导航、交互和数据存储方式，不是网页的容器或逐像素复刻。

## 当前范围

- SwiftUI 原生界面，最低支持 iOS 17；V1.0 首发仅支持 iPhone。
- 登录、注册和 Keychain 会话保存。
- 多目标创建、切换、重命名和删除。
- “今天”首页：当前间隔、快捷记录、正向反馈和最近事件。
- “历史”页：月历、破例与冲动标记、间隔影响。
- “分析”页：当前、最长、平均间隔，趋势图和冲动正向证据。
- 原生记录 Sheet、日期选择器、触感反馈、下拉刷新和中英文切换。
- 使用既有 Gapzilla 品牌标志生成 App Icon。
- 生产 API：`https://api.gapzilla.quietbase.online`。

## 项目结构

- `Gapzilla/App`：App 入口和根导航。
- `Gapzilla/Core`：数据模型、API、Keychain、状态和视觉系统。
- `Gapzilla/Features`：认证、今天、历史、分析、目标和记录功能。
- `Gapzilla/Resources`：Asset Catalog。
- `Gapzilla.xcodeproj`：Xcode 工程和共享 Scheme。

## 本地运行

1. 使用 Xcode 26 或兼容版本打开 `Gapzilla.xcodeproj`。
2. 选择 `Gapzilla` Scheme。
3. 选择任意 iOS 17 及以上的 iPhone 模拟器。
4. 点击 Run。

命令行编译：

```bash
xcodebuild \
  -project Gapzilla.xcodeproj \
  -scheme Gapzilla \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 测试

`GapzillaTests` 当前覆盖核心间隔计算规则：

- 当前间隔和完整间隔由破例事件推导。
- 最长、平均和上一次间隔计算。
- 冲动事件不重置当前间隔。
- 历史记录中的间隔影响计算。

命令行测试：

```bash
xcodebuild \
  -project Gapzilla.xcodeproj \
  -scheme Gapzilla \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Debug 构建包含通过启动参数加载模拟数据和指定初始 Tab 的视觉验收入口。相关代码由 `#if DEBUG` 隔离，不进入 Release 构建。

## 开发约定

- 功能分支使用 `codex/` 前缀。
- 改动通过 Pull Request 合并到 `main`，不直接在 `main` 开发。
- 访问令牌和刷新令牌只保存在 Keychain，不写入源码或 UserDefaults。
- App 内间隔指标由事件事实计算，不由客户端伪造服务端派生数据。
