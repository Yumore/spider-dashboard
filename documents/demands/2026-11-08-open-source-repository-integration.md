# 开源内容工程能力集成记录（2026-11-08）

日期：2026-11-08

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

## 2026-11-05 GitHub Flutter 工程逐项复查与 TXT 阅读接入

按用户列出的 13 类顺序重新搜索 GitHub，并对照当前工程入口、依赖及平台限制。1–7 类继续使用现有业务模块；复查未发现需要再嵌套一套完整应用的候选。新补充的是本地 TXT 小说阅读，合并到已有本地书架。

| 序号 | 类别与复查候选 | 决策 |
| --- | --- | --- |
| 1 | 小说：[Dream Manga Reader](https://github.com/TypeDreamMoon/DreamMangaReader)、[leetomlee123/book](https://github.com/leetomlee123/book) | Dream Manga Reader（MIT，检索提交 `a162c2c7634957be67beb64d8040e03e7cfba44b`）提供本地 TXT/EPUB 与多类脚本源；其 `prepare*/handle*` 源协议与 Dashboard Legado 规则合约不同，且仓库不自带源清单或站点。保留当前 Legado 书源能力，本轮迁入其本地 TXT 小说使用场景，不伪报脚本源已兼容。 |
| 2 | 漫画：[Dream Manga Reader](https://github.com/TypeDreamMoon/DreamMangaReader)、[flutter_manga_reader](https://github.com/TesteurManiak/flutter_manga_reader)、[Open Manga Reader](https://github.com/Skyleaft/Open-Manga-Reader) | 现有 Pica/Pixez/Haka 等阅读入口继续使用；flutter_manga_reader 标注仍在开发且多数列出的源未支持，Open Manga Reader 需要 ASP.NET SignalR、Firebase 与 MangaScrapper 服务，不作为可离线迁入的独立业务模块。 |
| 3 | 动漫：[Aimi](https://github.com/brokiem/aimi)、[Dream Manga Reader](https://github.com/TypeDreamMoon/DreamMangaReader) | Dashboard 已有 Kazumi、AnimeOne、TakoPlay、AnimeTrace 等运行链；Aimi 的多源播放与媒体 kit 能力重合，未再引入第二套动漫客户端。 |
| 4 | 视频：[pro_video_player](https://github.com/vitormf/pro_video_player) | 该候选是原生播放器插件；宿主已有 media-kit 播放影视、短视频和本地媒体，本轮不增加重复后端。 |
| 5 | 影视：[Freeplix](https://github.com/iamnabink/Freeplix) | TMDB 发现目录和用户自配播放地址与现有 TVBox/CMS 详情、选集及统一播放器功能重合。 |
| 6 | 短剧：[Hongguo](https://github.com/czgyz/hongguo)、[Zhenguo](https://github.com/youniube/zhenguo-app) | 现有短剧模块已包含两来源的目录、站源、播放器和创作工作流；未重复嵌套客户端。 |
| 7 | 直播：[OpenIPTV](https://github.com/DR-89/openiptv) | 该 GPL-3.0 客户端支持 M3U/Xtream、EPG、录制和投屏；Dashboard 已有 PureLive、SimpleLive、MyTV 与 XMLTV EPG。Xtream 需要用户自有服务地址和凭据，当前未配置；整体客户端的 TV UI/播放器会重复现有模块，因此未整体迁入，本轮未声称新增 Xtream API 支持。 |
| 8 | AI 漫剧：[Toonflow](https://github.com/HBAI-Ltd/Toonflow-app)、[Dream Manga Reader](https://github.com/TypeDreamMoon/DreamMangaReader) | Toonflow 项目以 Bun/桌面和本地服务为主；宿主已有小说/短剧/漫剧剧本和分镜提示工作流，未复制非 Flutter 服务。 |
| 9 | AI 工作台：[PocketLLM](https://github.com/PocketLLM/PocketLLM)、[BeatDesign](https://github.com/BeatAPI/BeatDesign) | PocketLLM 的本机模型运行与模型下载会明显增加体积和平台运行时依赖；BeatDesign 是 Web/MCP 工具链。Dashboard 已有 OpenAI 兼容创作接口，用户可配置自有兼容服务，本轮不增加重复工作台。 |
| 10 | 数字人：[Mynah](https://github.com/honwee/mynah) | 其实时数字人依赖自托管 Go/Python 服务、WebRTC 与模型 worker（默认 FlashHead 配置要求 NVIDIA GPU）；不是可独立接入的 Flutter 功能页，没有可用部署配置，未迁入。 |
| 11 | 书籍：[Papyrus client](https://github.com/PapyrusReader/client) | 完整客户端的同步和书目 relay 依赖服务；继续使用已集成的独立 Papyrus Reader 库和宿主本地书架。 |
| 12 | 电子书：[Papyrus Reader](https://github.com/PapyrusReader/reader)、[Flureadium](https://github.com/mulev/flureadium) | Papyrus Reader 继续提供宿主 EPUB/PDF 阅读。Flureadium LGPL-3.0 可补 CBZ、DiViNa 和有声书，但其 Android 要求 minSdk 24、FlutterFragmentActivity 与更高 SDK，而宿主 minSdk 23；本轮不改变现有设备兼容基线。 |
| 13 | 教材：[Local Educational App](https://github.com/trey-rosius/Local-Educational-App)、[Swipe Book](https://github.com/sajanpoudel/Swipebook) | 本地教育候选没有找到明确项目许可证，且依赖本机模型运行时；Swipe Book 依赖 Firebase 课程服务。沿用本机 EPUB/PDF 教材库并新增 TXT 本地阅读，不引入未授权代码或云端服务。 |

### 新增的本地 TXT 阅读链路

- 本地书架文件选择新增 TXT；选中的文件复制到应用私有书库并持久化为书目条目。UTF-8（含 BOM）、UTF-16 LE/BE（含 BOM）和 GBK 文本通过同一文本阅读页打开，滚动位置按书目 ID 保存在本机；删除书目时同时清理阅读进度。
- 解码复用工程已有 `enough_convert` 的 GBK 编码器；阅读页与 EPUB/PDF 共享书架、文件存储和统一入口。此项是根据 Dream Manga Reader 的 TXT 本地阅读业务场景实现的宿主适配，没有复制其脚本源引擎或应用代码。
- 第三方记录已更新：Dream Manga Reader `main` 提交 `a162c2c7634957be67beb64d8040e03e7cfba44b`、MIT；OpenIPTV 标注为 GPL-3.0；Flureadium 标注为 LGPL-3.0。未迁入后两者源码。

### 本轮验证边界

- `dart format`：本次涉及文件格式化完成；`flutter analyze lib/features/reading/local_library lib/features/reading/reading_entry_catalog.dart`：通过，无问题。未运行测试、构建或设备 UI 验证。不同 TXT 编码的真实样本、超大文本占用和阅读位置恢复仍需运行时验收；TXT 当前整本读入内存。

## 2026-11-08 GitHub 28 类 Flutter 工程检索与能力补齐

按用户给出的 1–28 顺序搜索候选、核对许可证和运行依赖，再与现有目录、服务层和入口逐项对照。当前工程已覆盖大部分内容源、播放器、阅读器、直播、采集和创作业务；本次补入本地 PDF 文本层解析/合并，以及 AI 创作区块的受控工具工作流。候选仓库没有被直接挂成路径链接或第二个应用。

| 序号 | 类别 | 搜索候选 | 决策与业务结果 |
| --- | --- | --- | --- |
| 1 | 小说 | [DreamMangaReader](https://github.com/TypeDreamMoon/DreamMangaReader)、[leetomlee123/book](https://github.com/leetomlee123/book) | Legado 源、ESO/EasyMyGo 与本机 TXT/EPUB/PDF 书架已有真实搜索、目录、阅读和进度链路；沿用现有模块，不重复导入另一个小说客户端或不兼容的脚本源协议。 |
| 2 | 漫画 | [Mangayomi](https://github.com/kodjodevf/mangayomi)、[JHenTai](https://github.com/jiangtian616/JHenTai) | PicaComic、Pixez、Haka 等来源和阅读器已接入。Mangayomi 使用自己的扩展运行时；JHenTai 是另一套成人漫画客户端，都不作为可直接装入的源清单或第二套 UI。 |
| 3 | 动漫 | [Mangayomi](https://github.com/kodjodevf/mangayomi)、[DreamMangaReader](https://github.com/TypeDreamMoon/DreamMangaReader) | Kazumi XPath、AnimeOne、TakoPlay、AnimeTrace 已有独立来源链路；不导入需要额外解释器的脚本而冒称兼容。 |
| 4 | 视频 | [media-kit](https://github.com/media-kit/media-kit)、[pro_video_player](https://github.com/vitormf/pro_video_player) | 当前统一播放器已依赖 media-kit 并用于影视、短视频和本机媒体；不叠加功能重复的第二个播放器后端。 |
| 5 | 影视 | [Cuipi TV](https://github.com/macro233/cuipi_tv)、[Freeplix](https://github.com/iamnabink/Freeplix) | 已有 TVBox/CMS 配置搜索、详情、选集和统一播放；不重复迁入另一套电影目录与播放 UI。 |
| 6 | 短剧 | [Hongguo](https://github.com/czgyz/hongguo)、[Zhenguo](https://github.com/youniube/zhenguo-app) | 两来源的短剧目录、站源、播放器和本机项目工作流已在短剧模块运行；本次不再复制客户端。 |
| 7 | 直播 | [PureLive](https://github.com/wzgrx/PureLive)、[OpenIPTV](https://github.com/DR-89/openiptv) | PureLive、SimpleLive、MyTV 与 Twitch VOD/Clip 已接入；OpenIPTV 的播放和源导入与现有直播聚合重复，不再引入新的客户端和依赖树。 |
| 8 | AI 漫剧 | [Toonflow](https://github.com/HBAI-Ltd/Toonflow-app)、[Reveric](https://github.com/looplj/reveric) | 本机创作模块已有设定、剧本和分镜提示；Toonflow 是另有 Bun/TypeScript 后端、桌面与可选模型服务的应用，不作为 Flutter 客户端复制。 |
| 9 | AI 工作台 | [GidarAI](https://github.com/kasifdeveloper/GidarAI) | GidarAI 是多模型 Flutter 聊天客户端；宿主当前提供小说/短剧创作 AI 能力。本次为这些创作区块加入显式工具调用工作流，不另嵌一套通用聊天 UI。 |
| 10 | 数字人 | [Mynah](https://github.com/honwee/mynah) | 候选是 Go/WebRTC 服务和 Python 模型 worker，需要自托管端点及 GPU/模型环境；没有本机服务配置，不迁入该服务栈。 |
| 11 | 书籍 | [Papyrus Reader](https://github.com/PapyrusReader/reader)、[Papyrus client](https://github.com/PapyrusReader/client) | 独立阅读器与本机书架已集成；需要云同步/书目 relay 的客户端后端不在本次接入范围。 |
| 12 | 电子书 | [Velora](https://github.com/blueokanna/velora)、[Papyrus Reader](https://github.com/PapyrusReader/reader) | EPUB/PDF 与 TXT 本机阅读已可用。Velora 的 MOBI/AZW3/CBZ 等扩展格式使用 Rust 核心与 FRB，在线来源也与现有源规则重叠；不改变平台构建链。 |
| 13 | 教材 | [Swipe Book](https://github.com/sajanpoudel/Swipebook)、[Papyrus Reader](https://github.com/PapyrusReader/reader) | 本机 EPUB/PDF/TXT 书架提供目录、阅读进度、批注/笔记；不引入依赖 Firebase 的课程后端，也不随包提供教材内容。 |
| 14 | PDF 解析 | [ben-milanko/dart-pdf](https://github.com/ben-milanko/dart-pdf) | 使用 `pdf_document` 与 `pdf_graphics` 15.0.0 接入本地文件解析，读取页数、标题、作者和已有文本层；文本预览上限 300 页或 50,000 字，不含 OCR。 |
| 15 | PDF 合成 | [ben-milanko/dart-pdf](https://github.com/ben-milanko/dart-pdf) | 使用同套纯 Dart `PdfMerger` 按用户排序合并 2–20 个文件，并通过系统文件选择器保存新 PDF；不上传文件，也不依赖平台通道。 |
| 16 | 升级 | [upgrader](https://github.com/larryaasen/upgrader)、[app_updater](https://github.com/mantreshkhurana/app_updater) | 设置页已有版本检查和平台自更新入口；不叠加以应用商店提示为主的新插件。各平台实际更新来源仍由现有平台实现和发布地址决定。 |
| 17 | 博客 | [rsspresso](https://github.com/iakdis/rsspresso) | ESO RSS 与知乎文章/资讯入口已覆盖订阅和文章阅读。rsspresso 是 GPL-3.0 Flutter RSS 客户端，能力重叠，不复制整套订阅 UI。 |
| 18 | 爬虫 | [scrapy.dart](https://github.com/sachaarbonel/scrapy.dart) | 工程现有爬虫工作台已具备任务、请求、页面规则和结果导出链路；Scrapy.dart 框架不替代宿主数据模型，不再引入第二套采集抽象。 |
| 19 | Agent 模版 | [flutter-ai-coding-starter-kit](https://github.com/SleyAI/flutter-ai-coding-starter-kit) | 这是面向开发流程的 Flutter 模板，不是用户产品功能；不把其项目脚手架和代理角色复制进运行时。 |
| 20 | fiction/novel | [DreamMangaReader](https://github.com/TypeDreamMoon/DreamMangaReader)、[Velora](https://github.com/blueokanna/velora) | 对应小说搜索、阅读和本机书架已覆盖；无需另建 fiction 子应用。 |
| 21 | manga/anime | [Mangayomi](https://github.com/kodjodevf/mangayomi)、[JHenTai](https://github.com/jiangtian616/JHenTai) | 对应漫画、动漫源和播放已由 Pica/Pixez/Haka、Kazumi 等入口承担；不复制需各自运行时的扩展。 |
| 22 | comic/cimoc | [manga-source-index](https://github.com/kuiti/manga-source-index) | 搜索到的是跨阅读器来源索引数据（其中包含 CIMOC 记录），不是 Flutter 客户端或 CIMOC 解析执行器；不把索引 JSON 当作可直接运行的漫画源。 |
| 23 | video | [media-kit](https://github.com/media-kit/media-kit) | 统一媒体播放能力已集成并复用于影视、短视频、本地视频和直播；无新增播放器依赖。 |
| 24 | drama | [Hongguo](https://github.com/czgyz/hongguo)、[Zhenguo](https://github.com/youniube/zhenguo-app) | 短剧来源、详情、播放与创作工作台已在对应业务域；没有重复客户端。 |
| 25 | live | [PureLive](https://github.com/wzgrx/PureLive)、[dart_simple_live](https://github.com/xiaojiulala/dart_simple_live) | 多平台直播、IPTV、电视专版、回看与统一入口已接入；未增加重叠直播源聚合器。 |
| 26 | spider/crawler | [scrapy.dart](https://github.com/sachaarbonel/scrapy.dart) | 复用宿主爬虫任务、请求和结果解析，不接入重复框架或预置采集源。 |
| 27 | agent/workflow | [dart_agent_core](https://github.com/memex-lab/dart_agent_core) 2.1.9 | MIT Agent 运行时因依赖图冲突暂未加入：它经 `aws_common` 要求 `http2` 2.x，现有 PureLive 网络依赖需要 `http2` 3.x；不强制覆盖直播依赖。本次在宿主 AI 创作客户端中实现只开放 `read_project_context` 与 `submit_draft` 的有限 OpenAI 工具循环，最多 5 轮，提交结果由页面保存。 |
| 28 | NSFW/Hentai | [JHenTai](https://github.com/jiangtian616/JHenTai)、[PicaComic](https://github.com/wgh136/PicaComic) | PicaComic 来源层已含 E-Hentai、Hitomi、nhentai 与 JM 等服务；JHenTai 同为 Apache-2.0 Flutter 客户端并与现有来源/阅读 UI 重叠，不再导入第二套客户端或打包源内容。 |

### 新增能力与边界

- “PDF 解析与合并”从阅读目录打开。PDF 内容经纯 Dart 解析器在本机读取；原生平台使用 `compute` 工作隔离，Web 上 `compute` 可能退化到页面事件循环，因此 Web 限单文件 24 MB、合并总量 48 MB；原生平台限制单文件 100 MB、合并总量 200 MB，最多合并 20 个文件。实际内存占用取决于 PDF 结构与设备；超限输入会拒绝处理。
- 文本提取只提取 PDF 已有的文本层。扫描页没有 OCR；损坏、加密或当前解析器不支持的文件会显示失败。合并结果保持用户选择的顺序；不声称所有表单、签名、文档级附件或 PDF 厂商扩展均可无损兼容。
- AI 创作每个区块旁增加 Agent 工作流入口。模型在收到项目标题、类型和现有区块内容后，先调用 `read_project_context` 再提交 `submit_draft`；Agent 不开放任意网络、文件系统或其他应用工具，模型请求仍通过用户配置的服务地址发送。服务端须支持 OpenAI 兼容的 function/tool calling。草稿随后由现有本机项目保存逻辑写入，用户可在编辑器检查和修改；API Key 仍只存当前页面运行内存，不写入项目或偏好。
- `dart_agent_core` 因 `http2` 主版本冲突未加入依赖，也未复制其源代码。本地 Agent 流程使用已有 `http` 和 OpenAI 兼容接口，并限制工具名、轮数、上下文和草稿长度；不包括计划、子 Agent、持久化记忆、MCP 或多供应商抽象。
- 新依赖为 `pdf_document 15.0.0`、`pdf_graphics 15.0.0`，传递依赖 `pdf_cos 15.0.0`；均 Apache-2.0，并已锁入 `pubspec.lock`。仓库 SDK 的完整应用没有迁入。上游来源、包版本、许可证和本地适配位置见 `documents/THIRD_PARTY_NOTICES.md`。

### 本次复核

- `flutter pub get`：成功，锁定上述 PDF 依赖；没有覆盖 PureLive 的 `http2` 版本。
- `dart format`：覆盖本次新建/修改的 8 个 Dart 文件，格式化完成。
- `flutter analyze`：覆盖 PDF 工具页、阅读入口与 AI 创作文件，通过，无问题。
- 未运行测试、构建 APK/Web/桌面包、启动实际 PDF 样例、接入模型服务或设备 UI 验收；不得据此认定 PDF 样本兼容、AI 服务可达或界面已在设备验证。
