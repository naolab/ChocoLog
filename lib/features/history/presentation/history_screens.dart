import 'package:chocolog/app/theme.dart';
import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/core/widgets/chocolog_loading_indicator.dart';
import 'package:chocolog/features/equipment/presentation/equipment_image.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:chocolog/features/workout/presentation/workout_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<List<WorkoutSessionSummary>> _history;
  DateTime? _visibleMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _history = _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(workoutFlowControllerProvider, (previous, next) {
      if (previous != next && !next.isLoading) _reload();
    });
    final body = FutureBuilder<List<WorkoutSessionSummary>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: ChocoLogLoadingIndicator());
        }
        if (snapshot.hasError) {
          return _HistoryError(onRetry: _reload);
        }
        final sessions = snapshot.requireData;
        if (sessions.isEmpty) {
          return _EmptyHistory(onStart: () => context.push('/workout/studio'));
        }

        final latestDate = _localDate(sessions.first.session.startedAt);
        final visibleMonth =
            _visibleMonth ?? DateTime(latestDate.year, latestDate.month);
        final selectedDate = _selectedDate ?? latestDate;
        final selectedSessions = sessions
            .where(
              (summary) => _isSameDate(
                _localDate(summary.session.startedAt),
                selectedDate,
              ),
            )
            .toList();

        return ChocoLogRefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              _MonthCalendar(
                month: visibleMonth,
                selectedDate: selectedDate,
                recordedDates: {
                  for (final summary in sessions)
                    _localDate(summary.session.startedAt),
                },
                onPreviousMonth: () => _changeMonth(-1, visibleMonth),
                onNextMonth: () => _changeMonth(1, visibleMonth),
                onDateSelected: (date) {
                  setState(() => _selectedDate = date);
                },
              ),
              const SizedBox(height: 24),
              Text(
                '${selectedDate.month}月${selectedDate.day}日の記録',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (selectedSessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'この日の記録はありません',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ChocoLogColors.muted),
                  ),
                )
              else
                for (final summary in selectedSessions) ...[
                  _SessionCard(summary: summary, onChanged: _reload),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('履歴')),
      body: body,
    );
  }

  Future<List<WorkoutSessionSummary>> _loadHistory() {
    return ref.read(workoutRepositoryProvider).getCompletedSessionSummaries();
  }

  Future<void> _reload() async {
    final future = _loadHistory();
    setState(() {
      _history = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the retry state.
    }
  }

  void _changeMonth(int offset, DateTime current) {
    setState(() {
      final nextMonth = DateTime(current.year, current.month + offset);
      _visibleMonth = nextMonth;
      _selectedDate = nextMonth;
    });
  }
}

class HistoryDetailScreen extends ConsumerStatefulWidget {
  const HistoryDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<HistoryDetailScreen> createState() =>
      _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends ConsumerState<HistoryDetailScreen> {
  late Future<WorkoutSessionSummary> _summary;
  var _processing = false;

  @override
  void initState() {
    super.initState();
    _summary = ref
        .read(workoutRepositoryProvider)
        .getSessionSummary(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('トレーニング詳細')),
      body: FutureBuilder<WorkoutSessionSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: ChocoLogLoadingIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('記録を読み込めませんでした'));
          }
          final summary = snapshot.requireData;
          final startedAt = summary.session.startedAt.toLocal();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                '${startedAt.year}年${startedAt.month}月${startedAt.day}日',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                _sessionTotalLabel(summary),
                style: const TextStyle(color: ChocoLogColors.muted),
              ),
              if (summary.session.note != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(summary.session.note!),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              for (final exercise in summary.exercises) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EquipmentImage(
                          equipmentId: exercise.equipmentId,
                          size: 76,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exercise.equipmentName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              if (exercise.recordType == 'cardio')
                                Text(_cardioLabel(exercise))
                              else
                                for (final (index, set)
                                    in exercise.sets.indexed)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '${index + 1}セット目　${_setLabel(exercise, set)}',
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _processing ? null : _duplicate,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('このメニューを複製'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _processing ? null : _confirmDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('この記録を削除'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _duplicate() async {
    final active = await ref.read(workoutRepositoryProvider).getActiveSession();
    if (active != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('計測中の有酸素運動を先に終了してください')));
      return;
    }
    if (!mounted) return;
    setState(() => _processing = true);
    try {
      await ref
          .read(workoutFlowControllerProvider.notifier)
          .duplicate(widget.sessionId);
      if (mounted) context.go('/home');
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メニューを複製できませんでした')));
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('記録を削除しますか？'),
        content: const Text('削除した記録は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await ref
          .read(workoutRepositoryProvider)
          .deleteCompletedSession(widget.sessionId);
      if (mounted) context.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('記録を削除できませんでした')));
    }
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selectedDate,
    required this.recordedDates,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final Set<DateTime> recordedDates;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final firstWeekdayOffset = DateTime(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cellCount = ((firstWeekdayOffset + daysInMonth + 6) ~/ 7) * 7;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onPreviousMonth,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: '前の月',
                ),
                Expanded(
                  child: Text(
                    '${month.year}年${month.month}月',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: '次の月',
                ),
              ],
            ),
            Row(
              children: [
                for (final weekday in const ['月', '火', '水', '木', '金', '土', '日'])
                  Expanded(
                    child: Text(
                      weekday,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ChocoLogColors.muted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: cellCount,
              itemBuilder: (context, index) {
                final day = index - firstWeekdayOffset + 1;
                if (day < 1 || day > daysInMonth) return const SizedBox();
                final date = DateTime(month.year, month.month, day);
                final isSelected = _isSameDate(date, selectedDate);
                final hasRecord = recordedDates.contains(date);
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onDateSelected(date),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ChocoLogColors.yellow
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text('$day'),
                      ),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: hasRecord
                              ? ChocoLogColors.ink
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.summary, required this.onChanged});

  final WorkoutSessionSummary summary;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final equipmentNames = summary.exercises
        .map((exercise) => exercise.equipmentName)
        .join('・');
    return Card(
      child: ListTile(
        onTap: () async {
          final changed = await context.push<bool>(
            '/reports/history/${summary.session.id}',
          );
          if (changed == true) await onChanged();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: EquipmentImage(
          equipmentId: summary.exercises.first.equipmentId,
          size: 58,
        ),
        title: Text(_sessionTotalLabel(summary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(equipmentNames),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 52),
            const SizedBox(height: 16),
            Text(
              'トレーニングの記録がここに表示されます',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onStart, child: const Text('最初の記録を始める')),
          ],
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('履歴を読み込めませんでした'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
        ],
      ),
    );
  }
}

DateTime _localDate(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool _isSameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _setLabel(WorkoutExerciseSummary exercise, ExerciseSetValue set) {
  final metric = set.weightKg == null
      ? exercise.recordType == 'bodyweight'
            ? '自重'
            : '重量未設定'
      : '${set.weightKg}kg';
  return '$metric × ${set.reps}回';
}

String _sessionTotalLabel(WorkoutSessionSummary summary) {
  final parts = ['${summary.exercises.length}種目'];
  if (summary.totalSetCount > 0) parts.add('${summary.totalSetCount}セット');
  if (summary.totalCardioSeconds > 0) {
    parts.add(_durationLabel(summary.totalCardioSeconds));
  }
  return parts.join('・');
}

String _cardioLabel(WorkoutExerciseSummary exercise) {
  final duration = _durationLabel(exercise.durationSeconds ?? 0);
  return exercise.distanceKm == null
      ? duration
      : '$duration・${exercise.distanceKm}km';
}

String _durationLabel(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  if (minutes == 0) return '$remainder秒';
  if (remainder == 0) return '$minutes分';
  return '$minutes分$remainder秒';
}
