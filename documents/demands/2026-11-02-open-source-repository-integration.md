# 十二个开源仓库能力集成记录

日期：2026-11-02

## 范围与决策

把用户指定的六个仓库按锁定的上游提交合入 Dashboard，以宿主已有目录、主题、依赖解析和状态边界启动真实业务。用户已同意根工程采用 AGPL-3.0，并确认拥有 `hongguo` 与 `zhenguo-app` 源码复用权。用户未提供私有服务地址或凭据，因此不配置私有部署；NAS 能力仅提供公开源码、部署文件和用户自托管地址接入。

本次在原六个仓库集成的基础上，追加评估并整合六个直播/影视仓库；用户明确确认拥有 `ym_live_stream` 与 `vioclass` 的源码复用权。根工程已采用 AGPL-3.0。新来源的提交、许可和边界见 `documents/THIRD_PARTY_NOTICES.md`。

## 迁入与入口

| 来源 | 上游提交 | 业务迁移结果 |
| --- | --- | --- |
| [czgyz/hongguo](https://github.com/czgyz/hongguo) | `b0b56ce18f2d66cdde715439eeaea7472d461301` | 短剧工作台、Go 核心/FFI、Android 桥接、站源目录、播放器、本地下载、媒体库与红果原生弹幕接入视频/短剧目录；弹幕分页请求复用当前郑果播放会话。 |
| [wzgrx/PureLive](https://github.com/wzgrx/PureLive) | `9bd38aaf10e5bd7c8db24c27af82f433507c1917` | `packages/pure_live/` 中的主应用及直播能力包通过 `PureLiveEmbeddedPage` 接入直播目录，初始化路径与宿主主题独立适配。 |
| [xiaojiulala/dart_simple_live](https://github.com/xiaojiulala/dart_simple_live) | `da2a0fdc9d9ca376bd3365e80a4589699a7b93b4` | 完整保留移动版、TV 版、核心、控制台和第三方 Dart 包。直播入口在 Android 大屏使用 TV 专版，其余 IO 平台使用移动/桌面版；两者使用独立 Hive 目录和宿主主题。 |
| [kelstna/Kazumi-WebDAV](https://github.com/kelstna/Kazumi-WebDAV) | `d4c4ac4c50b0aad3479d97e68a9c21dbc1670941` | `KazumiEmbeddedPage` 接入动漫目录，保留 XPath 规则、WebDAV、字幕与音轨、ASS 字体、下载和历史；嵌入时跳过原桌面窗口生命周期。 |
| [youniube/zhenguo-app](https://github.com/youniube/zhenguo-app) | `2cfc49345180325c180d7de03154e6874013cae1` | 新版 Dart 业务与 Go 原生能力合并到既有短剧工作台，增加跨源搜索、片库导入导出、直播目录、播放与源诊断、传输和 YSP 模块；与 #1 的站源扩展合并，避免双应用和双状态库。 |
| [superxyline/purelive](https://github.com/superxyline/purelive) | `49de6d04bb90d1df1b1015ac342c7104a768062f` | NAS Node 服务、Web 管理端和 Compose/Docker 部署源码放入 `packages/purelive_nas/`；直播目录增加自托管服务地址、健康检查和管理端打开入口。 |

根 `pubspec.yaml` 统一解析六个业务入口及共享插件。为消解上游依赖版本冲突，保留了宿主锁定的 `flutter_foreground_task`、XML、SQLite、FFmpeg 与二维码依赖版本，并为 QuickJS、PureLive QR、SimpleLive 弹幕 fork 使用隔离包名/路径。AGPL、GPL 和上游版权文本记录在 `documents/THIRD_PARTY_NOTICES.md` 与对应源码目录。

## 服务与平台边界

- 私有登录服务、用户账号、WebDAV、直播订阅和 NAS 地址需要由用户自行配置；仓库没有可用的私有服务凭据，所以未配置或声称验收这些连接。
- SimpleLive TV 版只在 Android 大屏入口选择，宽度阈值为 850 逻辑像素。实际电视焦点、遥控器、播放与登录仍需设备验证。
- Kazumi 的规则站点和 WebDAV 媒体依赖用户提供地址；本地代码与独立 Hive 目录已接入，远端响应未验证。
- 短剧原生核心包含 Zhenguo YSP 与新增站源代码；各公开站源当前可用性受网络、接口和反爬影响，未做在线逐站验收。
- 红果原生弹幕已并入郑果播放会话：计划携带弹幕分集 ID，Go 核心按播放进度分页，播放器在用户未选通用弹幕 API 时自动回退到原生红果弹幕。请求链路已编译，真实服务响应和播放叠层未验收。
- NAS 服务和网页控制台已迁入，未部署或验证真实 NAS 实例。

## 本次追加的六个仓库

| 来源 | 上游提交 | 迁移结果与能力边界 |
| --- | --- | --- |
| [yanmo-null/ym_live_stream](https://github.com/yanmo-null/ym_live_stream) | `b901557bb60272309a434d9a49f05055c6243c73` | 审查该版本的直播源注册与房间播放链路后，发现未注册平台会使用 `MockLiveSource` 兜底。可运行的平台适配已由宿主内的 PureLive/SimpleLive 承接，因此没有把模拟结果接入正式直播目录，也没有重复搬入一套平行状态与 UI。 |
| [harley60504/vioclass](https://github.com/harley60504/vioclass) | `bff8d047a8fe0ba77b0504a18573b955bc542ace` | 直播目录增加 Twitch 回看/Clip 入口；以公开频道 GraphQL 查询回放和片段，VOD 通过 playback token 获取 HLS，Clip 使用签名播放地址，VOD 页按播放进度分页加载并显示评论。VioClass 的活动实时 DVR、登录、Drops、Whispers、账户通知和小窗状态未迁入；这些路径依赖不同的上游会话/平台状态，尚未完成宿主适配。 |
| [djshxjsh233/pure_live](https://github.com/djshxjsh233/pure_live) | `271f16794678b0b2dc9d8884818b9dc2628752fc` | 与已接入的 PureLive 平台层、播放器和 IPTV 能力重叠；保留宿主已有集成，不引入第三份直播应用或依赖树。 |
| [macro233/cuipi_tv](https://github.com/macro233/cuipi_tv) | `2a6f30b0d72bc84b924e83aef265b95e61511749` | 影视目录新增 TVBox/LibreTV 用户配置入口，解析 CMS JSON 站点，完成搜索、详情、线路/选集选择并交给统一播放器；IPTV 仓库 JSON `lives` 链接接入现有直播解析器；本地视频经系统文件选择器复制到应用媒体库，使用统一播放器播放。通用 XML/可执行 Spider、内置源清单、网络刮削和局域网文件服务未迁入。 |
| [FiveHair/pure_live](https://github.com/FiveHair/pure_live) | `e55f82c8d78d54cdd90aeab0db7dc6a7b10b9fc2` | 此 fork 的 HarmonyOS 支持依赖定制 OH Flutter SDK、OHOS 插件分支及 forked vendor 包，无法作为当前统一 Pub 依赖安全合并；没有复制会覆盖其他平台的依赖解析或本地绝对路径。宿主已有的 OHOS 打包脚本不代表该 fork 的平台适配已迁入或编译验证。 |
| [liuchuancong/pure_live_TV](https://github.com/liuchuancong/pure_live_TV) | `6a1186630b41df36d0ae4ed7bb996d6c1c745897` | TV 版的直播平台层与 IPTV 数据能力和现有 PureLive 包重叠，沿用已有直播宿主入口与电视 UI，不复制第二套根应用。遥控器输入和真机电视布局尚未在设备验证。 |

### 追加迁移的运行链

- TVBox：用户输入配置 URL → 仅接纳 TVBox type-1/LibreTV JSON 中符合协议的站点 → 选择可搜索 CMS → 搜索/详情请求（客户端可指定页码）→ 解析 `vod_play_from` 与 `vod_play_url` 选集 → 交给 Dashboard 统一播放器。相对 CMS、海报和播放地址按配置/API 地址解析；只播放 HTTP(S) 线路。
- IPTV：直接 `channels` JSON 可由现有 MyTV parser 解析；TVBox/LibreTV 配置中的 `lives`/`liveSources` URL 受 20 个源上限约束，响应继续走现有 M3U/TXT parser；HLS manifest 作为单个频道播放源。
- 本地媒体：文件选择 → 拷贝到应用支持目录 → 持久化应用内副本路径 → 检查文件存在 → 统一播放器打开。删除媒体库条目也会删除应用副本；源文件不被修改。
- Twitch：输入频道登录名 → Twitch GraphQL 获取公开 VOD/Clip 列表 → VOD 令牌/HLS 或 Clip 签名 URL → Dashboard 播放器；VOD 评论以 30 秒偏移加载并限制内存缓存。匿名接口不稳定，需联网实测；未配置账号凭据。

### 追加迁移的安全和许可边界

- 不引入 Cuipi 源码中预置的站点列表、私有服务地址、关闭 TLS 校验逻辑、伪造延迟结果或本机路径示例；入口要求用户输入 HTTP(S) 配置，配置中发现的直播 URL 也限定为 HTTP(S)。
- `ym_live_stream` 与 `vioclass` 根目录未提供项目级 LICENSE，用户已确认拥有这两仓库的复用授权。Cuipi 的 MIT 文本保存在 `documents/third_party/Cuipi-TV-MIT.txt`。其他来源的上游提交和 AGPL 文本保留情况见第三方声明表。
- `djshxjsh233/pure_live` 与 `pure_live_TV` 能力重叠；`FiveHair/pure_live` 的 OS 适配绑定当前不可统一的工具链，所以记录审查结果但未复制重复或不可构建的上游应用代码。能力重叠不等于上游所有页面细节已逐项迁入。

## 静态验证与未覆盖

- `flutter pub get`：完成，依赖解析成功；包含新增 FFmpeg 插件、SimpleLive TV 包和统一锁文件。
- `go -C native build -o /tmp/dashboard-native-core-danmaku-check ./bridge`：成功，编译了 FFI 桥接、短剧核心、YSP 及红果原生弹幕分页链路；没有运行 Go 测试。
- SimpleLive 宿主入口及 TV 嵌入文件的 `flutter analyze`：通过，无问题。
- 短剧核心文件的 `flutter analyze`：未发现 error 或 warning；32 条 info 级提示是上游风格提示。命令因 info 级提示返回非零状态。
- 未运行测试，未构建 APK、Web 或桌面包，未安装设备，也未启动 NAS、直播账号、WebDAV 或站源。

本记录界定源码迁入完成范围，不把静态编译或依赖解析表述为运行、设备和服务端验收。

### 本次追加的静态检查

- `dart format`：覆盖 TVBox 影视源、Twitch 回看/片段与本地媒体入口相关的 25 个 Dart 文件；格式化 1 个文件。
- `flutter analyze`：覆盖本次新增/修改的 10 个相关路径；通过，无问题。
- 未运行测试、未构建 APK/Web/桌面/Harmony 包、未安装设备、未访问真实 CMS/Twitch 服务、未完成视频或电视遥控 UI 验收。
