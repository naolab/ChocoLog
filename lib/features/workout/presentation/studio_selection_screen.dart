import 'package:chocolog/app/theme.dart';
import 'package:chocolog/features/studios/data/studio_repository.dart';
import 'package:chocolog/features/workout/presentation/workout_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StudioSelectionScreen extends ConsumerStatefulWidget {
  const StudioSelectionScreen({super.key});

  @override
  ConsumerState<StudioSelectionScreen> createState() =>
      _StudioSelectionScreenState();
}

class _StudioSelectionScreenState extends ConsumerState<StudioSelectionScreen> {
  late Future<List<StudioItem>> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = StudioRepository.instance.favorites();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutFlowControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('今回の店舗')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              readOnly: true,
              onTap: session.isLoading ? null : _search,
              decoration: const InputDecoration(
                hintText: '店名・駅名で検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text('よく行く店舗', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<StudioItem>>(
                future: _favorites,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || snapshot.requireData.isEmpty) {
                    return const Center(
                      child: Text(
                        '登録した店舗がありません\n上の検索から追加できます',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ChocoLogColors.muted),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: snapshot.requireData.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final studio = snapshot.requireData[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(studio.name),
                        subtitle: Text(studio.access),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: session.isLoading ? null : () => _start(studio),
                      );
                    },
                  );
                },
              ),
            ),
            TextButton(
              onPressed: session.isLoading ? null : () => _start(null),
              child: const Text('店舗を選ばずに続ける'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _search() async {
    final studio = await context.push<StudioItem>('/workout/studio/search');
    if (studio != null && mounted) await _start(studio);
  }

  Future<void> _start(StudioItem? studio) async {
    try {
      await ref
          .read(workoutFlowControllerProvider.notifier)
          .ensureSession(studioId: studio?.id);
      if (mounted) await context.push('/workout/equipment');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('トレーニングを開始できませんでした')));
    }
  }
}
