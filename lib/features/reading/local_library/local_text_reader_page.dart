import 'package:dashboard/features/reading/local_library/local_reading_record.dart';
import 'package:dashboard/features/reading/local_library/local_text_reader_page_state.dart';
import 'package:flutter/material.dart';

class LocalTextReaderPage extends StatefulWidget {
  const LocalTextReaderPage({required this.record, super.key});

  final LocalReadingRecord record;

  static MaterialPageRoute<void> route({required LocalReadingRecord record}) =>
      MaterialPageRoute<void>(
        builder: (_) => LocalTextReaderPage(record: record),
      );

  @override
  LocalTextReaderPageState createState() => LocalTextReaderPageState();
}
