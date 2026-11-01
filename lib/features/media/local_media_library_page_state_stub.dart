import 'package:dashboard/features/media/local_media_library_page.dart';
import 'package:flutter/material.dart';

/// Web fallback for the native local-file library.
class LocalMediaLibraryPageState extends State<LocalMediaLibraryPage> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('本地媒体库')),
    body: const Center(child: Text('当前平台不支持本地媒体文件访问')),
  );
}
