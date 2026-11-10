# 修复主题模式保存错误导致的页面文字可读性问题

日期：2026-11-11

## 问题

应用切换夜间模式时，`AppTheme.changeThemeMode` 错把模式索引写入 `themeColor`；`ConfigHelper.setThemeMode` 又固定写入 `0`，未保存传入值。用户选择浅色模式后，重启应用会退回“跟随系统”。设备使用深色系统主题时，部分固定浅色背景页面会继承浅色文字，造成白底白字、难以阅读。

## 修改

- 夜间模式选择改为写入 `themeMode` 配置项。
- 夜间模式配置保存调用实际写入传入的模式索引。
- 主题色仍由独立的 `themeColor` 配置维护，切换夜间模式不会改动主题色。

用户若此前已选浅色模式，需要在修复后的应用中重新选择一次“关闭”，之后该选择会正确保留。

## 验证

- 通过设备截图确认当前连接设备运行的是旧包名 `com.nsapp.dashboard`，不是本工程当前包名 `com.yumore.spiderx.flutter`，因此无法据此重现当前源码页面的白字问题。
- 查看设备日志，未发现可定位文字颜色问题的 Flutter 异常；该缺陷来自主题配置写入逻辑。
- 本次静态代码复核确认模式索引只写入 `themeMode`，主题色索引仍走 `setAppTheme`。
- 设备属性 `ro.eink.model` 为空，且连接设备型号为 Pixel 6 Pro，按普通 Android Release 变体处理。
- 按 `--max-workers=6 --no-parallel` 执行 Android Release 构建；短剧 Go 原生库已编译，但 APK 未生成。Flutter 编译被已集成模块与当前依赖 API 不兼容阻断，涉及 QuickJS hooks、文件选择器、桌面托盘/屏幕捕获、`win32`、`media_kit` 和 Dio 等；需要单独完成这些模块的兼容迁移后才能产出 APK。
- 当前设备安装的仍是旧包名 `com.nsapp.dashboard`，本次没有可供安装验收的新 APK，也未完成当前源码的设备 UI 验证。
- 用户决定先交付主题文字可读性修复，暂缓兼容迁移和 APK 构建。
