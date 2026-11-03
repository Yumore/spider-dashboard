import 'package:dashboard/features/reading/flutterebook/data/feedbooks_download_record.dart';
import 'package:dashboard/features/reading/flutterebook/data/feedbooks_downloads_local_data_source_impl.dart';
import 'package:dashboard/features/reading/flutterebook/data/feedbooks_downloads_repository_impl.dart';
import 'package:dashboard/features/reading/flutterebook/presentation/controllers/feedbooks_downloads_controller.dart';
import 'package:dashboard/features/reading/flutterebook/presentation/pages/downloads/feedbooks_downloads_page.dart';
import 'package:dashboard/features/reading/flutterebook/presentation/widgets/feedbooks_book_opener.dart';
import 'package:dashboard/features/reading/flutterebook/presentation/widgets/feedbooks_download_row.dart';
import 'package:dashboard/features/reading/flutterebook/presentation/widgets/feedbooks_empty_view.dart';
import 'package:dashboard/features/reading/local_library/local_reading_reader_page.dart';
import 'package:flutter/material.dart';

/// [FeedbooksDownloadsPage] 的状态。
///
/// 行的排版与源工程一致：70x70 封面 + 书名 + 分隔线 + `COMPLETED` / 体积；
/// 左滑（`DismissDirection.endToStart`）删除记录。
class FeedbooksDownloadsPageState extends State<FeedbooksDownloadsPage> {
  FeedbooksDownloadsLocalDataSourceImpl? _ownedDataSource;
  FeedbooksDownloadsController? _ownedDownloads;
  FeedbooksBookOpener? _ownedOpener;

  FeedbooksDownloadsController get _downloads =>
      widget.downloads ??
      (_ownedDownloads ??= FeedbooksDownloadsController(
        repository: FeedbooksDownloadsRepositoryImpl(
          _ownedDataSource ??= FeedbooksDownloadsLocalDataSourceImpl(),
        ),
      ));

  FeedbooksBookOpener get _opener =>
      widget.opener ?? (_ownedOpener ??= const FeedbooksBookOpener());

  @override
  void initState() {
    super.initState();
    _downloads.addListener(_onControllerChanged);
    _downloads.load();
  }

  @override
  void dispose() {
    _ownedDownloads?.removeListener(_onControllerChanged);
    _ownedDownloads?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 文件存在时使用 Dashboard 内置阅读器；失效记录会从下载列表移除。
  Future<void> _openBook(FeedbooksDownloadRecord record) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    if (!await _opener.exists(record.path)) {
      await _downloads.deleteBook(record.id);
      messenger?.showSnackBar(
        const SnackBar(content: Text(FeedbooksBookOpener.missingFileMessage)),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      LocalReadingReaderPage.route(
        record: FeedbooksBookOpener.readingRecord(
          id: record.id,
          name: record.name,
          path: record.path,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<FeedbooksDownloadRecord> records = _downloads.records;
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Downloads')),
      body: records.isEmpty
          ? const FeedbooksEmptyView()
          : ListView.separated(
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 5),
              itemBuilder: (BuildContext context, int index) {
                return FeedbooksDownloadRow(
                  record: records[index],
                  onTap: () => _openBook(records[index]),
                  onDismissed: () => _downloads.deleteBook(records[index].id),
                );
              },
            ),
    );
  }
}
