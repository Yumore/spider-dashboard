import 'package:dashboard/features/shared/ui/content_entry_section.dart';
import 'package:dashboard/features/shared/ui/content_entry_section_view.dart';
import 'package:dashboard/features/shared/ui/content_status.dart';
import 'package:dashboard/features/shared/ui/module_page_scaffold.dart';
import 'package:dashboard/features/source_library/source_library_catalog.dart';
import 'package:flutter/material.dart';

/// One styled index for each content and source module already wired to the app.
class SourceLibraryPage extends StatelessWidget {
  const SourceLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: sourceLibraryCategories.length,
      child: ModulePageScaffold(
        title: '内容源库',
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            for (final category in sourceLibraryCategories)
              Tab(text: category.title),
          ],
        ),
        body: TabBarView(
          children: [
            for (final category in sourceLibraryCategories)
              _buildCategoryPage(category),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPage(
    ({String title, List<ContentEntrySection> sections}) category,
  ) {
    final hasAvailableEntries = category.sections.any(
      (section) => section.entries.any((entry) => entry.isAvailable),
    );
    if (!hasAvailableEntries) {
      return const ContentStatusView(
        title: '当前平台暂不支持',
        message: '此类来源需要当前平台尚未接入的原生能力。',
        icon: Icons.devices_other_outlined,
      );
    }
    return ListView(
      key: PageStorageKey<String>('source-library-${category.title}'),
      padding: ModulePageScaffold.pagePadding,
      children: [
        for (final section in category.sections)
          ContentEntrySectionView(section: section),
      ],
    );
  }
}
