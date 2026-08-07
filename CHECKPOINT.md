# Gapzilla iOS 开发检查点

更新时间：2026-07-15

## 当前任务

基于 Gapzilla 手机版 Web 的视觉调性和既有业务功能，设计并实现原生 iOS App。

这不是 WebView，也不是对网页逐像素照抄。iOS 端需要使用原生信息架构、导航、组件、手势、触感反馈和安全存储，并针对手机一屏的信息密度重新设计。

## Git 状态

- 仓库：`/Users/jiangshen/www/gapzilla-ios`
- 当前分支：`codex/native-ios-foundation`
- `main` 基础提交：`4a5397c chore: bootstrap repository`
- iOS 功能提交：`1b8762e feat: build native Gapzilla iOS app`
- `main` 和 `codex/native-ios-foundation` 均已推送到 GitHub。
- Pull Request：`https://github.com/jiangsyz/gapzilla-ios/pull/1`
- 后续必须通过 Pull Request 合并到 `main`，不要直接在 `main` 开发或合并。

## 已完成内容

### 工程基础

- 已建立原生 SwiftUI Xcode 工程。
- 最低系统版本为 iOS 17。
- Bundle Identifier 为 `online.quietbase.gapzilla`。
- 已建立共享 Scheme：`Gapzilla`。
- 没有引入第三方 UI 框架。
- 已使用既有 Gapzilla 品牌标志生成应用内标志和 1024px App Icon。

### 产品结构

- 未登录产品首页。
- 登录和注册。
- 首次创建目标。
- 三个原生主 Tab：今天、历史、分析。
- 当前目标切换与目标管理。
- 原生事件记录 Sheet。
- 账号与语言设置。

### 今天

- 当前间隔和正向反馈。
- 快捷记录破例。
- 快捷记录冲动；录入时不判断是否控制住。
- 最长间隔、平均间隔和近 7 天冲动概览。
- 最近事件。

### 历史

- 月历和月份切换。
- 破例与冲动使用不同标记。
- 事件记录列表。
- 最新破例显示“已坚持 X 天”。
- 已完成间隔显示“X 天”。
- 冲动不显示“间隔继续”等无意义重复文案。

### 分析

- 当前、最长和平均间隔。
- 上一次间隔。
- 间隔趋势图。
- 近 7 个已结束自然日中，根据“同日有冲动且无破例”动态派生的被控制住的冲动。
- 最近 6 个月冲动柱状图。

### 数据与会话

- 生产 API：`https://api.gapzilla.quietbase.online`。
- 已接入登录、注册、刷新、退出、用户、目标和事件接口。
- Access Token 和 Refresh Token 使用 Keychain 保存。
- 当前目标使用 UserDefaults 保存。
- API JSON 使用 snake case 编解码策略。
- 遇到 401 时尝试刷新会话并重试。
- 间隔指标由事件事实在客户端计算。

## 已完成验证

Xcode 能正确识别工程、Target 和 Scheme。

以下模拟器编译命令已成功执行，退出码为 0：

```bash
xcodebuild -quiet \
  -project Gapzilla.xcodeproj \
  -scheme Gapzilla \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/gapzilla-derived-check \
  CODE_SIGNING_ALLOWED=NO \
  build
```

编译过程中曾出现 `GoalManagerSheet` 类型检查耗时错误，已通过拆分 SwiftUI 子视图修复；修复后的完整编译已通过。

2026-07-15 已再次完成以下验证：

- Debug 模拟器构建通过。
- Release 模拟器构建通过。
- Debug 模拟数据只存在于 `#if DEBUG` 条件代码中。
- `GapzillaTests` 的 3 个核心规则测试全部通过。
- Token 写入已改为等待 API Client 完成更新，避免登录后首次请求的竞态。

已在 `Gapzilla-Preview` 模拟器实际检查：

- 未登录产品首页。
- 登录 Sheet。
- 今天页。
- 历史页和月历。
- 分析页和趋势图。
- 记录事件 Sheet。

根据真实截图完成的修正：

- 中文模式下的月份和日期本地化。
- 导航标题由纯黑调整为品牌深灰紫。
- 日历中的破例、冲动图例和日期底色区分。
- Debug 示例数据调整为逐步增长的间隔趋势。
- 应用内标志改为与 Web 一致的 Gapzilla 品牌标志。

## 当前收尾位置

功能实现、视觉验收、App Icon、Debug/Release 构建和核心规则测试均已完成。

已创建专用模拟器：

- 名称：`Gapzilla-Preview`
- 设备：iPhone 17 Pro
- UDID：`F5F2A12A-5C0D-4CAF-BA3C-C465918FB146`
- 最近验收时状态：Booted

第一次使用原有模拟器截图时，被模拟器自身的 Apple 账号验证弹窗遮挡。随后使用干净的 `Gapzilla-Preview` 专用模拟器完成了全部页面验收。

当前代码已提交并推送，Pull Request #1 已创建，等待审阅和合并。

## 下次继续顺序

1. 读取本文件和仓库 `README.md`。
2. 打开 Pull Request #1，检查自动化状态和审阅意见。
3. 如有审阅意见，在 `codex/native-ios-foundation` 上修改并继续推送。
4. 审阅通过后，由用户确认是否合并到 `main`。

## 关联本地项目

- Web 前端：`/Users/jiangshen/www/gapzilla-web-frontend`
- Go 后端：`/Users/jiangshen/go/src/gapzilla-backend`
- 设计与服务器文档：`/Users/jiangshen/www/gapzilla-design`

本次暂停前，本地服务状态如下：

- Web：`http://localhost:5173/`
- 后端：`http://localhost:8888/`
- MySQL 容器：`local-mysql`，端口 `3306`

关机后这些进程会停止。下次需要时重新启动，并实际检查端口，不要只根据本文件假设仍在运行。

操作 Go 后端前，必须重新遵循用户的 Go 项目必读规范；仅启动 iOS 工程不需要执行 Go 命令。

## 已确认的产品与协作要求

- iOS 使用 Web 的视觉调性和功能事实，但必须为 App 重新设计。
- 手机与桌面都需要控制首屏信息密度，不能任由内容自然堆叠。
- 深黑色会显得脏，主文字使用偏灰紫的深色体系。
- 当前间隔和坚持天数是重要正反馈，应直接展示。
- 不展示“间隔继续”等需要用户阅读但没有新增信息的文案。
- 修改后需要在真实浏览器或模拟器中自行检查。
- 用户说暂停时必须立即停止。
- 代码合并使用 Pull Request 或 Merge Request。
- 不在源码、文档或提交中记录账号密码、Token、SSH 私钥等秘密。
