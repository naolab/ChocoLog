import 'package:chocolog/app/theme.dart';
import 'package:chocolog/features/studios/data/studio_repository.dart';
import 'package:flutter/material.dart';

class StudioSearchScreen extends StatefulWidget {
  const StudioSearchScreen({super.key, this.selectable = false});

  final bool selectable;

  @override
  State<StudioSearchScreen> createState() => _StudioSearchScreenState();
}

class _StudioSearchScreenState extends State<StudioSearchScreen> {
  late Future<List<StudioItem>> _studios;
  Set<String> _favoriteIds = {};
  var _query = '';

  @override
  void initState() {
    super.initState();
    _studios = _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.selectable ? '店舗を選ぶ' : 'よく行く店舗')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          children: [
            TextField(
              autofocus: widget.selectable,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: '店名・駅名・住所で検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '店舗情報は参考情報です',
                    style: TextStyle(
                      color: ChocoLogColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  tooltip: '最新情報に更新',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<StudioItem>>(
                future: _studios,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _StudioError(onRetry: _refresh);
                  }
                  final normalized = _query.trim().toLowerCase();
                  final matches = snapshot.requireData
                      .where((studio) {
                        if (normalized.isEmpty) {
                          return _favoriteIds.contains(studio.id);
                        }
                        return studio.name.toLowerCase().contains(normalized) ||
                            studio.address.toLowerCase().contains(normalized) ||
                            studio.access.toLowerCase().contains(normalized);
                      })
                      .take(100)
                      .toList();
                  if (matches.isEmpty) {
                    return Center(
                      child: Text(
                        normalized.isEmpty
                            ? '店名などを入力して検索してください'
                            : '該当する店舗がありません',
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final studio = matches[index];
                      final favorite = _favoriteIds.contains(studio.id);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        title: Text(studio.name),
                        subtitle: Text(
                          [
                            studio.address,
                            studio.access,
                          ].where((text) => text.isNotEmpty).join('\n'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: widget.selectable
                            ? () => Navigator.pop(context, studio)
                            : null,
                        trailing: IconButton(
                          tooltip: favorite ? 'お気に入りを解除' : 'よく行く店舗に追加',
                          icon: Icon(
                            favorite ? Icons.star : Icons.star_border,
                            color: favorite ? ChocoLogColors.ink : null,
                          ),
                          onPressed: () =>
                              _toggleFavorite(studio.id, !favorite),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<StudioItem>> _load({bool refresh = false}) async {
    final results = await Future.wait([
      StudioRepository.instance.load(forceRefresh: refresh),
      StudioRepository.instance.favoriteIds(),
    ]);
    _favoriteIds = results[1] as Set<String>;
    return results[0] as List<StudioItem>;
  }

  void _refresh() {
    setState(() => _studios = _load(refresh: true));
  }

  Future<void> _toggleFavorite(String id, bool favorite) async {
    await StudioRepository.instance.setFavorite(id, favorite);
    if (!mounted) return;
    setState(() {
      favorite ? _favoriteIds.add(id) : _favoriteIds.remove(id);
    });
  }
}

class _StudioError extends StatelessWidget {
  const _StudioError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('店舗情報を取得できませんでした\n店舗を選ばずに記録できます'),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
      ],
    ),
  );
}
