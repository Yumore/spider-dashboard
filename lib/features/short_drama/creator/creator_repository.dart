import 'dart:convert';

import 'package:dashboard/features/short_drama/creator/creator_project.dart';
import 'package:sqflite/sqflite.dart';

class CreatorRepository {
  static const String _databaseName = 'dashboard_creator_projects.db';
  static const String _tableName = 'creator_projects';
  static const int _databaseVersion = 1;
  static Database? _database;
  static Future<Database>? _opening;

  Future<Database> get _db async {
    final current = _database;
    if (current != null) return current;
    final opening = _opening ??= _openDatabase();
    try {
      return await opening;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  static Future<Database> _openDatabase() async {
    final path = '${await getDatabasesPath()}/$_databaseName';
    final database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            kind TEXT NOT NULL,
            sections_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
    _database = database;
    return database;
  }

  Future<List<CreatorProject>> loadProjects() async {
    final rows = await (await _db).query(
      _tableName,
      orderBy: 'updated_at DESC',
    );
    return rows.map(_projectFromRow).toList();
  }

  Future<void> saveProject(CreatorProject project) async {
    await (await _db).insert(_tableName, <String, Object?>{
      'id': project.id,
      'title': project.title,
      'kind': project.kind,
      'sections_json': jsonEncode(project.sections),
      'created_at': project.createdAt.toIso8601String(),
      'updated_at': project.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProject(String id) async {
    await (await _db).delete(
      _tableName,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  CreatorProject _projectFromRow(Map<String, Object?> row) {
    final decodedSections = jsonDecode(row['sections_json']! as String);
    if (decodedSections is! Map) {
      throw const FormatException('创作项目区块数据格式无效');
    }
    return CreatorProject(
      id: row['id']! as String,
      title: row['title']! as String,
      kind: row['kind']! as String,
      sections: <String, String>{
        for (final entry in decodedSections.entries)
          '${entry.key}': '${entry.value ?? ''}',
      },
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}
