import 'dart:convert';
import 'dart:typed_data';

import 'package:guomu/hg/api/hg_api.dart';
import 'package:guomu/hg/auth/app_controllers.dart';
import 'package:guomu/hg/models/hg_download_models.dart';
import 'package:guomu/hg/models/hg_models.dart';
import 'package:guomu/hg/utils/hg_local_history.dart';
import 'package:guomu/hg/utils/hg_update_service.dart';
import 'package:guomu/hg/widgets/hg_components.dart';
import 'package:guomu/hg/widgets/secure_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('HG models', () {
    test('parses video cards and pagination', () {
      final page = HgPage.fromJson({
        'items': [
          {
            'id': 10769,
            'title': '测试短剧',
            'cover': 'https://example.test/cover',
            'description': '一段简介',
            'tags': ['都市', '逆袭'],
            'score': 9.6,
            'episode_count': 12,
            'total_episodes': 24,
            'hot': 30163724,
            'like_count': 27285,
            'collect_count': 11892,
            'comment_count': 341,
            'is_finished': false,
            'is_original': 1,
            'author': {'id': 1, 'name': '黄果官方', 'avatar': ''},
          },
        ],
        'pagination': {'page': 1, 'pages': 2, 'size': 20, 'total': 21},
      }, HgVideoCard.fromJson);

      expect(page.items, hasLength(1));
      expect(page.items.single.title, '测试短剧');
      expect(page.items.single.tags, ['都市', '逆袭']);
      expect(page.items.single.isOriginal, isTrue);
      expect(page.items.single.author?.name, '黄果官方');
      expect(page.pagination.pages, 2);
    });

    test('builds original and new double badges from real card fields', () {
      final card = HgVideoCard.fromJson({
        'id': 13781,
        'title': '蜜桃臀',
        'cover': '/upload_01/example.jpeg',
        'is_original': 1,
        'new_at': 1794800896,
        'episode_count': 1,
        'is_finished': false,
      });

      expect(card.cover, startsWith(kHgImageOrigin));
      expect(card.statusBadges, ['原创', '新片']);
      expect(card.episodeLabel, '更新至 1 集');
    });

    test('parses homepage banners and video rails', () {
      final home = HgHomeData.fromJson({
        'banners': [
          {
            'id': 28,
            'video_id': 10586,
            'title': '',
            'image': '/upload_01/banner.jpeg',
            'score': 9.3,
            'desc': '短剧简介',
          },
        ],
        'featured': [
          {'id': 12, 'title': '神瞳觉醒', 'cover': '/upload_01/a.jpg'},
        ],
        'latest': [],
        'cate_rec': [
          {
            'cate_id': 24,
            'cate_name': '短剧',
            'videos': [
              {'id': 117, 'title': '高三爱情故事', 'cover': '/upload_01/b.jpg'},
            ],
          },
        ],
      });

      expect(home.banners.single.videoId, 10586);
      expect(home.banners.single.image, startsWith(kHgImageOrigin));
      expect(home.featured.single.title, '神瞳觉醒');
      expect(home.categoryRails.single.videos.single.id, 117);
    });

    test('parses current playback response shape', () {
      final info = HgPlayInfo.fromJson(
        {
          'streams': {
            'main': 'https://cdn.example.test/main.m3u8',
            'hevc': 'https://cdn.example.test/hevc.m3u8',
          },
          'cdn': {'authKey': 'x-cdn-auth', 'authValue': 'token', 'app': '150'},
        },
        videoId: 7,
        episode: 3,
      );

      expect(info.videoId, 7);
      expect(info.episode, 3);
      expect(info.videoUrl, contains('main.m3u8'));
      expect(info.hevcUrl, contains('hevc.m3u8'));
      expect(info.cdnAuthKey, 'x-cdn-auth');
      expect(info.cdnAuthValue, 'token');
      expect(info.cdnApp, '150');
    });

    test('parses rich post detail and real interaction counts', () {
      final detail = HgPostDetail.fromJson({
        'id': 65,
        'title': '吃瓜正文',
        'cover': 'https://example.test/post.jpg',
        'content': '<p>正文</p><img data-src="https://example.test/a.jpg">',
        'counts': {'like': 920, 'collect': 200, 'comment': 12, 'hot': 65303},
        'interaction': {'liked': true, 'collected': false},
        'author': {'id': 7, 'name': '黄果扫地僧'},
      });

      expect(detail.post.title, '吃瓜正文');
      expect(detail.likeCount, 920);
      expect(detail.collectCount, 200);
      expect(detail.commentCount, 12);
      expect(detail.isLiked, isTrue);
      expect(detail.isCollected, isFalse);
      expect(detail.content, contains('data-src'));
    });

    test('parses topic detail and embedded FAQ', () {
      final detail = HgTopicDetail.fromJson({
        'topic': {
          'id': 12,
          'title': '精品短剧',
          'slug': 'hot-aiduanju',
          'cover': 'https://example.test/topic.jpg',
          'intro': '专题介绍',
          'video_count': 81,
          'faq': [
            {'q': '多久更新？', 'a': '持续更新。'},
          ],
        },
        'videos': {
          'items': [
            {'id': 12, 'title': '神瞳觉醒', 'cover': ''},
          ],
          'pagination': {'page': 1, 'pages': 5, 'size': 20, 'total': 81},
        },
        'related': [
          {'id': 17, 'title': '灵异专题', 'slug': 'paranormal', 'cover': ''},
        ],
      });

      expect(detail.topic.slug, 'hot-aiduanju');
      expect(detail.topic.faq.single.question, '多久更新？');
      expect(detail.videos.items.single.id, 12);
      expect(detail.videos.pagination.total, 81);
      expect(detail.related.single.slug, 'paranormal');
    });

    test('parses comment replies and likes', () {
      final comment = HgComment.fromJson({
        'id': 121363,
        'user_id': 235601,
        'nickname': '瓜友',
        'text': '好看',
        'time': '1月前',
        'like_count': 48,
        'liked': true,
        'reply_count': 1,
        'reply_list': [
          {
            'id': 122207,
            'user_id': 241445,
            'nickname': '回复者',
            'text': '同感',
            'reply_to_nickname': '瓜友',
          },
        ],
      });

      expect(comment.isLiked, isTrue);
      expect(comment.likeCount, 48);
      expect(comment.replies, hasLength(1));
      expect(comment.replies.single.replyToNickname, '瓜友');
    });

    test('parses public user stats and messages', () {
      final stats = HgUserStats.fromJson({
        'user_id': 256977,
        'like_count': 194310,
        'following': 0,
        'followers': 931,
        'video_count': 8,
        'post_count': 0,
      });
      final message = HgUserMessage.fromJson({
        'id': 9,
        'title': '更新提醒',
        'content': '<p>你追的短剧更新了</p>',
        'created_at': '刚刚',
        'is_read': false,
      });

      expect(stats.followers, 931);
      expect(stats.videoCount, 8);
      expect(message.title, '更新提醒');
      expect(message.isRead, isFalse);
      expect(message.copyWith(isRead: true).isRead, isTrue);
    });

    test('keeps interaction state in user cache', () {
      final user = HgUser.fromJson({
        'id': 9,
        'username': 'demo',
        'nickname': '演示账号',
        'counts': {'collect': 2, 'like': 4},
        'is_following': true,
        'interactions': {
          'favorite_video_ids': [10769],
          'like_video_episodes': [
            {'video_id': 10769, 'ep': 3},
          ],
        },
      });

      expect(user.favoriteVideoIds, contains(10769));
      expect(user.likedEpisodes, contains('10769:3'));
      expect(user.isFollowing, isTrue);
      expect(user.toJson()['interactions'], isA<Map>());
    });
  });

  test(
    'decrypts an AES-CBC encrypted cover and removes PKCS#7 padding',
    () async {
      final key = Uint8List.fromList(utf8.encode('f5d965df75336270'));
      final iv = Uint8List.fromList(utf8.encode('97b60394abc2fbe1'));
      final plain = Uint8List(32);
      plain.setAll(0, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      plain.fillRange(16, 32, 16);

      final cipher = CBCBlockCipher(AESEngine())
        ..init(true, ParametersWithIV<KeyParameter>(KeyParameter(key), iv));
      final encrypted = Uint8List(plain.length);
      for (var offset = 0; offset < plain.length; offset += 16) {
        cipher.processBlock(plain, offset, encrypted, offset);
      }

      final decrypted = await HgCoverCrypto.decryptOrPassThrough(encrypted);
      expect(decrypted, hasLength(16));
      expect(decrypted.take(8).toList(), [
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]);
    },
  );

  group('Custom source', () {
    test('normalizes bare domains and strips paths', () {
      expect(
        normalizeHgBaseUrl('example.com/some/path?q=1'),
        'https://example.com',
      );
      expect(
        normalizeHgBaseUrl(' http://example.com:8080/ '),
        'http://example.com:8080',
      );
      expect(normalizeHgBaseUrl(kHgDefaultBaseUrl), kHgDefaultBaseUrl);
    });

    test('rejects invalid or credential-bearing URLs', () {
      expect(() => normalizeHgBaseUrl(''), throwsFormatException);
      expect(
        () => normalizeHgBaseUrl('ftp://example.com'),
        throwsFormatException,
      );
      expect(
        () => normalizeHgBaseUrl('https://user:pass@example.com'),
        throwsFormatException,
      );
    });

    test('persists a custom source and can reset to the default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = SourceController(prefs);

      expect(controller.baseUrl, kHgBootstrapBaseUrl);
      await controller.setBaseUrl('example.com');
      expect(controller.baseUrl, 'https://example.com');
      expect(controller.isDefault, isFalse);

      await controller.reset();
      expect(controller.baseUrl, kHgDefaultBaseUrl);
      expect(controller.isDefault, isTrue);
    });

    test('persists multiple sources and the active source', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = SourceController(prefs);

      await controller.addSource('https://example.org');
      await controller.selectSource('https://example.org');

      final restored = SourceController(prefs);
      expect(restored.sources, contains('https://example.org'));
      expect(restored.baseUrl, 'https://example.org');
    });
  });

  test('round-trips download tasks with cached episodes', () {
    final task = HgDownloadTask(
      videoId: 10586,
      title: '任意门',
      cover: 'https://example.test/cover.jpg',
      totalEpisodes: 12,
      episodes: const {
        1: HgDownloadedEpisode(
          number: 1,
          directory: '/downloads/10586/1',
          manifestPath: '/downloads/10586/1/index.m3u8',
          bytes: 1024,
          updatedAt: '2026-11-16',
        ),
      },
      lastKnownEpisode: 12,
    );
    final decoded = HgDownloadTask.fromJson(task.toJson());
    expect(decoded.videoId, 10586);
    expect(decoded.episodes[1]?.manifestPath, endsWith('index.m3u8'));
    expect(decoded.downloadedBytes, 1024);
    expect(decoded.totalEpisodes, 12);
  });

  test('stores playback history locally and deduplicates by video', () async {
    SharedPreferences.setMockInitialValues({});
    await HgLocalHistory.save(
      videoId: 1,
      title: '第一部',
      cover: 'https://example.test/1.jpg',
      episode: 2,
      totalEpisodes: 20,
    );
    await HgLocalHistory.save(
      videoId: 2,
      title: '第二部',
      cover: 'https://example.test/2.jpg',
      episode: 1,
      totalEpisodes: 10,
    );
    await HgLocalHistory.save(
      videoId: 1,
      title: '第一部',
      cover: 'https://example.test/1.jpg',
      episode: 3,
      totalEpisodes: 20,
      positionMs: 42000,
      durationMs: 120000,
    );

    final items = await HgLocalHistory.load();
    expect(items, hasLength(2));
    expect(items.first.dramaId, 1);
    expect(items.first.lastEpisode, 3);
    expect(items.first.positionMs, 42000);
    expect(items.first.durationMs, 120000);
  });

  testWidgets('loading skeleton fits a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HgLoading())),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
    expect(find.byType(HgLoading), findsOneWidget);
  });

  test('compares GitHub release versions', () {
    expect(HgUpdateService.compareVersions('v1.4.0', '1.3.9'), 1);
    expect(HgUpdateService.compareVersions('1.4', 'v1.4.0'), 0);
    expect(HgUpdateService.compareVersions('2.0.0', '1.99.99'), 1);
    expect(HgUpdateService.compareVersions('1.4.0', '1.4.1'), -1);
  });

  test('parses GitHub release assets and plain release body', () {
    final release = HgReleaseUpdate.fromJson({
      'tag_name': 'v1.5.0',
      'name': '果幕 v1.5.0',
      'html_url': 'https://github.com/DearLicy/guomu/releases/tag/v1.5.0',
      'body': '# 更新\n\n- 新增功能\n- 修复问题',
      'assets': [
        {
          'name': 'Guomu-1.5.0.apk',
          'browser_download_url': 'https://example.test/guomu.apk',
          'size': 100,
        },
        {
          'name': 'Guomu-1.5.0-unsigned.ipa',
          'browser_download_url': 'https://example.test/guomu.ipa',
          'size': 90,
        },
      ],
    });

    expect(release.version, '1.5.0');
    expect(release.androidAsset?.downloadUrl, endsWith('.apk'));
    expect(release.iosAsset?.downloadUrl, endsWith('.ipa'));
    expect(HgUpdateService.plainReleaseBody(release.body), contains('• 新增功能'));
  });
}
