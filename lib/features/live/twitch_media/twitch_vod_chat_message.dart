/// One plain-text public Twitch VOD chat comment at its playback offset.
class TwitchVodChatMessage {
  const TwitchVodChatMessage({
    required this.id,
    required this.offsetSeconds,
    required this.author,
    required this.text,
  });

  final String id;
  final double offsetSeconds;
  final String author;
  final String text;

  factory TwitchVodChatMessage.fromJson(Map<String, Object?> json) {
    final commenter = json['commenter'] is Map
        ? json['commenter'] as Map
        : const {};
    final message = json['message'] is Map ? json['message'] as Map : const {};
    final fragments = message['fragments'];
    final text = fragments is List
        ? fragments
              .whereType<Map>()
              .map((fragment) => '${fragment['text'] ?? ''}')
              .join()
        : '';
    return TwitchVodChatMessage(
      id: '${json['id'] ?? '${commenter['id'] ?? ''}:${json['contentOffsetSeconds'] ?? ''}:$text'}',
      offsetSeconds:
          (json['contentOffsetSeconds'] as num?)?.toDouble() ??
          double.tryParse('${json['contentOffsetSeconds'] ?? 0}') ??
          0,
      author:
          '${commenter['displayName'] ?? commenter['login'] ?? 'Twitch 用户'}',
      text: text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim(),
    );
  }
}
