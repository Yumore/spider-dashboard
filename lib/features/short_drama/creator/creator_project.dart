class CreatorProject {
  const CreatorProject({
    required this.id,
    required this.title,
    required this.kind,
    required this.sections,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String kind;
  final Map<String, String> sections;
  final DateTime createdAt;
  final DateTime updatedAt;

  CreatorProject copyWith({
    String? title,
    Map<String, String>? sections,
    DateTime? updatedAt,
  }) {
    return CreatorProject(
      id: id,
      title: title ?? this.title,
      kind: kind,
      sections: sections ?? this.sections,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

List<String> creatorSectionsFor(String kind) {
  if (kind == '小说') {
    return const <String>['故事设定', '人物与世界观', '分卷大纲', '章节正文'];
  }
  return const <String>['故事设定', '人物设定', '分集大纲', '剧本正文', '分镜与画面提示'];
}
