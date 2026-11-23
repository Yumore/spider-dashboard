import 'dart:math' as math;

abstract interface class HgSourceRouter {
  String get baseUrl;
  List<String> get rankedSources;
  Future<void> recordSuccess(
    String baseUrl,
    Duration latency, {
    required bool promote,
  });
  Future<void> recordFailure(String baseUrl);
}

class HgSourceHealth {
  const HgSourceHealth({
    required this.baseUrl,
    this.latencyMs,
    this.successCount = 0,
    this.failureCount = 0,
    this.consecutiveFailures = 0,
    this.lastSuccessAt,
    this.lastCheckedAt,
    this.cooldownUntil,
  });

  final String baseUrl;
  final int? latencyMs;
  final int successCount;
  final int failureCount;
  final int consecutiveFailures;
  final DateTime? lastSuccessAt;
  final DateTime? lastCheckedAt;
  final DateTime? cooldownUntil;

  bool get isCoolingDown =>
      cooldownUntil != null && cooldownUntil!.isAfter(DateTime.now());

  bool get hasBeenChecked => lastCheckedAt != null;

  String get statusLabel {
    if (isCoolingDown) return '暂不可用';
    if (!hasBeenChecked) return '待检测';
    if (consecutiveFailures > 0) return '连接不稳定';
    return '可用';
  }

  double get score {
    if (isCoolingDown) return -100000;
    final total = successCount + failureCount;
    final reliability = total == 0 ? 0.45 : successCount / total;
    final latencyPenalty = math.min(latencyMs ?? 5000, 10000) / 10;
    final failurePenalty = consecutiveFailures * 120;
    final unknownPenalty = hasBeenChecked ? 0 : 180;
    return reliability * 1000 -
        latencyPenalty -
        failurePenalty -
        unknownPenalty;
  }

  HgSourceHealth copyWith({
    int? latencyMs,
    int? successCount,
    int? failureCount,
    int? consecutiveFailures,
    DateTime? lastSuccessAt,
    DateTime? lastCheckedAt,
    DateTime? cooldownUntil,
    bool clearCooldown = false,
  }) {
    return HgSourceHealth(
      baseUrl: baseUrl,
      latencyMs: latencyMs ?? this.latencyMs,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      cooldownUntil: clearCooldown ? null : cooldownUntil ?? this.cooldownUntil,
    );
  }

  Map<String, dynamic> toJson() => {
    'base_url': baseUrl,
    'latency_ms': latencyMs,
    'success_count': successCount,
    'failure_count': failureCount,
    'consecutive_failures': consecutiveFailures,
    'last_success_at': lastSuccessAt?.millisecondsSinceEpoch,
    'last_checked_at': lastCheckedAt?.millisecondsSinceEpoch,
    'cooldown_until': cooldownUntil?.millisecondsSinceEpoch,
  };

  static HgSourceHealth? fromJson(Map<String, dynamic> json) {
    final baseUrl = json['base_url']?.toString().trim() ?? '';
    if (baseUrl.isEmpty) return null;
    DateTime? date(dynamic value) {
      final milliseconds = value is num
          ? value.toInt()
          : int.tryParse('$value');
      return milliseconds == null || milliseconds <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }

    return HgSourceHealth(
      baseUrl: baseUrl,
      latencyMs: (json['latency_ms'] as num?)?.toInt(),
      successCount: (json['success_count'] as num?)?.toInt() ?? 0,
      failureCount: (json['failure_count'] as num?)?.toInt() ?? 0,
      consecutiveFailures: (json['consecutive_failures'] as num?)?.toInt() ?? 0,
      lastSuccessAt: date(json['last_success_at']),
      lastCheckedAt: date(json['last_checked_at']),
      cooldownUntil: date(json['cooldown_until']),
    );
  }
}

class HgSourcePool implements HgSourceRouter {
  HgSourcePool({
    Iterable<String> sources = const [],
    String? activeSource,
    bool automaticSelection = true,
    Map<String, HgSourceHealth> health = const {},
  }) : _automaticSelection = automaticSelection {
    _sources.addAll(sources);
    for (final source in _sources) {
      _health[source] = health[source] ?? HgSourceHealth(baseUrl: source);
    }
    _activeSource = activeSource != null && _sources.contains(activeSource)
        ? activeSource
        : _sources.firstOrNull;
  }

  final List<String> _sources = [];
  final Map<String, HgSourceHealth> _health = {};
  String? _activeSource;
  bool _automaticSelection;

  @override
  String get baseUrl => _activeSource ?? _sources.firstOrNull ?? '';

  String? get activeSource => _activeSource;

  bool get automaticSelection => _automaticSelection;

  List<String> get sources => List.unmodifiable(_sources);

  List<HgSourceHealth> get health => _sources
      .map((source) => _health[source] ?? HgSourceHealth(baseUrl: source))
      .toList(growable: false);

  HgSourceHealth? healthFor(String source) => _health[source];

  @override
  List<String> get rankedSources {
    final ranked = [...health]
      ..sort((left, right) {
        if (left.isCoolingDown != right.isCoolingDown) {
          return left.isCoolingDown ? 1 : -1;
        }
        if (!left.isCoolingDown && left.baseUrl == baseUrl) return -1;
        if (!right.isCoolingDown && right.baseUrl == baseUrl) return 1;
        return right.score.compareTo(left.score);
      });
    return ranked.map((item) => item.baseUrl).toList(growable: false);
  }

  void setAutomaticSelection(bool value) {
    _automaticSelection = value;
  }

  void setActive(String source) {
    if (_sources.contains(source)) _activeSource = source;
  }

  void merge(Iterable<String> values) {
    for (final value in values) {
      if (value.isEmpty || _sources.contains(value)) continue;
      _sources.add(value);
      _health[value] = HgSourceHealth(baseUrl: value);
    }
    _activeSource ??= _sources.firstOrNull;
  }

  String? selectBestAvailable() {
    final candidate =
        health
            .where((item) => item.hasBeenChecked && !item.isCoolingDown)
            .toList(growable: false)
          ..sort((left, right) => right.score.compareTo(left.score));
    final selected = candidate.firstOrNull?.baseUrl;
    if (selected != null && _automaticSelection) _activeSource = selected;
    return selected;
  }

  void remove(String source) {
    if (_sources.length <= 1) return;
    _sources.remove(source);
    _health.remove(source);
    if (_activeSource == source) {
      _activeSource = _sources.firstOrNull;
    }
  }

  void resetTo(String source) {
    if (!_sources.contains(source)) {
      _sources.insert(0, source);
      _health[source] = HgSourceHealth(baseUrl: source);
    }
    _activeSource = source;
  }

  @override
  Future<void> recordSuccess(
    String source,
    Duration latency, {
    required bool promote,
  }) async {
    final current = _health[source] ?? HgSourceHealth(baseUrl: source);
    final now = DateTime.now();
    _health[source] = current.copyWith(
      latencyMs: latency.inMilliseconds,
      successCount: current.successCount + 1,
      consecutiveFailures: 0,
      lastSuccessAt: now,
      lastCheckedAt: now,
      clearCooldown: true,
    );
    if (promote && _automaticSelection) _activeSource = source;
  }

  @override
  Future<void> recordFailure(String source) async {
    final current = _health[source] ?? HgSourceHealth(baseUrl: source);
    final now = DateTime.now();
    final failures = current.consecutiveFailures + 1;
    final cooldownSeconds = math.min(
      600,
      20 * (1 << math.min(failures - 1, 5)),
    );
    _health[source] = current.copyWith(
      failureCount: current.failureCount + 1,
      consecutiveFailures: failures,
      lastCheckedAt: now,
      cooldownUntil: now.add(Duration(seconds: cooldownSeconds)),
    );
    if (_activeSource == source) selectBestAvailable();
  }

  Map<String, dynamic> toJson() => {
    'version': 3,
    'active': _activeSource,
    'automatic_selection': _automaticSelection,
    'sources': health.map((item) => item.toJson()).toList(growable: false),
  };

  static HgSourcePool fromJson(
    Map<String, dynamic> json, {
    Iterable<String> fallbackSources = const [],
  }) {
    final records = <String, HgSourceHealth>{};
    final values = json['sources'];
    if (values is List) {
      for (final value in values.whereType<Map>()) {
        final item = HgSourceHealth.fromJson(Map<String, dynamic>.from(value));
        if (item != null) records[item.baseUrl] = item;
      }
    }
    final sources = records.isEmpty ? fallbackSources : records.keys;
    return HgSourcePool(
      sources: sources,
      activeSource: json['active']?.toString(),
      automaticSelection: json['automatic_selection'] != false,
      health: records,
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
