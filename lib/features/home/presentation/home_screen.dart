import 'dart:math' as math;

import 'package:chocolog/app/theme.dart';
import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:chocolog/features/workout/presentation/workout_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.weeklyTarget});

  final int weeklyTarget;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<_HomeData> _data;
  var _duplicating = false;

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
      appBar: AppBar(title: const Text('ChocoLog')),
      body: SafeArea(
        child: FutureBuilder<_HomeData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _HomeError(onRetry: _reload);
            }
            final data = snapshot.requireData;
            final progress = widget.weeklyTarget == 0
                ? 0.0
                : math.min(data.weeklyCount / widget.weeklyTarget, 1.0);
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    'こんにちは',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '今週 ${data.weeklyCount} / ${widget.weeklyTarget}回',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 10),
                          Text(
                            _progressMessage(
                              data.weeklyCount,
                              widget.weeklyTarget,
                            ),
                            style: const TextStyle(color: ChocoLogColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.push(
                      data.activeSession == null
                          ? '/workout/studio'
                          : '/workout/session',
                    ),
                    child: Text(
                      data.activeSession == null ? 'トレーニングを始める' : 'トレーニングを続ける',
                    ),
                  ),
                  if (data.activeSession != null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '保存途中のトレーニングがあります',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ChocoLogColors.muted),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    '前回のメニュー',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (data.previousSession == null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'まだ記録がありません',
                          style: TextStyle(color: ChocoLogColors.muted),
                        ),
                      ),
                    )
                  else
                    _PreviousWorkoutCard(
                      summary: data.previousSession!,
                      canDuplicate: data.activeSession == null,
                      duplicating: _duplicating,
                      onDuplicate: () =>
                          _duplicate(data.previousSession!.session.id),
                    ),
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
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weeklyCount = history.where((summary) {
      final startedAt = summary.session.startedAt.toLocal();
      final date = DateTime(startedAt.year, startedAt.month, startedAt.day);
      return !date.isBefore(weekStart) && !date.isAfter(today);
    }).length;
    return _HomeData(
      activeSession: active,
      previousSession: history.firstOrNull,
      weeklyCount: weeklyCount,
    );
  }

  Future<void> _reload() async {
    final future = _loadData();
    if (mounted) {
      setState(() {
        _data = future;
        _duplicating = false;
      });
    }
    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the retry state.
    }
  }

  Future<void> _duplicate(String sourceSessionId) async {
    setState(() => _duplicating = true);
    try {
      await ref
          .read(workoutFlowControllerProvider.notifier)
          .duplicate(sourceSessionId);
      if (mounted) context.push('/workout/session');
    } catch (_) {
      if (!mounted) return;
      setState(() => _duplicating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('前回のメニューを開始できませんでした')));
    }
  }
}

class _HomeData {
  const _HomeData({
    required this.activeSession,
    required this.previousSession,
    required this.weeklyCount,
  });

  final WorkoutSessionSnapshot? activeSession;
  final WorkoutSessionSummary? previousSession;
  final int weeklyCount;
}

class _PreviousWorkoutCard extends StatelessWidget {
  const _PreviousWorkoutCard({
    required this.summary,
    required this.canDuplicate,
    required this.duplicating,
    required this.onDuplicate,
  });

  final WorkoutSessionSummary summary;
  final bool canDuplicate;
  final bool duplicating;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final startedAt = summary.session.startedAt.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${startedAt.month}月${startedAt.day}日・'
              '${_summaryLabel(summary)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            for (final exercise in summary.exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('・${exercise.equipmentName}'),
              ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: canDuplicate && !duplicating ? onDuplicate : null,
              icon: const Icon(Icons.replay),
              label: Text(
                canDuplicate
                    ? duplicating
                          ? '準備中…'
                          : 'このメニューでもう一度'
                    : '進行中の記録を先に完了してください',
              ),
            ),
          ],
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

String _progressMessage(int count, int target) {
  if (count >= target) return '今週の目標を達成しました！';
  if (count == 0) return '最初のトレーニングを記録しましょう';
  return 'あと${target - count}回で今週の目標達成です';
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
