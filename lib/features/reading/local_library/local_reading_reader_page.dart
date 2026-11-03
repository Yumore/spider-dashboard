import 'package:dashboard/features/reading/local_library/local_reading_record.dart';
import 'package:dashboard/features/reading/local_library/local_reading_reader_page_state.dart';
import 'package:flutter/material.dart';

class LocalReadingReaderPage extends StatefulWidget {
  const LocalReadingReaderPage({required this.record, super.key});

  final LocalReadingRecord record;

  static MaterialPageRoute<void> route({required LocalReadingRecord record}) =>
      MaterialPageRoute<void>(
        builder: (_) => LocalReadingReaderPage(record: record),
      );

  @override
  LocalReadingReaderPageState createState() => LocalReadingReaderPageState();
}
