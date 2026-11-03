import 'package:dashboard/features/reading/flutterebook/data/feedbooks_download_record.dart';
import 'package:dashboard/features/reading/flutterebook/presentation/widgets/feedbooks_cover_image.dart';
import 'package:dashboard/features/reading/flutterebook/presentation/widgets/feedbooks_dismissible_background.dart';
import 'package:flutter/material.dart';

/// One completed Feedbooks download row with swipe-to-delete behavior.
class FeedbooksDownloadRow extends StatelessWidget {
  const FeedbooksDownloadRow({
    required this.record,
    required this.onTap,
    required this.onDismissed,
    super.key,
  });

  final FeedbooksDownloadRecord record;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ObjectKey(record.id),
      direction: DismissDirection.endToStart,
      background: const FeedbooksDismissibleBackground(),
      onDismissed: (_) => onDismissed(),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Row(
            children: [
              FeedbooksCoverImage(
                url: record.image,
                height: 70,
                width: 70,
                fit: BoxFit.cover,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'COMPLETED',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        Text(record.size, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
