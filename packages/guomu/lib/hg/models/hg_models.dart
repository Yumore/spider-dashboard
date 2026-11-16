const String kHgImageOrigin = 'https://pic.drleao.cn';

String resolveHgMediaUrl(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return '';
  if (clean.startsWith('//')) return 'https:$clean';
  final lower = clean.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) return clean;
  if (clean.startsWith('/')) return '$kHgImageOrigin$clean';
  return '$kHgImageOrigin/$clean';
}

class HgAuthor {
  const HgAuthor({
    required this.id,
    required this.name,
    this.avatar = '',
    this.followers = 0,
    this.isFollowing = false,
  });

  final int id;
  final String name;
  final String avatar;
  final int followers;
  final bool isFollowing;

  factory HgAuthor.fromJson(Map<String, dynamic> json) {
    return HgAuthor(
      id: asInt(json['id'] ?? json['user_id']),
      name: asText(json['name'] ?? json['nickname'] ?? json['username']),
      avatar: asText(json['avatar']),
      followers: asInt(json['followers'] ?? json['follower_count']),
      isFollowing: asBool(json['is_following'] ?? json['following']),
    );
  }
}

class HgVideoCard {
  const HgVideoCard({
    required this.id,
    required this.title,
    required this.cover,
    this.description = '',
    this.tags = const [],
    this.score = 0,
    this.episodeCount = 0,
    this.totalEpisodes = 0,
    this.duration = '',
    this.hot = 0,
    this.likeCount = 0,
    this.collectCount = 0,
    this.commentCount = 0,
    this.isFinished = false,
    this.isOriginal = false,
    this.isHot = false,
    this.badge = '',
    this.newAt = 0,
    this.lastEpAt = 0,
    this.playAt = '',
    this.author,
    this.createdAt = '',
  });

  final int id;
  final String title;
  final String cover;
  final String description;
  final List<String> tags;
  final double score;
  final int episodeCount;
  final int totalEpisodes;
  final String duration;
  final int hot;
  final int likeCount;
  final int collectCount;
  final int commentCount;
  final bool isFinished;
  final bool isOriginal;
  final bool isHot;
  final String badge;
  final int newAt;
  final int lastEpAt;
  final String playAt;
  final HgAuthor? author;
  final String createdAt;

  bool get isNew {
    if (newAt > 0) return true;
    final created = DateTime.tryParse(createdAt.replaceFirst(' ', 'T'));
    return created != null &&
        DateTime.now().difference(created) < const Duration(days: 14);
  }

  List<String> get statusBadges {
    final labels = <String>[];
    if (isOriginal) labels.add('原创');
    if (isHot) {
      labels.add('热播');
    } else if (isNew) {
      labels.add('新片');
    }
    if (labels.isEmpty && badge.isNotEmpty) labels.add(badge);
    return labels.take(2).toList(growable: false);
  }

  String get episodeLabel {
    final total = totalEpisodes > 0 ? totalEpisodes : episodeCount;
    if (total <= 0) return '待更新';
    return isFinished ? '全 $total 集' : '更新至 $total 集';
  }

  factory HgVideoCard.fromJson(Map<String, dynamic> json) {
    final counts = asMap(json['counts']);
    final authorJson = asMap(json['author']);
    final badgeText = asText(json['badge']);
    return HgVideoCard(
      id: asInt(json['id'] ?? json['video_id']),
      title: asText(json['title']),
      cover: resolveHgMediaUrl(asText(json['cover'])),
      description: asText(json['description'] ?? json['desc']),
      tags: asStringList(json['tags']),
      score: asDouble(json['score']),
      episodeCount: asInt(json['episode_count']),
      totalEpisodes: asInt(json['total_episodes']),
      duration: asText(json['duration']),
      hot: asInt(json['hot'] ?? counts['hot']),
      likeCount: asInt(json['like_count'] ?? counts['like']),
      collectCount: asInt(json['collect_count'] ?? counts['collect']),
      commentCount: asInt(json['comment_count'] ?? counts['comment']),
      isFinished: asBool(json['is_finished']),
      isOriginal: asBool(json['is_original']) || badgeText.contains('原创'),
      isHot: asBool(json['is_hot']) || badgeText.contains('热播'),
      badge: badgeText,
      newAt: asInt(json['new_at']),
      lastEpAt: asInt(json['last_ep_at']),
      playAt: asText(json['play_at']),
      author: authorJson.isEmpty ? null : HgAuthor.fromJson(authorJson),
      createdAt: asText(json['created_at']),
    );
  }
}

class HgHomeBanner {
  const HgHomeBanner({
    required this.id,
    required this.videoId,
    required this.title,
    required this.image,
    required this.description,
    this.score = 0,
    this.episodeLabel = '',
    this.tags = const [],
  });

  final int id;
  final int videoId;
  final String title;
  final String image;
  final String description;
  final double score;
  final String episodeLabel;
  final List<String> tags;

  HgHomeBanner copyWith({
    String? title,
    String? image,
    String? description,
    double? score,
    String? episodeLabel,
    List<String>? tags,
  }) {
    return HgHomeBanner(
      id: id,
      videoId: videoId,
      title: title ?? this.title,
      image: image ?? this.image,
      description: description ?? this.description,
      score: score ?? this.score,
      episodeLabel: episodeLabel ?? this.episodeLabel,
      tags: tags ?? this.tags,
    );
  }

  factory HgHomeBanner.fromJson(Map<String, dynamic> json) {
    return HgHomeBanner(
      id: asInt(json['id']),
      videoId: asInt(json['video_id']),
      title: asText(json['title']),
      image: resolveHgMediaUrl(asText(json['image'] ?? json['cover'])),
      description: asText(json['desc'] ?? json['description']),
      score: asDouble(json['score']),
      episodeLabel: asText(json['episode'] ?? json['episode_label']),
      tags: asStringList(json['tags']),
    );
  }
}

class HgHomeCategoryRail {
  const HgHomeCategoryRail({
    required this.id,
    required this.name,
    required this.videos,
  });

  final int id;
  final String name;
  final List<HgVideoCard> videos;

  factory HgHomeCategoryRail.fromJson(Map<String, dynamic> json) {
    final videos = json['videos'];
    return HgHomeCategoryRail(
      id: asInt(json['cate_id']),
      name: asText(json['cate_name']),
      videos: videos is List
          ? videos
                .whereType<Map>()
                .map(
                  (item) =>
                      HgVideoCard.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((item) => item.id > 0)
                .toList(growable: false)
          : const [],
    );
  }
}

class HgHomeData {
  const HgHomeData({
    this.banners = const [],
    this.featured = const [],
    this.latest = const [],
    this.categoryRails = const [],
  });

  final List<HgHomeBanner> banners;
  final List<HgVideoCard> featured;
  final List<HgVideoCard> latest;
  final List<HgHomeCategoryRail> categoryRails;

  bool get isEmpty =>
      banners.isEmpty &&
      featured.isEmpty &&
      latest.isEmpty &&
      categoryRails.isEmpty;

  HgHomeData copyWith({
    List<HgHomeBanner>? banners,
    List<HgVideoCard>? featured,
    List<HgVideoCard>? latest,
    List<HgHomeCategoryRail>? categoryRails,
  }) {
    return HgHomeData(
      banners: banners ?? this.banners,
      featured: featured ?? this.featured,
      latest: latest ?? this.latest,
      categoryRails: categoryRails ?? this.categoryRails,
    );
  }

  factory HgHomeData.fromJson(Map<String, dynamic> json) {
    List<HgVideoCard> videos(dynamic value) => value is List
        ? value
              .whereType<Map>()
              .map(
                (item) => HgVideoCard.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.id > 0)
              .toList(growable: false)
        : const [];

    final banners = json['banners'];
    final rails = json['cate_rec'];
    return HgHomeData(
      banners: banners is List
          ? banners
                .whereType<Map>()
                .map(
                  (item) =>
                      HgHomeBanner.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((item) => item.videoId > 0)
                .toList(growable: false)
          : const [],
      featured: videos(json['featured']),
      latest: videos(json['latest']),
      categoryRails: rails is List
          ? rails
                .whereType<Map>()
                .map(
                  (item) => HgHomeCategoryRail.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.videos.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class HgVideoCategory {
  const HgVideoCategory({
    required this.id,
    required this.name,
    required this.route,
    required this.displayName,
    required this.intro,
  });

  final int id;
  final String name;
  final String route;
  final String displayName;
  final String intro;

  bool get isAvailable => route == 'ai-duanju' || route == 'ai-manju';

  factory HgVideoCategory.fromJson(Map<String, dynamic> json) {
    final route = asText(json['route']);
    final name = asText(json['name']);
    return HgVideoCategory(
      id: asInt(json['id']),
      name: name,
      route: route,
      displayName: hgVideoCategoryDisplayName(route, name),
      intro: asText(
        json['intro'] ?? json['description'],
        fallback: hgVideoCategoryIntro(route, name),
      ),
    );
  }
}

class HgTag {
  const HgTag({
    required this.id,
    required this.name,
    required this.slug,
    required this.categoryId,
    required this.categoryName,
    this.hotScore = 0,
    this.isHot = false,
    this.trend = 0,
  });

  final int id;
  final String name;
  final String slug;
  final int categoryId;
  final String categoryName;
  final int hotScore;
  final bool isHot;
  final int trend;

  String get intro => '精选$name题材短剧，持续收录高热度、最近更新与原创作品。';

  factory HgTag.fromJson(Map<String, dynamic> json) {
    return HgTag(
      id: asInt(json['id']),
      name: asText(json['name']),
      slug: asText(json['slug']),
      categoryId: asInt(json['cate_id']),
      categoryName: asText(json['cate_name']),
      hotScore: asInt(json['hot_score']),
      isHot: asBool(json['is_hot']),
      trend: asInt(json['trend']),
    );
  }
}

class HgTagGroup {
  const HgTagGroup({
    required this.id,
    required this.code,
    required this.name,
    required this.tags,
  });

  final int id;
  final String code;
  final String name;
  final List<HgTag> tags;

  String get intro => '按$name整理的短剧题材，共 ${tags.length} 个标签。';

  factory HgTagGroup.fromJson(Map<String, dynamic> json) {
    final tags = json['tags'];
    return HgTagGroup(
      id: asInt(json['id']),
      code: asText(json['code']),
      name: asText(json['name']),
      tags: tags is List
          ? tags
                .whereType<Map>()
                .map((item) => HgTag.fromJson(Map<String, dynamic>.from(item)))
                .where((item) => item.name.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class HgTagDirectory {
  const HgTagDirectory({this.groups = const []});

  final List<HgTagGroup> groups;

  factory HgTagDirectory.fromJson(Map<String, dynamic> json) {
    final groups = json['categories'];
    return HgTagDirectory(
      groups: groups is List
          ? groups
                .whereType<Map>()
                .map(
                  (item) =>
                      HgTagGroup.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((item) => item.tags.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

String hgVideoCategoryDisplayName(String route, String fallback) {
  return switch (route) {
    'ai-duanju' => 'AI成人短剧',
    'ai-manju' => 'AI成人漫剧',
    'ai-mogai' => 'AI魔改',
    'ai-huanlian' => 'AI换脸',
    _ => fallback,
  };
}

String hgVideoCategoryIntro(String route, String fallback) {
  return switch (route) {
    'ai-duanju' => '精选热播短剧，汇集独家原创、精选推荐与最新更新内容。',
    'ai-manju' => '精选漫剧与动态漫画，发现独家原创和持续更新的好作品。',
    'ai-mogai' => 'AI 魔改短剧分类当前未开放，请从可用分类浏览。',
    'ai-huanlian' => 'AI 换脸短剧分类当前未开放，请从可用分类浏览。',
    _ => '$fallback短剧分类，持续更新热门作品。',
  };
}

class HgEpisode {
  const HgEpisode({
    required this.number,
    required this.title,
    this.duration = 0,
    this.status = 0,
  });

  final int number;
  final String title;
  final int duration;
  final int status;

  factory HgEpisode.fromJson(Map<String, dynamic> json) {
    return HgEpisode(
      number: asInt(json['ep_num'] ?? json['ep'] ?? json['number']),
      title: asText(json['title']),
      duration: asInt(json['duration']),
      status: asInt(json['status']),
    );
  }
}

class HgVideoDetail {
  const HgVideoDetail({
    required this.id,
    required this.title,
    required this.cover,
    required this.description,
    required this.tags,
    required this.score,
    required this.episodes,
    required this.author,
    required this.isFinished,
    required this.isOriginal,
    this.episodeCount = 0,
    this.totalEpisodes = 0,
    this.likeCount = 0,
    this.collectCount = 0,
    this.commentCount = 0,
    this.hot = 0,
    this.isCollected = false,
    this.isHot = false,
    this.badge = '',
    this.newAt = 0,
    this.lastEpAt = 0,
    this.playAt = '',
    this.createdAt = '',
  });

  final int id;
  final String title;
  final String cover;
  final String description;
  final List<String> tags;
  final double score;
  final int episodeCount;
  final int totalEpisodes;
  final List<HgEpisode> episodes;
  final HgAuthor? author;
  final bool isFinished;
  final bool isOriginal;
  final int likeCount;
  final int collectCount;
  final int commentCount;
  final int hot;
  final bool isCollected;
  final bool isHot;
  final String badge;
  final int newAt;
  final int lastEpAt;
  final String playAt;
  final String createdAt;

  String get episodeLabel {
    final total = totalEpisodes > 0 ? totalEpisodes : episodeCount;
    if (total <= 0) return '待更新';
    return isFinished ? '全 $total 集' : '更新至 $total 集';
  }

  HgVideoCard toCard() => HgVideoCard(
    id: id,
    title: title,
    cover: cover,
    description: description,
    tags: tags,
    score: score,
    episodeCount: episodeCount,
    totalEpisodes: totalEpisodes,
    hot: hot,
    likeCount: likeCount,
    collectCount: collectCount,
    commentCount: commentCount,
    isFinished: isFinished,
    isOriginal: isOriginal,
    isHot: isHot,
    badge: badge,
    newAt: newAt,
    lastEpAt: lastEpAt,
    playAt: playAt,
    author: author,
    createdAt: createdAt,
  );

  factory HgVideoDetail.fromJson(Map<String, dynamic> json) {
    final counts = asMap(json['counts']);
    final interaction = asMap(json['interaction']);
    final authorJson = asMap(json['author']);
    final episodeJson = json['episodes'];
    final badgeText = asText(json['badge']);
    return HgVideoDetail(
      id: asInt(json['id']),
      title: asText(json['title']),
      cover: resolveHgMediaUrl(asText(json['cover'])),
      description: asText(json['description']),
      tags: asStringList(json['tags']),
      score: asDouble(json['score']),
      episodeCount: asInt(json['episode_count']),
      totalEpisodes: asInt(json['total_episodes']),
      episodes: episodeJson is List
          ? episodeJson
                .whereType<Map>()
                .map(
                  (item) => HgEpisode.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      author: authorJson.isEmpty ? null : HgAuthor.fromJson(authorJson),
      isFinished: asBool(json['is_finished']),
      isOriginal: asBool(json['is_original']) || badgeText.contains('原创'),
      likeCount: asInt(counts['like'] ?? json['like_count']),
      collectCount: asInt(counts['collect'] ?? json['collect_count']),
      commentCount: asInt(counts['comment'] ?? json['comment_count']),
      hot: asInt(counts['hot'] ?? json['hot']),
      isCollected: asBool(interaction['collected']),
      isHot: asBool(json['is_hot']) || badgeText.contains('热播'),
      badge: badgeText,
      newAt: asInt(json['new_at']),
      lastEpAt: asInt(json['last_ep_at']),
      playAt: asText(json['play_at']),
      createdAt: asText(json['created_at']),
    );
  }
}

class HgPagination {
  const HgPagination({
    this.page = 1,
    this.pages = 1,
    this.size = 20,
    this.total = 0,
  });

  final int page;
  final int pages;
  final int size;
  final int total;

  factory HgPagination.fromJson(Map<String, dynamic> json) {
    return HgPagination(
      page: asInt(json['page'], fallback: 1),
      pages: asInt(json['pages'], fallback: 1),
      size: asInt(json['size'], fallback: 20),
      total: asInt(json['total']),
    );
  }
}

class HgPage<T> {
  const HgPage({required this.items, required this.pagination});

  final List<T> items;
  final HgPagination pagination;

  factory HgPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final rawItems = json['items'];
    return HgPage<T>(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((item) => itemParser(Map<String, dynamic>.from(item)))
                .toList(growable: false)
          : const [],
      pagination: HgPagination.fromJson(asMap(json['pagination'])),
    );
  }
}

class HgRankItem {
  const HgRankItem({
    required this.rank,
    required this.videoId,
    required this.title,
    required this.cover,
    required this.tags,
    required this.score,
    required this.categoryName,
    required this.episodeCount,
    required this.isFinished,
    required this.metricLabel,
    required this.metricValue,
    this.likeCount = 0,
    this.collectCount = 0,
    this.commentCount = 0,
    this.playCount = 0,
  });

  final int rank;
  final int videoId;
  final String title;
  final String cover;
  final List<String> tags;
  final double score;
  final String categoryName;
  final int episodeCount;
  final bool isFinished;
  final String metricLabel;
  final int metricValue;
  final int likeCount;
  final int collectCount;
  final int commentCount;
  final int playCount;

  factory HgRankItem.fromJson(Map<String, dynamic> json) {
    final metrics = asMap(json['metrics']);
    return HgRankItem(
      rank: asInt(json['rank']),
      videoId: asInt(json['video_id'] ?? json['id']),
      title: asText(json['title']),
      cover: asText(json['cover']),
      tags: asStringList(json['tags']),
      score: asDouble(json['score']),
      categoryName: asText(json['cate_name']),
      episodeCount: asInt(json['episode_count']),
      isFinished: asBool(json['is_finished']),
      metricLabel: asText(json['metric_label'], fallback: '热度'),
      metricValue: asInt(json['metric_value']),
      likeCount: asInt(metrics['like']),
      collectCount: asInt(metrics['collect']),
      commentCount: asInt(metrics['comment']),
      playCount: asInt(metrics['play']),
    );
  }
}

class HgPlayInfo {
  const HgPlayInfo({
    required this.videoId,
    required this.episode,
    required this.videoUrl,
    this.duration = 0,
    this.title = '',
    this.hevcUrl = '',
    this.cdnAuthKey = '',
    this.cdnAuthValue = '',
    this.cdnApp = '',
  });

  final int videoId;
  final int episode;
  final String videoUrl;
  final int duration;
  final String title;
  final String hevcUrl;
  final String cdnAuthKey;
  final String cdnAuthValue;
  final String cdnApp;

  factory HgPlayInfo.fromJson(
    Map<String, dynamic> json, {
    required int videoId,
    required int episode,
  }) {
    final streams = asMap(json['streams']);
    final cdn = asMap(json['cdn']);
    return HgPlayInfo(
      videoId: asInt(json['id'], fallback: videoId),
      episode: asInt(json['ep_num'] ?? json['ep'], fallback: episode),
      videoUrl: asText(
        streams['main'] ?? streams['preview'] ?? json['video_url'],
      ),
      duration: asInt(json['duration']),
      title: asText(json['title']),
      hevcUrl: asText(streams['hevc'] ?? json['video_url_hevc']),
      cdnAuthKey: asText(cdn['authKey'] ?? cdn['auth_key']),
      cdnAuthValue: asText(cdn['authValue'] ?? cdn['auth_value']),
      cdnApp: asText(cdn['app']),
    );
  }
}

class HgComment {
  const HgComment({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.text,
    required this.time,
    this.avatar = '',
    this.avatarColor = '#FF6B3D',
    this.likeCount = 0,
    this.replyCount = 0,
    this.replyId = 0,
    this.replyToNickname = '',
    this.isPinned = false,
    this.isLiked = false,
    this.ipRegion = '',
    this.replies = const [],
  });

  final int id;
  final int userId;
  final String nickname;
  final String avatar;
  final String avatarColor;
  final String text;
  final String time;
  final int likeCount;
  final int replyCount;
  final int replyId;
  final String replyToNickname;
  final bool isPinned;
  final bool isLiked;
  final String ipRegion;
  final List<HgComment> replies;

  HgComment copyWith({
    int? likeCount,
    bool? isLiked,
    List<HgComment>? replies,
  }) => HgComment(
    id: id,
    userId: userId,
    nickname: nickname,
    text: text,
    time: time,
    avatar: avatar,
    avatarColor: avatarColor,
    likeCount: likeCount ?? this.likeCount,
    replyCount: replyCount,
    replyId: replyId,
    replyToNickname: replyToNickname,
    isPinned: isPinned,
    isLiked: isLiked ?? this.isLiked,
    ipRegion: ipRegion,
    replies: replies ?? this.replies,
  );

  factory HgComment.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['reply_list'];
    return HgComment(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      nickname: asText(json['nickname'], fallback: '匿名用户'),
      avatar: asText(json['avatar']),
      avatarColor: asText(json['avatar_color'], fallback: '#FF6B3D'),
      text: asText(json['text'] ?? json['content']),
      time: asText(json['time'] ?? json['created_at']),
      likeCount: asInt(json['like_count']),
      replyCount: asInt(json['reply_count']),
      replyId: asInt(json['reply_id']),
      replyToNickname: asText(json['reply_to_nickname']),
      isPinned: asBool(json['is_pinned']),
      isLiked: asBool(json['liked']),
      ipRegion: asText(json['ip_region']),
      replies: rawReplies is List
          ? rawReplies
                .whereType<Map>()
                .map(
                  (item) => HgComment.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class HgCommentPage {
  const HgCommentPage({required this.items, required this.pagination});

  final List<HgComment> items;
  final HgPagination pagination;

  factory HgCommentPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return HgCommentPage(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => HgComment.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      pagination: HgPagination.fromJson(asMap(json['pagination'])),
    );
  }
}

class HgUser {
  const HgUser({
    required this.id,
    required this.username,
    required this.nickname,
    this.avatar = '',
    this.avatarColor = '#FF6B3D',
    this.sign = '',
    this.counts = const {},
    this.favoriteVideoIds = const {},
    this.likedEpisodes = const {},
    this.isFollowing = false,
  });

  final int id;
  final String username;
  final String nickname;
  final String avatar;
  final String avatarColor;
  final String sign;
  final Map<String, int> counts;
  final Set<int> favoriteVideoIds;
  final Set<String> likedEpisodes;
  final bool isFollowing;

  factory HgUser.fromJson(Map<String, dynamic> json) {
    final rawCounts = asMap(json['counts']);
    final interactions = asMap(json['interactions']);
    final favorites = interactions['favorite_video_ids'];
    final likedEpisodes = interactions['like_video_episodes'];
    return HgUser(
      id: asInt(json['id']),
      username: asText(json['username']),
      nickname: asText(json['nickname'], fallback: asText(json['username'])),
      avatar: asText(json['avatar']),
      avatarColor: asText(json['avatar_color'], fallback: '#FF6B3D'),
      sign: asText(json['sign'] ?? json['desc']),
      counts: rawCounts.map((key, value) => MapEntry(key, asInt(value))),
      favoriteVideoIds: favorites is List
          ? favorites.map(asInt).where((id) => id > 0).toSet()
          : const {},
      likedEpisodes: likedEpisodes is List
          ? likedEpisodes
                .whereType<Map>()
                .map(
                  (item) => '${asInt(item['video_id'])}:${asInt(item['ep'])}',
                )
                .toSet()
          : const {},
      isFollowing: asBool(json['is_following'] ?? interactions['is_following']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nickname': nickname,
    'avatar': avatar,
    'avatar_color': avatarColor,
    'sign': sign,
    'is_following': isFollowing,
    'counts': counts,
    'interactions': {
      'favorite_video_ids': favoriteVideoIds.toList(),
      'like_video_episodes': likedEpisodes.map((value) {
        final parts = value.split(':');
        return {'video_id': asInt(parts.first), 'ep': asInt(parts.last)};
      }).toList(),
    },
  };
}

class HgUserStats {
  const HgUserStats({
    this.userId = 0,
    this.likeCount = 0,
    this.following = 0,
    this.followers = 0,
    this.videoCount = 0,
    this.postCount = 0,
  });

  final int userId;
  final int likeCount;
  final int following;
  final int followers;
  final int videoCount;
  final int postCount;

  factory HgUserStats.fromJson(Map<String, dynamic> json) {
    return HgUserStats(
      userId: asInt(json['user_id'] ?? json['id']),
      likeCount: asInt(json['like_count']),
      following: asInt(json['following']),
      followers: asInt(json['followers'] ?? json['follower_count']),
      videoCount: asInt(json['video_count']),
      postCount: asInt(json['post_count']),
    );
  }
}

class HgUserMessage {
  const HgUserMessage({
    required this.id,
    required this.title,
    required this.content,
    required this.time,
    this.kind = '',
    this.isRead = false,
    this.actionUrl = '',
  });

  final int id;
  final String title;
  final String content;
  final String time;
  final String kind;
  final bool isRead;
  final String actionUrl;

  HgUserMessage copyWith({bool? isRead}) => HgUserMessage(
    id: id,
    title: title,
    content: content,
    time: time,
    kind: kind,
    isRead: isRead ?? this.isRead,
    actionUrl: actionUrl,
  );

  factory HgUserMessage.fromJson(Map<String, dynamic> json) {
    return HgUserMessage(
      id: asInt(json['id'] ?? json['message_id']),
      title: asText(json['title'] ?? json['subject'], fallback: '系统消息'),
      content: asText(
        json['content'] ?? json['text'] ?? json['body'] ?? json['desc'],
      ),
      time: asText(json['created_at'] ?? json['time'] ?? json['publish_time']),
      kind: asText(json['type'] ?? json['kind']),
      isRead: asBool(json['is_read'] ?? json['read']),
      actionUrl: asText(json['url'] ?? json['action_url']),
    );
  }
}

class HgPost {
  const HgPost({
    required this.id,
    required this.title,
    required this.cover,
    this.description = '',
    this.tags = const [],
    this.hot = 0,
    this.createdAt = '',
  });

  final int id;
  final String title;
  final String cover;
  final String description;
  final List<String> tags;
  final int hot;
  final String createdAt;

  factory HgPost.fromJson(Map<String, dynamic> json) {
    return HgPost(
      id: asInt(json['id']),
      title: asText(json['title'], fallback: '黄果吃瓜'),
      cover: asText(json['cover']),
      description: asText(json['desc'] ?? json['description']),
      tags: asStringList(json['tags']),
      hot: asInt(json['hot']),
      createdAt: asText(json['publish_time'] ?? json['created_at']),
    );
  }
}

class HgPostDetail {
  const HgPostDetail({
    required this.post,
    this.content = '',
    this.videoUrl = '',
    this.author,
    this.likeCount = 0,
    this.collectCount = 0,
    this.commentCount = 0,
    this.hot = 0,
    this.isLiked = false,
    this.isCollected = false,
  });

  final HgPost post;
  final String content;
  final String videoUrl;
  final HgAuthor? author;
  final int likeCount;
  final int collectCount;
  final int commentCount;
  final int hot;
  final bool isLiked;
  final bool isCollected;

  factory HgPostDetail.fromJson(Map<String, dynamic> json) {
    final authorJson = asMap(json['author']);
    final counts = asMap(json['counts']);
    final interaction = asMap(json['interaction']);
    return HgPostDetail(
      post: HgPost.fromJson(json),
      content: asText(json['content']),
      videoUrl: asText(json['video_url']),
      author: authorJson.isEmpty ? null : HgAuthor.fromJson(authorJson),
      likeCount: asInt(counts['like']),
      collectCount: asInt(counts['collect']),
      commentCount: asInt(counts['comment']),
      hot: asInt(counts['hot'] ?? json['hot']),
      isLiked: asBool(interaction['liked']),
      isCollected: asBool(interaction['collected']),
    );
  }
}

class HgPostAdjacent {
  const HgPostAdjacent({this.previous, this.next});

  final HgPost? previous;
  final HgPost? next;

  factory HgPostAdjacent.fromJson(Map<String, dynamic> json) {
    final prev = asMap(json['prev']);
    final next = asMap(json['next']);
    return HgPostAdjacent(
      previous: prev.isEmpty ? null : HgPost.fromJson(prev),
      next: next.isEmpty ? null : HgPost.fromJson(next),
    );
  }
}

class HgTopic {
  const HgTopic({
    required this.id,
    required this.title,
    required this.slug,
    required this.cover,
    this.intro = '',
    this.videoCount = 0,
    this.faq = const [],
  });

  final int id;
  final String title;
  final String slug;
  final String cover;
  final String intro;
  final int videoCount;
  final List<HgTopicFaq> faq;

  factory HgTopic.fromJson(Map<String, dynamic> json) {
    final rawFaq = json['faq'];
    return HgTopic(
      id: asInt(json['id']),
      title: asText(json['title']),
      slug: asText(json['slug']),
      cover: asText(json['cover']),
      intro: asText(json['intro']),
      videoCount: asInt(json['video_count']),
      faq: rawFaq is List
          ? rawFaq
                .whereType<Map>()
                .map(
                  (item) =>
                      HgTopicFaq.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class HgTopicFaq {
  const HgTopicFaq({required this.question, required this.answer});

  final String question;
  final String answer;

  factory HgTopicFaq.fromJson(Map<String, dynamic> json) {
    return HgTopicFaq(question: asText(json['q']), answer: asText(json['a']));
  }
}

class HgTopicDetail {
  const HgTopicDetail({
    required this.topic,
    required this.videos,
    required this.related,
  });

  final HgTopic topic;
  final HgPage<HgVideoCard> videos;
  final List<HgTopic> related;

  factory HgTopicDetail.fromJson(Map<String, dynamic> json) {
    final rawRelated = json['related'];
    return HgTopicDetail(
      topic: HgTopic.fromJson(asMap(json['topic'])),
      videos: HgPage.fromJson(asMap(json['videos']), HgVideoCard.fromJson),
      related: rawRelated is List
          ? rawRelated
                .whereType<Map>()
                .map(
                  (item) => HgTopic.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class HgPostPlayback {
  const HgPostPlayback({this.videoUrls = const []});

  final List<String> videoUrls;

  factory HgPostPlayback.fromJson(Map<String, dynamic> json) {
    final rawVideos = json['videos'];
    return HgPostPlayback(
      videoUrls: rawVideos is List
          ? rawVideos
                .whereType<Map>()
                .map((item) => asText(item['url']))
                .where((url) => url.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class HgPlaylistItem {
  const HgPlaylistItem({
    required this.id,
    required this.title,
    required this.cover,
    this.videoId,
    this.lastEpisode = 0,
    this.totalEpisodes = 0,
    this.positionMs = 0,
    this.durationMs = 0,
    this.updatedAt = '',
  });

  final int id;
  final int? videoId;
  final String title;
  final String cover;
  final int lastEpisode;
  final int totalEpisodes;
  final int positionMs;
  final int durationMs;
  final String updatedAt;

  int get dramaId => videoId ?? id;

  double get progress {
    if (durationMs <= 0) return 0;
    return (positionMs / durationMs).clamp(0.0, 1.0).toDouble();
  }

  factory HgPlaylistItem.fromJson(Map<String, dynamic> json) {
    return HgPlaylistItem(
      id: asInt(json['id']),
      videoId: json['video_id'] == null ? null : asInt(json['video_id']),
      title: asText(json['title']),
      cover: asText(json['cover']),
      lastEpisode: asInt(json['last_ep']),
      totalEpisodes: asInt(json['total_ep']),
      positionMs: asInt(json['position_ms'] ?? json['position']),
      durationMs: asInt(json['duration_ms'] ?? json['duration']),
      updatedAt: asText(json['updated_at']),
    );
  }
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<String> asStringList(dynamic value) {
  if (value is List) {
    return value
        .map(asText)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[,，\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

int asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

String asText(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}
