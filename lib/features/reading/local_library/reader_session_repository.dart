import 'dart:convert';

import 'package:dashboard/features/reading/local_library/reader_annotation.dart';
import 'package:flutter/material.dart';
import 'package:papyrus_reader/papyrus_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderSessionRepository {
  ReaderSessionRepository({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _keyPrefix = 'reading.local_session.v1.';
  static Future<void> _pendingWrites = Future<void>.value();

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  String _key(String id) => '$_keyPrefix$id';

  Future<Map<String, dynamic>> _read(String id) async {
    final raw = (await _prefs).getString(_key(id));
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    } on TypeError {
      return <String, dynamic>{};
    }
  }

  Future<void> _write(String id, Map<String, dynamic> data) async {
    await (await _prefs).setString(_key(id), jsonEncode(data));
  }

  Future<void> _serializeWrite(Future<void> Function() operation) {
    final result = _pendingWrites.then((_) => operation());
    _pendingWrites = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<ReaderLocator?> loadLocator(String id) async {
    final value = (await _read(id))['locator'];
    if (value is! Map) return null;
    try {
      return ReaderLocator.fromJson(Map<String, Object?>.from(value));
    } on FormatException {
      return null;
    }
  }

  Future<void> saveLocator(String id, ReaderLocator locator) =>
      _serializeWrite(() async {
        final data = await _read(id);
        data['locator'] = locator.toJson();
        await _write(id, data);
      });

  Future<ReaderPreferences?> loadPreferences(String id) async {
    final value = (await _read(id))['preferences'];
    if (value is! Map) return null;
    try {
      final json = Map<String, dynamic>.from(value);
      return ReaderPreferences(
        fontFamily: json['fontFamily'] as String?,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
        letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0,
        paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 8,
        pageMargins: EdgeInsets.fromLTRB(
          (json['marginLeft'] as num?)?.toDouble() ?? 24,
          (json['marginTop'] as num?)?.toDouble() ?? 24,
          (json['marginRight'] as num?)?.toDouble() ?? 24,
          (json['marginBottom'] as num?)?.toDouble() ?? 24,
        ),
        backgroundColor: Color(
          (json['backgroundColor'] as num?)?.toInt() ?? 0xffffffff,
        ),
        foregroundColor: Color(
          (json['foregroundColor'] as num?)?.toInt() ?? 0xff1b1b1b,
        ),
        brightness: Brightness.values.byName(
          json['brightness'] as String? ?? 'light',
        ),
        layoutMode: ReaderLayoutMode.values.byName(
          json['layoutMode'] as String? ?? 'paginated',
        ),
        columnMode: ReaderColumnMode.values.byName(
          json['columnMode'] as String? ?? 'single',
        ),
        pageTurnAnimation: json['pageTurnAnimation'] as bool? ?? true,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  Future<void> savePreferences(String id, ReaderPreferences preferences) =>
      _serializeWrite(() async {
        final data = await _read(id);
        final margins = preferences.pageMargins;
        data['preferences'] = <String, Object?>{
          'fontFamily': preferences.fontFamily,
          'fontSize': preferences.fontSize,
          'lineHeight': preferences.lineHeight,
          'letterSpacing': preferences.letterSpacing,
          'paragraphSpacing': preferences.paragraphSpacing,
          'marginLeft': margins.left,
          'marginTop': margins.top,
          'marginRight': margins.right,
          'marginBottom': margins.bottom,
          'backgroundColor': preferences.backgroundColor.toARGB32(),
          'foregroundColor': preferences.foregroundColor.toARGB32(),
          'brightness': preferences.brightness.name,
          'layoutMode': preferences.layoutMode.name,
          'columnMode': preferences.columnMode.name,
          'pageTurnAnimation': preferences.pageTurnAnimation,
        };
        await _write(id, data);
      });

  Future<List<ReaderAnnotation>> loadAnnotations(String id) async {
    final value = (await _read(id))['annotations'];
    if (value is! List) return const [];
    try {
      return value
          .whereType<Map>()
          .map(
            (item) =>
                ReaderAnnotation.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  Future<void> saveAnnotations(String id, List<ReaderAnnotation> annotations) =>
      _serializeWrite(() async {
        final data = await _read(id);
        data['annotations'] = annotations.map((item) => item.toJson()).toList();
        await _write(id, data);
      });

  Future<void> clear(String id) =>
      _serializeWrite(() async => (await _prefs).remove(_key(id)));
}
