# 开源内容工程能力集成记录（2026-11-04）

日期：2026-11-04

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

## 2026-11-03 GitHub Flutter 工程检索与创作工作流接入

本次重新检查小说源、漫画源、动漫源、影视/视频源、短剧源、直播源和 AI 漫剧的 Flutter 项目。现有 Dashboard 已有 Legado/EasyMyGo/ESO 书源、U17/画涯/Haka/PicaComic/Pixez 漫画、Kazumi/AnimeOne/TakoPlay/AnimeTrace 动漫、TVBox/CMS 与统一播放器、红果/真果鉴短剧以及 PureLive/SimpleLive/MyTV/Twitch 等直播入口。这些运行链已有对应代码和统一入口，本次不再复制第二套同类客户端。

| 候选 | 许可证/运行前提 | 处理结果 |
| --- | --- | --- |
| [kodjodevf/mangayomi](https://github.com/kodjodevf/mangayomi) 与 [m2k3a/mangayomi-extensions](https://github.com/m2k3a/mangayomi-extensions) | Apache-2.0；主应用使用独立 Dart/JS 扩展桥、原生与 Rust 组件，扩展仓库提供的是依赖 Mangayomi 合约执行的代码 | 现有项目已经有对应内容模块，但没有 Mangayomi 扩展运行时。本次不把目录 JSON 当作可工作的书源/播放源，也不复制另一整套 UI 与运行时依赖。 |
| [looplj/reveric](https://github.com/looplj/reveric)，上游快照 `c5df958d314e14804ba027acc51a2a46ab4e9557` | AGPL-3.0，另有署名和显著链接附加条款；当前主分支要求更新的 Flutter/Dart 工具链，并带桌面专用编辑器、原生媒体 fork 和其他大体量依赖 | 将小说/短剧项目、分集剧本和 AI 漫剧分镜提示工作流接入宿主新建的本地创作工作台；不嵌入整套 Reveric 应用，也不引入其依赖树。工作流按 Dashboard 数据模型和统一 UI 独立实现，入口保留上游要求的署名及项目链接。 |
| [xuanyustudio/LocalMiniDrama](https://github.com/xuanyustudio/LocalMiniDrama) | 仓库描述为 JavaScript 本地桌面工具，不是 Flutter 工程 | 不符合 Flutter 工程范围，没有迁入。 |
| [HankLiy/guoapp](https://github.com/HankLiy/guoapp) | Flutter 短剧客户端；仓库未发现明确的项目许可证 | 没有用户对该仓库的单独复用授权，未复制源码。短剧浏览和 AI 漫剧内容由既有红果/真果鉴模块提供。 |
| [ch6vip/fqapp](https://github.com/ch6vip/fqapp) | Flutter UI 加进程内 Rust 核心；未确认与本工程兼容的许可与源站复用边界 | 未迁入其不透明源站实现；继续由宿主已有内容源、阅读器和播放器承接。 |

### 创作工作台接入结果

- “小说”目录和“短剧”目录均新增创作工作台入口，使用全局内容页样式。
- 支持创建小说、短剧和 AI 漫剧项目；设定、人物、分卷/分集大纲、正文/剧本、分镜提示均按项目分别保存在本机，支持自动保存、项目删除和跨次启动加载。
- AI 草稿通过用户填写的 OpenAI 兼容地址、模型名和 API Key 请求 `chat/completions`；支持根据当前作品及其他已填写区块为当前阶段生成内容。Key 只保存在当前页面内存，不写入项目数据或偏好设置。
- 模型服务地址与账号由用户提供；未配置密钥时 AI 请求不可用，但本机项目编辑和保存可独立工作。没有内置云端、后端、模型账号或源内容。
- 按 Reveric 仓库 AGPLv3 Section 7 附加条款，在创作页展示 “Based on Reveric by looplj.” 和上游项目链接；项目细节和上游许可记录见第三方声明表。
- 当前是本机文字创作、剧本和画面提示草稿流；没有迁入 Reveric 的无限画布、3D 导演台、图像/视频模型供应商适配、智能体编排和多轨成片导出能力。没有模型凭据，未验证远端 AI 响应。

### 本次检查边界

- 未新增 Flutter/Pub 依赖；复用工程现有 `http`、`sqflite` 和 `url_launcher`。
- 未导入 Mangayomi 动态脚本，也未声称其扩展可直接由 Legado、TVBox 或宿主播放器执行。
- 新增工作台目录、数据模型与入口的 `dart format` 和目标路径 `flutter analyze` 已通过；没有运行测试、构建包或真实 UI/设备验证，也没有模型凭据，因此远端 AI 响应尚未验收。

## 2026-11-03 Legado JavaScript 书源执行接入

本次 GitHub 检索另外核对了小说、漫画、动漫和可扩展源工程：

| 仓库 | 许可与依赖边界 | 处理 |
| --- | --- | --- |
| [leetomlee123/book](https://github.com/leetomlee123/book) | Apache-2.0；Flutter Legado 规则子集带 JavaScript 源规则，依赖 `flutter_js` 本地补丁和 Rust 可选分页；Android 优先，没有维护 iOS 工程 | 参考其 Legado JS 书源能力，未复制上游应用源码；在现有 Legado 规则管线内接入 MIT `flutter_js` 0.8.7，尽量保留宿主已有解析、阅读 UI 和数据模型。 |
| [DreamMangaReader](https://github.com/TypeDreamMoon/DreamMangaReader) | MIT；源运行时接收其 `prepare*/handle*` 协议，仓库本身不内置内容源 | 保留为另一种脚本源协议候选；宿主目前没有该协议的适配和漫画/动漫/小说统一脚本路由，本次不把其脚本误报成已支持来源。 |
| [Mangayomi](https://github.com/kodjodevf/mangayomi) 与 [Mangayomi Extensions](https://github.com/m2k3a/mangayomi-extensions) | Apache-2.0；扩展依赖 Mangayomi 特定 JS/Dart API，主应用同时含 Rust 与扩展执行实现 | 没有把扩展清单导入为可运行书源；需要另行实现完整的扩展合约适配后才能接入。 |
| [Kai-Shelf](https://github.com/abduznik/kai-shelf) | MIT；漫画浏览依赖用户部署并配置 Suwayomi、Komga 或 Kavita 服务 | 依赖自托管私有服务，按当前迁移范围跳过。 |
| [DirectorAI](https://github.com/StevenAi01/director_ai) | 仓库页面未显示项目级许可证；文档示例要求外部智谱/Google 模型凭据和图像/视频服务 | 未复制代码或接入模型服务；现有创作工作台仍可离线保存脚本和分镜提示。 |

### Legado 规则执行行为

- 在书源管理增加 JavaScript 执行开关；默认关闭，打开前展示本机执行与潜在网络访问/阻塞风险说明，并把用户选择保存在偏好设置。
- 本机原生运行时向 Legado 规则提供 `result`、`src`、`baseUrl` 和当前书源的 `jsLib`；把返回的字符串或 JSON 值交回现有 CSS/JSON/章节规则流水线，书架、搜索、目录和正文继续使用原有业务实现。
- Web 使用条件导入降级桩；鸿蒙平台也关闭运行时，因为当前没有该插件的鸿蒙实现证据。Android、iOS 与 Windows/Linux/macOS 使用 `flutter_js` 原生运行时。
- 这不是完整的 Legado Java API 或任意扩展兼容层：`java.*`、自定义 request/network 注入、WebView 交互和其他 Android 专有书源接口仍未实现。同步 JS 若包含不终止循环，可能阻塞当前执行线程；只对可信书源手动启用。
- 依赖版本锁定为 `flutter_js 0.8.7`，MIT 记录已加到 `documents/THIRD_PARTY_NOTICES.md`。`leetomlee123/book` 的应用源码没有复制，其 `master` 分支仅作为能力检索参考。

### 本次验证边界

- `flutter pub get` 成功；`dart format` 已格式化本次 Dart 改动。5 个目标 Dart 文件的 `flutter analyze` 无问题；另行分析 `lib/main.dart` 时只报告 5 条原有 info，均位于本次未修改行。
- 未运行测试、APK/Web/桌面构建或设备验证；没有在线逐个执行第三方书源。此项验证只证明代码静态检查结果，不证明具体站点脚本、平台打包或 UI 运行行为。

## 2026-11-04 Flutter 阅读、媒体与创作工程逐项检索

按用户列出的 13 类顺序检索 GitHub，并对照当前 Dashboard 入口和依赖。检索到的现有同类模块不重复嵌套完整客户端；新集成仅补本工程缺少的 EPUB/PDF 应用内阅读、教材本机导入和批注链路。

| 序号 | 类别与 Flutter 候选 | 处理结果 |
| --- | --- | --- |
| 1 | 小说： [leetomlee123/book](https://github.com/leetomlee123/book) | 当前已具备 Legado/EasyMyGo/ESO 源与书架；上一轮已将 MIT `flutter_js` 接入 Legado JS 规则，搜索、目录、正文继续由现有解析管线处理，本轮不重复复制另一套小说应用。 |
| 2 | 漫画： [Mangayomi](https://github.com/kodjodevf/mangayomi)、[PicaComic](https://github.com/wgh136/PicaComic) | Dashboard 已有 Pica、Pixez、Haka 等来源和阅读入口；Mangayomi 扩展依赖其专有脚本合约，本轮没有把扩展清单伪装成可运行漫画源。 |
| 3 | 动漫： [Mangayomi](https://github.com/kodjodevf/mangayomi) | Dashboard 已有 Kazumi XPath 源及 AnimeOne、TakoPlay、AnimeTrace 入口；Mangayomi 平台层与扩展运行时不兼容，本轮不另嵌整套播放器。 |
| 4 | 视频： [media-kit](https://github.com/media-kit/media-kit)、[pro_video_player](https://github.com/vitormf/pro_video_player) | 当前播放器已使用 media-kit 并服务短视频、影视和本地媒体；第二个候选是重叠的播放器后端，本轮不叠加新的原生播放器依赖。 |
| 5 | 影视： [Freeplix](https://github.com/iamnabink/Freeplix) | 候选主要提供 TMDB 目录和用户自配的播放地址；Dashboard 已有 TVBox/CMS、影片详情/选集和统一播放器，未重复迁入另一套目录 UI。 |
| 6 | 短剧： [Hongguo](https://github.com/czgyz/hongguo)、[Zhenguo](https://github.com/youniube/zhenguo-app) | 两个来源的短剧目录、站源、播放和本机工作流已在当前短剧模块；本轮没有再复制平行客户端。 |
| 7 | 直播： [OpenIPTV](https://github.com/DR-89/openiptv) | 候选要求用户导入 M3U/Xtream 源；现有 PureLive、SimpleLive 和 MyTV 已覆盖相同播放/源配置入口，本轮不增加重复 IPTV 客户端。 |
| 8 | AI 漫剧： [Toonflow](https://github.com/HBAI-Ltd/Toonflow-app) | 仓库提供无限画布、脚本、资产和模型工作流，但项目树以 Bun/桌面及本地服务为主，未找到可确认的 Flutter 模块；现有 Reveric 业务参考已接入小说/短剧/漫剧文本与分镜创作，本轮不把非 Flutter 应用嵌入宿主。 |
| 9 | AI 工作台： [BeatDesign](https://github.com/BeatAPI/BeatDesign) | 候选以 pnpm、浏览器编辑器和 MCP 工具组成，不是 Flutter 工程；本地创作工作台已有项目、剧本、分镜提示及 OpenAI 兼容文本生成入口，本轮未复制非 Flutter 工具链。 |
| 10 | 数字人： [Mynah](https://github.com/honwee/mynah) | 上游由 Go 实时服务、Python avatar worker 和 WebRTC 客户端组成，运行需要 GPU/模型 worker 或远端端点；不属于 Flutter 客户端，也没有可验收服务配置，本轮跳过。 |
| 11 | 书籍： [Papyrus client](https://github.com/PapyrusReader/client) | 完整客户端的账号、同步和目录 relay 需要其 FastAPI/数据库服务；只选用独立阅读器子仓库，宿主自行保存本机书目、进度和笔记。 |
| 12 | 电子书： [Papyrus Reader](https://github.com/PapyrusReader/reader) | 将 `development` 提交 `fa667ae96c64e2d1d80c06e83d326265673abc75` 固定为根 `papyrus_reader` Git 依赖，实际接入 EPUB 2/3 与 PDF 阅读、目录、排版设置和定位恢复；Feedbooks 下载 EPUB 也改为应用内阅读。 |
| 13 | 教材： [Swipe Book](https://github.com/sajanpoudel/Swipebook) | 上游以 Firebase 保存课程与资源，教材文件来源也不适合直接打包复用；本工程新增本机 EPUB/PDF 导入，支持教材目录、进度、选区高亮和笔记，不预置受版权约束的教材内容。 |

### 本机书籍与教材接入

- 阅读入口新增“电子书与教材”；通过文件选择器复制 EPUB/PDF 到应用文档目录，书目元数据和每本书的 locator、排版偏好、高亮与笔记保存在本机偏好库。阅读状态的并发更新串行写入，避免定位、排版或批注同时保存时互相覆盖。
- Papyrus Reader 通过 pinned Git dependency 使用；服务地址、账号和云端同步均不需要。删除本机书籍时同步清理文件副本和阅读会话；Feedbooks 下载记录仍由其原有下载库管理，只共享阅读器会话能力。
- 依赖将根工程 `html` 解析版本从 `0.15.7` 锁定到 Papyrus Reader 兼容的 `0.15.6`；完整依赖图由 `pubspec.lock` 管理。上游的 AGPL-3.0 与本工程 AGPL-3.0 一致，Papyrus 包内的 EPUB worker 第三方声明随依赖保留。
- 当前格式范围是 EPUB 2/3 reflowable 与 PDF；固定版式 EPUB、MOBI/AZW3 和 DRM 文件不在阅读器支持范围。阅读器载入完整文件字节，超大文件会增加内存占用。

### 本轮验证边界

- `flutter pub get` 成功，Papyrus Reader 锁定到上述 commit；本次新增阅读库、阅读器、Feedbooks 入口和阅读目录的目标路径 `flutter analyze` 无问题。全工程分析仍列出 1585 条既有诊断（主要是旧源码的 lint、弃用和警告）；本次目标路径单独分析无诊断。
- 未运行测试、APK/Web/桌面构建或设备 UI 验收；没有在实际 EPUB/PDF 文件上确认渲染、翻页、Web Worker CSP 或不同平台文件选择行为。当前阅读入口按本机文件系统能力显示，Web 不提供本机书架入口。
