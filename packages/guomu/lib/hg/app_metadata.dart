abstract final class HgAppMetadata {
  static const String version = '1.4.6';
  static const String buildNumber = '11';
  static const String versionLabel = 'v1.4.6 (11)';
  static const String releaseTitle = '原生手感与主题一致性版';
  static const List<String> releaseNotes = [
    '列表与按钮增加轻微按压叠色反馈，去掉水波纹。',
    'Android 预测性返回与系统转场；iOS 列表回弹与 Android 边缘指示恢复合理默认值。',
    'Tab 与操作图标切换仅淡入，去掉弹簧缩放。',
    '骨架加载色跟随深浅主题；半屏输入随键盘即时抬升。',
  ];

  static const List<HgReleaseRecord> releaseHistory = [
    HgReleaseRecord(
      version: 'v1.4.6',
      buildNumber: '11',
      date: '2026-11-18',
      title: '原生手感与主题一致性版',
      features: [],
      improvements: [
        '全站可点区域增加轻微按压叠色，交互更接近原生客户端。',
        'Android 使用 PredictiveBack 页面转场并启用 OnBackInvokedCallback。',
        '按平台区分滚动物理与边缘拉伸指示，iOS 列表恢复回弹。',
        '底部 Tab、帖子与播放页图标状态切换仅淡入，移除 easeOutBack 缩放。',
        '骨架屏渐变取自 ColorScheme，深色模式不再显示浅色占位块。',
        '移除全局 textScaler 上限；评论回复文本改用 Text.rich 继承缩放。',
        '半屏表单随 viewInsets 即时 padding，不再叠加 180ms AnimatedPadding。',
      ],
      fixes: [],
    ),
    HgReleaseRecord(
      version: 'v1.4.5',
      buildNumber: '10',
      date: '2026-11-16',
      title: '播放器与 iOS 后台能力版',
      features: [
        'iOS 灵动岛与锁屏实时活动补齐主 App 能力声明，并在播放开始时立即创建。',
        'iOS 接入系统 Now Playing 锁屏媒体信息和播放控制。',
        '启动时自动请求通知权限，后台音频与后台 App 刷新能力同步启用。',
        'iPhone 播放器支持左右横屏，退出播放器后自动恢复竖屏。',
      ],
      improvements: [
        '视频进度条改用 Flutter 原生 Slider，触控区域扩大并支持连续跟手拖动。',
        '进度条整体上移并放到选集栏上方，避免贴近系统手势区导致难以滑动。',
        '横屏视频竖屏显示时使用纯黑背景，不再以封面图填充画面。',
        '全屏观看按钮移动到画面上方，并扩大按钮点击区域。',
      ],
      fixes: [
        '修复评论区下箭头与半屏拖动条重合的问题。',
        '修复松手后等待视频 seek 完成才更新界面造成的卡顿感。',
        '修复 Live Activity 封面过大可能导致活动创建失败的问题。',
      ],
    ),
    HgReleaseRecord(
      version: 'v1.4.4',
      buildNumber: '9',
      date: '2026-11-16',
      title: '原生面板与全局打磨版',
      features: [
        '半屏面板统一复用 Flutter 原生模态底部面板、系统拖动条和中大档吸附。',
        '新增统一确认面板，清空缓存、退出登录等操作不再使用居中系统弹窗。',
        '数据源、更新说明、消息详情和设置选择等长内容统一使用面板滚动控制器。',
      ],
      improvements: [
        '登录、编辑资料、评论、选集、分享和更新说明的面板高度改由容器统一控制。',
        '面板内文字、按钮和错误提示改为跟随浅色与深色主题。',
        '评论输入、数据源地址输入和帖子评论适配键盘与底部安全区。',
      ],
      fixes: [
        '修复半屏顶部横条无法可靠拖动、内外层滚动冲突和高度跳动的问题。',
        '修复我的页面消息角标和快捷入口角标背景透明、部分环境不可见的问题。',
      ],
    ),
    HgReleaseRecord(
      version: 'v1.4.3',
      buildNumber: '8',
      date: '2026-11-16',
      title: '启动稳定性修复版',
      features: [
        'Android 增加品牌化原生启动画面，并优先渲染 Flutter 首帧。',
        '通知与后台任务改为界面显示后异步初始化，失败时自动降级。',
        'iOS Widget 补齐标准 Bundle 元数据，IPA 构建时强制检查主 App 与扩展。',
      ],
      improvements: [
        '通知图标加入 R8 资源保留清单，避免 Release 构建裁剪后导致插件初始化异常。',
        'Android 启动链路增加超时与错误降级，不再因可选插件阻塞进入首页。',
      ],
      fixes: [
        '修复 Sideloadly 安装时提示 Widget 缺少非空 CFBundleName 的问题。',
        '修复 Android Release 版本启动后停留在黑屏的问题。',
      ],
    ),
    HgReleaseRecord(
      version: 'v1.4.2',
      buildNumber: '7',
      date: '2026-11-16',
      title: '离线缓存与原生体验版',
      features: [
        '新增整部短剧缓存、下载任务页面、下载进度与实时网速。',
        '未完结短剧支持记录追更，更新后可通知并可选自动缓存新集。',
        'iOS 支持灵动岛和锁屏实时活动，显示封面、剧名、观看集数与进度。',
        '设置页新增追更通知、自动缓存和后台检查开关。',
      ],
      improvements: [
        '剧场、吃瓜和榜单支持左右滑动切换 Tab，切换时保留页面状态。',
        '半屏弹窗统一为可拖拽的原生式面板，支持关闭、半屏和全屏吸附。',
        '首页轮播改为连续无限滚动，并从真实短剧详情补全横幅标题。',
        '全面修复深色模式的页面、卡片和弹窗背景；下拉刷新改为原生风格。',
        '移除 Android 预测式返回的半透明过渡，统一为整页推入。',
        'GitHub Pages 改为纯界面预览，进入播放页直接阻止视频加载。',
      ],
      fixes: [
        '修复“我的”页登录按钮文字被 padding 挤压的问题。',
        '修复轮播最后一张跳回第一张、以及空标题显示为“精选短剧”的问题。',
        '修复下载内容重启应用后无法恢复、离线找不到本地播放列表的问题。',
        '修复切换邻近剧集时默认不自动播放的问题。',
        '修复设置页更新记录与功能入口表达不清晰的问题。',
        '修复播放地址缓存过期导致的 Source error，重试时自动获取新地址。',
      ],
    ),
    HgReleaseRecord(
      version: 'v1.4.1',
      buildNumber: '6',
      date: '2026-11-16',
      title: '在线更新与稳定版',
      features: [
        '设置页和启动阶段通过 GitHub Releases 检查在线更新。',
        'GitHub Pages 在线预览、APK 和未签名 IPA 自动构建与发布。',
      ],
      improvements: [
        'GitHub 数据源清单增加 Contents API、jsDelivr 和 Raw 多级回退。',
        '产品 README 与关于果幕页面改为面向中文黄果短剧用户的正式产品说明。',
      ],
      fixes: [
        '修复 iOS 安装包结构错误，导致部分签名工具提示未找到 App 包的问题。',
        '修复 GitHub 源清单在部分网络环境不可达时没有备用镜像的问题。',
      ],
    ),
    HgReleaseRecord(
      version: 'v1.4.0',
      buildNumber: '5',
      date: '2026-11-16',
      title: '原生体验与续播版',
      features: [
        '追剧、历史、喜欢、详情、榜单和专题统一读取本机播放进度，可继续上次集数与播放位置。',
        '播放器新增可拖动进度条，支持点击定位、跟手预览时间和松手跳转。',
        '长按播放器两侧可临时二倍速，上滑锁定，锁定后继续长按两侧下滑解除。',
        '详情页右上角三点菜单新增分享、刷新详情、从头播放和清除本剧记录。',
        '设置页新增独立更新记录页，按版本展示新增功能、体验优化和问题修复。',
        '设置页与启动阶段通过 GitHub Releases 检查在线更新，并按平台提供 APK、IPA 或 Release 入口。',
      ],
      improvements: [
        '剧场页改为顶部全部、短剧、漫剧切换，缩短页面并移除重复说明区。',
        '榜单页改为重点作品大卡与完整排名列表，专题页改为精选大图与双列卡片。',
        '标签页改为分类切换和紧凑标签网格，标签详情页同步精简。',
        '个人页右上角固定为设置入口，消息入口保留在设置左侧，头像抽屉移除重复设置项。',
        '首页、剧场、榜单、专题、标签等页面无缓存时统一展示微光骨架动画。',
      ],
      fixes: [
        '修复追剧入口和历史入口显示的播放集数不一致。',
        '修复续播只记录集数、不记录具体播放位置的问题。',
        '修复详情页播放按钮总是从第 1 集开始的问题。',
      ],
    ),
    HgReleaseRecord(
      version: 'v1.3.0',
      buildNumber: '4',
      date: '',
      title: '第三方客户端与内容中心版',
      features: [
        '首页按精选推荐、最近上新、热播短剧、专题推荐重新组织，并支持查看更多。',
        '支持多个自定义数据源与本机网络自动发现官方最新可用线路。',
        '观看历史改为本机保存，不再依赖官方历史接口。',
      ],
      improvements: [
        '搜索、短剧、漫剧、题材标签、榜单和专题数据在启动阶段预加载。',
        '设置页支持外观选择、缓存管理与数据源管理。',
        '吃瓜页面选中图标和首页快捷卡改为自绘图形，减少不同环境的字体差异。',
      ],
      fixes: ['修复个人页重复入口与观看历史不同步问题。', '修复部分环境中图标字体缺失导致选中状态不可见。'],
    ),
  ];
}

class HgReleaseRecord {
  const HgReleaseRecord({
    required this.version,
    required this.buildNumber,
    required this.date,
    required this.title,
    required this.features,
    required this.improvements,
    required this.fixes,
  });

  final String version;
  final String buildNumber;
  final String date;
  final String title;
  final List<String> features;
  final List<String> improvements;
  final List<String> fixes;

  String get versionLabel => '$version ($buildNumber)';
}
