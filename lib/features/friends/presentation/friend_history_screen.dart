import 'package:chocolog/features/history/presentation/history_screens.dart';
import 'package:flutter/material.dart';

class FriendHistoryScreen extends StatelessWidget {
  const FriendHistoryScreen({
    super.key,
    required this.ownerId,
    this.displayName,
  });

  final String ownerId;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final title = displayName == null || displayName!.isEmpty
        ? 'フレンドの履歴'
        : '${displayName!}さんの履歴';
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 25),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
      ),
      body: HistoryScreen(embedded: true, ownerId: ownerId),
    );
  }
}
