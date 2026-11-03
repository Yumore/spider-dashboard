import 'package:dashboard/features/reading/flutterebook/data/feedbooks_download_record.dart';
import 'package:dashboard/features/reading/flutterebook/data/feedbooks_download_service.dart';
import 'package:dashboard/features/reading/flutterebook/models/entry.dart';
import 'package:dashboard/features/reading/flutterebook/presentation/controllers/feedbooks_downloads_controller.dart';
import 'package:dashboard/features/reading/flutterebook/presentation/widgets/feedbooks_book_opener.dart';
import 'package:dashboard/features/reading/flutterebook/presentation/widgets/feedbooks_download_alert.dart';
import 'package:dashboard/features/reading/local_library/local_reading_reader_page.dart';
import 'package:flutter/material.dart';

/// 源工程详情页的 `_DownloadButton`：未下载显示 `DOWNLOAD`，
/// 已下载（本地库里有同 id 记录）显示 `READ BOOK`。
///
/// 文件不存在时提示并删除失效记录；文件存在时使用 Dashboard 内置阅读器。
class FeedbooksDownloadButton extends StatelessWidget {
  const FeedbooksDownloadButton({
    super.key,
    required this.entry,
    required this.downloads,
    required this.downloadService,
    required this.opener,
  });

  final FeedbooksEntry entry;
  final FeedbooksDownloadsController downloads;
  final FeedbooksDownloadService downloadService;
  final FeedbooksBookOpener opener;

  String get id => entry.id!.t.toString();

  @override
  Widget build(BuildContext context) {
    final int index = downloads.records.indexWhere(
      (FeedbooksDownloadRecord element) => element.id == id,
    );
    if (index == -1) {
      return _downloadButton(context);
    }
    final FeedbooksDownloadRecord book = downloads.records[index];
    return TextButton(
      onPressed: () => _openBook(context, book.path),
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      child: Text(
        'Read Book'.toUpperCase(),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.black,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _downloadButton(BuildContext context) => TextButton(
    style: TextButton.styleFrom(padding: EdgeInsets.zero),
    onPressed: () {
      FeedbooksDownloadAlert.show(
        context: context,
        url: entry.link![3].href!,
        name: entry.title!.t ?? '',
        image: '${entry.link![1].href}',
        id: id,
        service: downloadService,
        onCompleted: (FeedbooksDownloadRecord record) =>
            downloads.addBook(record, record.id),
      );
    },
    child: Text(
      'Download'.toUpperCase(),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.black,
        decoration: TextDecoration.underline,
      ),
    ),
  );

  Future<void> _openBook(BuildContext context, String path) async {
    final bool exists = await opener.exists(path);
    if (!context.mounted) return;
    if (!exists) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text(FeedbooksBookOpener.missingFileMessage)),
      );
      await downloads.deleteBook(id);
      return;
    }
    await Navigator.of(context).push<void>(
      LocalReadingReaderPage.route(
        record: FeedbooksBookOpener.readingRecord(
          id: id,
          name: entry.title?.t ?? 'Feedbooks',
          path: path,
        ),
      ),
    );
  }
}
