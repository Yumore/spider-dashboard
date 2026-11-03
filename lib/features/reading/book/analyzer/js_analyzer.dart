import 'dart:convert';

import 'package:dashboard/app/platform/app_platform.dart';
import 'package:dashboard/features/reading/book/util/book_log.dart';
import 'js_runtime_stub.dart'
    if (dart.library.io) 'js_runtime_native.dart'
    as platform_js;

/// Legado-style JavaScript rule host for book sources.
class JsEngine {
  JsEngine._();

  static final JsEngine instance = JsEngine._();

  static const String enabledPreferenceKey =
      'book.source.javascript_execution_enabled';

  String _loadedJsLib = '';
  bool _enabled = false;

  /// Whether this platform has a JavaScript runtime implementation.
  bool get runtimeAvailable =>
      platform_js.jsRuntimeSupported && !AppPlatform.isOhos;

  /// Execution is off until the user enables it in source management.
  bool get enabled => _enabled && runtimeAvailable;

  set enabled(bool value) => _enabled = value && runtimeAvailable;

  /// Records the Legado helper library used by the current source.
  void ensureJsLib(String jsLib) {
    final lib = jsLib.trim();
    if (lib.isEmpty) return;
    _loadedJsLib = lib;
    BookLog.d('JsEngine', 'jsLib loaded (${lib.length} chars)');
  }

  /// Text of the last [ensureJsLib] call (empty when none).
  String get loadedJsLib => _loadedJsLib;

  /// True if [rule] looks like it needs JS evaluation.
  static bool needsJs(String rule) {
    final r = rule.trim();
    if (r.isEmpty) return false;
    return r.startsWith('@js:') || r.contains('<js>') || r.contains('@js:');
  }

  /// Extract pure JS code from a Legado rule fragment, or null when not JS.
  static String? extractCode(String rule) {
    final r = rule.trim();
    if (r.isEmpty) return null;
    if (r.startsWith('@js:')) {
      return r.substring(4).trim();
    }
    final m = RegExp(
      r'<js>([\s\S]*?)</js>',
      caseSensitive: false,
    ).firstMatch(r);
    if (m != null) return (m.group(1) ?? '').trim();
    final idx = r.indexOf('@js:');
    if (idx >= 0) return r.substring(idx + 4).trim();
    return null;
  }

  /// Evaluates a pure Legado transformation with [result], [baseUrl] and [src].
  /// Source execution is opt-in because imported scripts are executable code.
  String eval(
    String code, {
    String result = '',
    String baseUrl = '',
    String src = '',
    String jsLib = '',
  }) {
    if (jsLib.isNotEmpty) ensureJsLib(jsLib);
    if (code.isEmpty) return result;
    if (!enabled) {
      BookLog.d(
        'JsEngine',
        'JavaScript is disabled; rule degraded to passthrough',
      );
      return result.isNotEmpty ? result : src;
    }
    try {
      return platform_js.evaluateJavascript(
        _buildEvaluationScript(
          code,
          result: result,
          baseUrl: baseUrl,
          src: src,
          jsLib: jsLib,
        ),
      );
    } catch (error, stackTrace) {
      BookLog.e(
        'JsEngine',
        'JavaScript rule failed',
        error: error,
        stackTrace: stackTrace,
      );
      return result.isNotEmpty ? result : src;
    }
  }

  String _buildEvaluationScript(
    String code, {
    required String result,
    required String baseUrl,
    required String src,
    required String jsLib,
  }) {
    final statements = <String>[
      '(function () {',
      'var result = ${jsonEncode(result)};',
      'var baseUrl = ${jsonEncode(baseUrl)};',
      'var src = ${jsonEncode(src)};',
      if (jsLib.isNotEmpty) jsLib,
      'var value = eval(${jsonEncode(code)});',
      'if (value === undefined || value === null) value = result;',
      'if (value === undefined || value === null) value = src;',
      'if (value === undefined || value === null) return "";',
      'return typeof value === "string" ? value : JSON.stringify(value);',
      '})()',
    ];
    return statements.join('\n');
  }

  /// If [rule] is JS, run it against [input]; otherwise null (caller handles).
  String? tryEvalRule(
    String rule, {
    required String input,
    required String baseUrl,
    String jsLib = '',
  }) {
    if (!needsJs(rule)) return null;
    final code = extractCode(rule);
    if (code == null || code.isEmpty) return null;
    return eval(
      code,
      result: input,
      baseUrl: baseUrl,
      src: input,
      jsLib: jsLib,
    );
  }

  /// Parse JS list output into List (of Map or String).
  List<dynamic> evalList(
    String code, {
    String result = '',
    String baseUrl = '',
    String src = '',
    String jsLib = '',
  }) {
    final out = eval(
      code,
      result: result,
      baseUrl: baseUrl,
      src: src,
      jsLib: jsLib,
    );
    if (out.isEmpty) return const [];
    try {
      final decoded = jsonDecode(out);
      if (decoded is List) return decoded;
      if (decoded is Map) return [decoded];
    } catch (_) {
      final lines = out
          .split(RegExp(r'[\r\n]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (lines.length > 1) return lines;
    }
    return [out];
  }

  void dispose() {
    _loadedJsLib = '';
  }
}
