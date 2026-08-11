import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:chocolog/features/workout/presentation/workout_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key});

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  late Future<WorkoutSessionSummary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = ref.read(workoutFlowControllerProvider.notifier).summary();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(workoutFlowControllerProvider, (previous, next) {
      if (previous?.isLoading == true && next.hasValue) _reload();
    });
    return Scaffold(
      appBar: AppBar(title: const Text('今日の記録')),
      body: FutureBuilder(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _RetryView(onRetry: _reload);
          final summary = snapshot.requireData;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: summary.exercises.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final exercise = summary.exercises[index];
                      return Card(
                        child: ListTile(
                          title: Text(exercise.equipmentName),
                          subtitle: Text(_exerciseLabel(exercise)),
                          trailing: TextButton(
                            onPressed: () => _openExercise(exercise),
                            child: const Text('追加'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('別の器具を追加'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: summary.exercises.isEmpty
                      ? null
                      : () => context.push('/workout/review'),
                  child: const Text('トレーニングを終了'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _reload() {
    setState(() {
      _summary = ref.read(workoutFlowControllerProvider.notifier).summary();
    });
  }

  Future<void> _addExercise() async {
    await context.push('/workout/equipment');
    if (mounted) _reload();
  }

  Future<void> _openExercise(WorkoutExerciseSummary exercise) async {
    final type = switch (exercise.recordType) {
      'cardio' => 'cardio',
      'bodyweight' => 'bodyweight',
      _ => 'strength',
    };
    await context.push('/workout/$type/${exercise.equipmentId}');
    if (mounted) _reload();
  }
}

class WorkoutReviewScreen extends ConsumerStatefulWidget {
  const WorkoutReviewScreen({super.key});

  @override
  ConsumerState<WorkoutReviewScreen> createState() =>
      _WorkoutReviewScreenState();
}

class _WorkoutReviewScreenState extends ConsumerState<WorkoutReviewScreen> {
  late Future<WorkoutSessionSummary> _summary;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _summary = ref.read(workoutFlowControllerProvider.notifier).summary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('記録を確認')),
      body: FutureBuilder(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _RetryView(
              onRetry: () => setState(() {
                _summary = ref
                    .read(workoutFlowControllerProvider.notifier)
                    .summary();
              }),
            );
          }
          final summary = snapshot.requireData;
          final hasUnfinishedCardio = summary.exercises.any(
            (exercise) =>
                exercise.recordType == 'cardio' &&
                exercise.timerStatus != 'completed',
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      for (final exercise in summary.exercises)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(exercise.equipmentName),
                          subtitle: Text(_exerciseLabel(exercise)),
                        ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('合計'),
                        trailing: Text(_sessionTotalLabel(summary)),
                      ),
                      if (hasUnfinishedCardio)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '計測中の有酸素タイマーを終了してください',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _saving || hasUnfinishedCardio ? null : _complete,
                  child: Text(_saving ? '保存中…' : '完了'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _complete() async {
    setState(() => _saving = true);
    try {
      final sessionId = await ref
          .read(workoutFlowControllerProvider.notifier)
          .complete();
      if (mounted) context.go('/workout/complete/$sessionId');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('記録を完了できませんでした')));
    }
  }
}

class WorkoutCompleteScreen extends ConsumerWidget {
  const WorkoutCompleteScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('完了')),
      body: FutureBuilder(
        future: ref
            .read(workoutRepositoryProvider)
            .getSessionSummary(sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('結果を読み込めませんでした'));
          }
          final summary = snapshot.requireData;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(Icons.check_circle, size: 72),
                const SizedBox(height: 20),
                Text(
                  'トレーニング完了！',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                Text(
                  _sessionTotalLabel(summary),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('ホームへ戻る'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('記録を読み込めませんでした'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
        ],
      ),
    );
  }
}

String _exerciseLabel(WorkoutExerciseSummary exercise) {
  if (exercise.recordType == 'cardio') {
    if (exercise.timerStatus != 'completed') {
      return exercise.timerStatus == 'paused' ? '一時停止中' : '計測中';
    }
    final duration = _durationLabel(exercise.durationSeconds ?? 0);
    return exercise.distanceKm == null
        ? duration
        : '$duration・${exercise.distanceKm}km';
  }
  if (exercise.sets.isEmpty) return 'セットなし';
  final labels = exercise.sets.map((set) {
    final metric = set.weightKg == null
        ? exercise.recordType == 'bodyweight'
              ? '自重'
              : '重量未設定'
        : '${set.weightKg}kg';
    return '$metric × ${set.reps}回';
  }).toList();
  if (labels.toSet().length == 1) {
    return '${labels.first} × ${labels.length}セット';
  }
  return labels.indexed
      .map((entry) => '${entry.$1 + 1}. ${entry.$2}')
      .join(' / ');
}

String _sessionTotalLabel(WorkoutSessionSummary summary) {
  final parts = ['${summary.exercises.length}種目'];
  if (summary.totalSetCount > 0) parts.add('${summary.totalSetCount}セット');
  if (summary.totalCardioSeconds > 0) {
    parts.add(_durationLabel(summary.totalCardioSeconds));
  }
  return parts.join('・');
}

String _durationLabel(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  if (minutes == 0) return '$remainder秒';
  if (remainder == 0) return '$minutes分';
  return '$minutes分$remainder秒';
}
