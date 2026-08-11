import 'package:chocolog/app/theme.dart';
import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:chocolog/features/workout/presentation/workout_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<_HomeData> _data;

  @override
  void initState() {
    super.initState();
    _data = _loadData();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(workoutFlowControllerProvider, (previous, next) {
      if (previous != next && !next.isLoading) _reload();
    });
    return Scaffold(
      appBar: AppBar(title: const Text('今日のトレーニング')),
      body: SafeArea(
        child: FutureBuilder<_HomeData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return _HomeError(onRetry: _reload);
            final data = snapshot.requireData;
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  if (data.activeSession == null)
                    _StartWorkoutCard(
                      onStart: () => context.push('/workout/studio'),
                    )
                  else
                    _ActiveWorkoutCard(
                      summary: data.activeSession!,
                      onContinue: () => context.push('/workout/session'),
                      onAdd: () => context.push('/workout/equipment'),
                    ),
                  const SizedBox(height: 28),
                  Text('今日の記録', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (data.completedToday.isEmpty)
                    const _EmptyTodayCard()
                  else
                    for (final summary in data.completedToday) ...[
                      _TodaySessionCard(summary: summary, onChanged: _reload),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<_HomeData> _loadData() async {
    final repository = ref.read(workoutRepositoryProvider);
    final active = await repository.getActiveSession();
    final history = await repository.getCompletedSessionSummaries();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedToday = history.where((summary) {
      final startedAt = summary.session.startedAt.toLocal();
      return DateTime(startedAt.year, startedAt.month, startedAt.day) == today;
    }).toList();
    return _HomeData(
      activeSession: active == null
          ? null
          : await repository.getSessionSummary(active.id),
      completedToday: completedToday,
    );
  }

  Future<void> _reload() async {
    final future = _loadData();
    if (mounted) {
      setState(() {
        _data = future;
      });
    }
    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the retry state.
    }
  }
}

class _HomeData {
  const _HomeData({required this.activeSession, required this.completedToday});

  final WorkoutSessionSummary? activeSession;
  final List<WorkoutSessionSummary> completedToday;
}

class _StartWorkoutCard extends StatelessWidget {
  const _StartWorkoutCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.fitness_center, size: 44),
            const SizedBox(height: 14),
            Text(
              '今日も記録を始めましょう',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onStart, child: const Text('トレーニングを始める')),
          ],
        ),
      ),
    );
  }
}

class _ActiveWorkoutCard extends StatelessWidget {
  const _ActiveWorkoutCard({
    required this.summary,
    required this.onContinue,
    required this.onAdd,
  });

  final WorkoutSessionSummary summary;
  final VoidCallback onContinue;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.play_circle_fill),
                const SizedBox(width: 8),
                Text(
                  '進行中のトレーニング',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (summary.exercises.isEmpty)
              const Text(
                'まだ器具は記録されていません',
                style: TextStyle(color: ChocoLogColors.muted),
              )
            else ...[
              Text(_summaryLabel(summary)),
              const SizedBox(height: 8),
              for (final exercise in summary.exercises)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('・${exercise.equipmentName}'),
                ),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: onContinue, child: const Text('記録を続ける')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('器具を追加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaySessionCard extends StatelessWidget {
  const _TodaySessionCard({required this.summary, required this.onChanged});

  final WorkoutSessionSummary summary;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final startedAt = summary.session.startedAt.toLocal();
    return Card(
      child: ListTile(
        onTap: () async {
          final changed = await context.push<bool>(
            '/reports/history/${summary.session.id}',
          );
          if (changed == true) await onChanged();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        title: Text(
          '${_twoDigits(startedAt.hour)}:${_twoDigits(startedAt.minute)}　'
          '${_summaryLabel(summary)}',
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            summary.exercises.isEmpty
                ? '種目の記録なし'
                : summary.exercises
                      .map((exercise) => exercise.equipmentName)
                      .join('・'),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _EmptyTodayCard extends StatelessWidget {
  const _EmptyTodayCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          '完了したトレーニングはまだありません',
          style: TextStyle(color: ChocoLogColors.muted),
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('ホームを読み込めませんでした'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
        ],
      ),
    );
  }
}

String _summaryLabel(WorkoutSessionSummary summary) {
  final parts = ['${summary.exercises.length}種目'];
  if (summary.totalSetCount > 0) parts.add('${summary.totalSetCount}セット');
  if (summary.totalCardioSeconds > 0) {
    final minutes = summary.totalCardioSeconds ~/ 60;
    parts.add(minutes > 0 ? '$minutes分' : '${summary.totalCardioSeconds}秒');
  }
  return parts.join('・');
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
