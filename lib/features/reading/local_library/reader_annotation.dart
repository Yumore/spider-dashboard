import 'package:flutter/material.dart';
import 'package:papyrus_reader/papyrus_reader.dart';

class ReaderAnnotation {
  const ReaderAnnotation({
    required this.id,
    required this.selection,
    required this.note,
    required this.colorValue,
  });

  factory ReaderAnnotation.fromJson(Map<String, dynamic> json) {
    return ReaderAnnotation(
      id: json['id'] as String,
      selection: ReaderSelection.fromJson(
        Map<String, Object?>.from(json['selection'] as Map),
      ),
      note: json['note'] as String? ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xffffd54f,
    );
  }

  final String id;
  final ReaderSelection selection;
  final String note;
  final int colorValue;

  ReaderHighlight toHighlight() =>
      ReaderHighlight(id: id, selection: selection, color: Color(colorValue));

  ReaderAnnotation withNote(String value) => ReaderAnnotation(
    id: id,
    selection: selection,
    note: value,
    colorValue: colorValue,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'selection': selection.toJson(),
    'note': note,
    'colorValue': colorValue,
  };
}
