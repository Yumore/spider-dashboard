# 第三方源码与许可记录

更新日期：2026-11-03

本工程根许可证为 GNU AGPL-3.0。表内提交号界定迁移的上游快照；仓库未提供项目级 LICENSE 的来源按用户明确确认的复用授权处理。上游许可证、版权声明和随源码提供的第三方许可证保留在对应目录。

| 来源 | 提交 | 上游许可 | 本地业务代码位置 | 接入方式与边界 |
| --- | --- | --- | --- | --- |
| [czgyz/hongguo](https://github.com/czgyz/hongguo) | `b0b56ce18f2d66cdde715439eeaea7472d461301` | 仓库未提供项目级 LICENSE；用户确认有权复用 | `lib/features/short_drama/hongguo/`, `native/`, `android/app/src/main/kotlin/com/yumore/dashboard/shortdrama/` | 短剧目录、详情、播放、下载、本地库、设备互联、视频增强、Android 桥接和红果原生弹幕；与郑果播放会话及弹幕叠层联动 |
| [wzgrx/PureLive](https://github.com/wzgrx/PureLive) | `9bd38aaf10e5bd7c8db24c27af82f433507c1917` | AGPL-3.0，见 `packages/pure_live/LICENSE` | `packages/pure_live/`, `lib/features/live/pure_live/` | 多平台直播、IPTV、弹幕、录制、多画面、后台播放、WebDAV、DLNA 及播放回退；从直播目录启动 |
| [xiaojiulala/dart_simple_live](https://github.com/xiaojiulala/dart_simple_live) | `da2a0fdc9d9ca376bd3365e80a4589699a7b93b4` | GPL-3.0，见 `packages/simple_live/LICENSE` 与 `packages/simple_live/simple_live_tv_app/LICENSE.upstream` | `packages/simple_live/`, `lib/features/live/simple_live_host_page.dart`, `lib/features/live/simple_live_host_page_state.dart` | 手机/桌面版与 Android TV 专版共存；Android 大屏按逻辑宽度选择 TV 页面；QuickJS 与弹幕 fork 各自保留许可证 |
| [kelstna/Kazumi-WebDAV](https://github.com/kelstna/Kazumi-WebDAV) | `d4c4ac4c50b0aad3479d97e68a9c21dbc1670941` | GPL-3.0-only，见 `packages/kazumi_webdav/LICENSE.upstream` | `packages/kazumi_webdav/`, `lib/features/anime/kazumi_entry.dart` | XPath 动漫源规则、WebDAV 媒体、字幕/音轨、ASS 字体、播放历史和下载；独立存储目录并使用宿主主题 |
| [youniube/zhenguo-app](https://github.com/youniube/zhenguo-app) | `2cfc49345180325c180d7de03154e6874013cae1` | 仓库未提供项目级 LICENSE；用户确认有权复用 | `lib/features/short_drama/hongguo/`, `native/core/`, `native/ysp/` | 新版短剧搜索、诊断、片库交换、直播、媒体传输与 YSP 代码合入短剧模块；保留 #1 迁移的青空次元、鬼片、韩小圈站源 |
| [superxyline/purelive](https://github.com/superxyline/purelive) | `49de6d04bb90d1df1b1015ac342c7104a768062f` | AGPL-3.0，见 `packages/purelive_nas/LICENSE.upstream` | `packages/purelive_nas/`, `lib/features/live/pure_live_nas/` | NAS Node 服务、Web 管理界面和部署文件；宿主允许设置用户自托管地址并检查 `/api/health`，不包含预置私有服务或访问令牌 |
| [yanmo-null/ym_live_stream](https://github.com/yanmo-null/ym_live_stream) | `b901557bb60272309a434d9a49f05055c6243c73` | 仓库未提供项目级 LICENSE；用户确认有权复用 | 未重复导入；直播适配能力由 `packages/pure_live/` 与 `packages/simple_live/` 承接 | 审查到的上游房间控制器在未注册站源时回退到 MockLiveSource；没有新增可用平台适配器，避免将模拟数据当成真实直播能力 |
| [harley60504/vioclass](https://github.com/harley60504/vioclass) | `bff8d047a8fe0ba77b0504a18573b955bc542ace` | 仓库未提供项目级 LICENSE；用户确认有权复用 | `lib/features/live/twitch_media/`, `lib/features/live/live_entry_catalog.dart` | 新增公开 Twitch VOD/Clip 列表、播放令牌与 VOD 评论回放入口；不包含登录态、Drops、Whispers、通知及实时直播 DVR |
| [djshxjsh233/pure_live](https://github.com/djshxjsh233/pure_live) | `271f16794678b0b2dc9d8884818b9dc2628752fc` | AGPL-3.0，上游 `LICENSE`；未重复复制代码 | 无新增独立目录；对应平台能力由 `packages/pure_live/` 提供 | 该仓库与现有 PureLive 直播聚合能力重叠；保留现有更新版本的集成实现，不再引入重复播放器、状态库和插件依赖 |
| [macro233/cuipi_tv](https://github.com/macro233/cuipi_tv) | `2a6f30b0d72bc84b924e83aef265b95e61511749` | MIT，完整文本见 `documents/third_party/Cuipi-TV-MIT.txt` | `lib/features/movie/tvbox/`, `lib/features/media/local_media_library_*.dart`, `lib/features/live/my_tv/` | 适配用户导入的 TVBox/LibreTV JSON 配置、CMS 搜索/详情/选集与统一播放器；将选择的本地视频复制到应用媒体库；复用 IPTV JSON 直播源解析。未迁入硬编码源、私有地址、跳过 TLS 校验、假测速、网络刮削服务与局域网服务端 |
| [FiveHair/pure_live](https://github.com/FiveHair/pure_live) | `e55f82c8d78d54cdd90aeab0db7dc6a7b10b9fc2` | AGPL-3.0，上游 `LICENSE`；未重复复制代码 | 无新增独立目录；现有平台封装与 `tool/package.dart` 维护跨平台入口 | 该分支重点是 HarmonyOS/鸿蒙适配，其补丁依赖定制 OH Flutter SDK、OHOS 插件分支及本地 vendor 依赖；未把这些工具链绑定的覆盖项带入统一依赖 |
| [liuchuancong/pure_live_TV](https://github.com/liuchuancong/pure_live_TV) | `6a1186630b41df36d0ae4ed7bb996d6c1c745897` | AGPL-3.0，上游 `LICENSE`；未重复复制代码 | `packages/pure_live/`, `lib/features/live/pure_live/` | TV 直播入口、遥控器导航与 IPTV 能力与现有 PureLive 集成重叠；沿用已有宿主入口和电视版 UI，不再嵌套第二套完整应用 |
| [looplj/reveric](https://github.com/looplj/reveric) | `c5df958d314e14804ba027acc51a2a46ab4e9557` | AGPL-3.0；上游 `NOTICES` 含 AGPLv3 Section 7 显著署名与项目链接附加条款 | `lib/features/short_drama/creator/` | 采用其小说/短剧/漫剧创作工作流作为业务参考，按宿主数据模型与 UI 重写本机项目库、分集剧本/分镜草稿和 OpenAI 兼容文本生成；创作页显示所需署名与上游链接。没有迁入桌面画布、3D 导演台或其 AI 插件/模型依赖。 |
| [flutter_js](https://pub.dev/packages/flutter_js) | `0.8.7`（`pubspec.lock`） | MIT，Copyright © 2019 Ábner Oliveira | `lib/features/reading/book/analyzer/js_runtime_native.dart` | 为 Legado `@js:` / `<js>` 书源规则提供原生同步 JS 执行；本地适配仅开放 `result`、`src`、`baseUrl` 与 `jsLib` 上下文，运行默认关闭并由用户选择启用。 |

纯 Flutter 依赖 `ffmpeg_kit_flutter_new_min_gpl` 由 `pubspec.lock` 锁定；其 GPL 许可随 Pub 包发布。WebDAV、直播账号、站源服务和 NAS 地址均由用户提供。项目未迁入任何源仓库中的签名密钥或服务端凭据。

对本表中标记“未重复复制代码”的仓库，仅记录版本、许可和能力重叠，不表示其每项独有上游行为均已逐项实现或验收。用户授权的未声明许可来源限于本表注明的两个仓库。

`leetomlee123/book`（[Apache-2.0](https://github.com/leetomlee123/book)，检查 `master` 分支于 2026-11-03）作为 Flutter Legado JS 书源实现参考；未复制其应用源码或本地补丁。宿主独立接入上表 MIT `flutter_js` 依赖。
