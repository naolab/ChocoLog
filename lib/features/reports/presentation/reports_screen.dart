import 'package:chocolog/app/theme.dart';
import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/equipment/presentation/equipment_image.dart';
import 'package:chocolog/features/history/presentation/history_screens.dart';
import 'package:chocolog/features/onboarding/data/onboarding_preferences.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:chocolog/features/workout/presentation/workout_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _ReportPeriod { week, month }

enum _ReportSection { history, analysis }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key, required this.preferences});

  final OnboardingPreferences preferences;

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late Future<List<WorkoutSessionSummary>> _history;
  var _section = _ReportSection.history;
  var _period = _ReportPeriod.week;

  @override
  void initState() {
    super.initState();
    _history = _load();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(workoutFlowControllerProvider, (previous, next) {
      if (previous != next && !next.isLoading) _reload();
    });
    return Scaffold(
      appBar: AppBar(title: const Text('レポート')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_ReportSection>(
                segments: const [
                  ButtonSegment(
                    value: _ReportSection.history,
                    icon: Icon(Icons.calendar_month_outlined),
                    label: Text('履歴'),
                  ),
                  ButtonSegment(
                    value: _ReportSection.analysis,
                    icon: Icon(Icons.bar_chart_outlined),
                    label: Text('分析'),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (selection) {
                  setState(() => _section = selection.single);
                },
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _section.index,
              children: [const HistoryScreen(embedded: true), _buildAnalysis()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysis() {
    return FutureBuilder<List<WorkoutSessionSummary>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ReportError(onRetry: _reload);
        }
        final report = _ReportData.create(
          history: snapshot.requireData,
          period: _period,
        );
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              SegmentedButton<_ReportPeriod>(
                segments: const [
                  ButtonSegment(value: _ReportPeriod.week, label: Text('週')),
                  ButtonSegment(value: _ReportPeriod.month, label: Text('月')),
                ],
                selected: {_period},
                onSelectionChanged: (selection) {
                  setState(() => _period = selection.single);
                },
              ),
              const SizedBox(height: 18),
              Text(
                report.periodLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ChocoLogColors.muted),
              ),
              const SizedBox(height: 14),
              if (report.sessions.isEmpty)
                _EmptyReport(onStart: () => context.push('/workout/studio'))
              else ...[
                ListenableBuilder(
                  listenable: widget.preferences,
                  builder: (context, _) => _SummaryCard(
                    report: report,
                    weeklyTarget: widget.preferences.weeklyTarget,
                  ),
                ),
                const SizedBox(height: 24),
                Text('運動した日', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                _ActivityChart(report: report),
                const SizedBox(height: 24),
                Text('よく使った器具', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                for (final (index, equipment) in report.equipment.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EquipmentCard(
                      rank: index + 1,
                      equipment: equipment,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<List<WorkoutSessionSummary>> _load() =>
      ref.read(workoutRepositoryProvider).getCompletedSessionSummaries();

  Future<void> _reload() async {
    final history = _load();
    setState(() {
      _history = history;
    });
    await history;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report, required this.weeklyTarget});

  final _ReportData report;
  final int weeklyTarget;

  @override
  Widget build(BuildContext context) {
    final targetLabel = report.period == _ReportPeriod.week
        ? ' / $weeklyTarget回'
        : '回';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _Metric(
              label: '運動',
              value: '${report.sessions.length}$targetLabel',
            ),
            _Metric(label: '筋トレ', value: '${report.totalSets}セット'),
            _Metric(label: '有酸素', value: '${report.cardioMinutes}分'),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: ChocoLogColors.muted)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.report});

  final _ReportData report;

  @override
  Widget build(BuildContext context) {
    final points = report.chartPoints;
    final maximum = points.fold(1, (value, point) {
      return point.count > value ? point.count : value;
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${report.activeDayCount}日運動しました',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '棒の高さは1日の記録回数です',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ChocoLogColors.muted),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 156,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final point in points)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (point.count > 0)
                              Text(
                                '${point.count}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              height: point.count == 0
                                  ? 6
                                  : 92 * point.count / maximum + 12,
                              decoration: BoxDecoration(
                                color: point.count == 0
                                    ? ChocoLogColors.border
                                    : ChocoLogColors.yellow,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                border: Border.all(
                                  color: point.count == 0
                                      ? ChocoLogColors.border
                                      : ChocoLogColors.ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              point.label,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({required this.rank, required this.equipment});

  final int rank;
  final _EquipmentReport equipment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            EquipmentImage(equipmentId: equipment.id, size: 58),
            Positioned(
              left: -6,
              top: -6,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: ChocoLogColors.yellow,
                foregroundColor: ChocoLogColors.ink,
                child: Text('$rank'),
              ),
            ),
          ],
        ),
        title: Text(equipment.name),
        subtitle: Text(equipment.performanceLabel),
        trailing: Text('${equipment.usageCount}回'),
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.bar_chart_outlined, size: 44),
            const SizedBox(height: 12),
            const Text('この期間の記録はありません'),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onStart, child: const Text('記録を始める')),
          ],
        ),
      ),
    );
  }
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: OutlinedButton(onPressed: onRetry, child: const Text('再読み込み')),
  );
}

class _ReportData {
  const _ReportData({
    required this.period,
    required this.start,
    required this.end,
    required this.sessions,
    required this.equipment,
  });

  final _ReportPeriod period;
  final DateTime start;
  final DateTime end;
  final List<WorkoutSessionSummary> sessions;
  final List<_EquipmentReport> equipment;

  int get totalSets =>
      sessions.fold(0, (sum, item) => sum + item.totalSetCount);
  int get cardioMinutes =>
      sessions.fold(0, (sum, item) => sum + item.totalCardioSeconds) ~/ 60;
  int get activeDayCount =>
      chartPoints.where((point) => point.count > 0).length;
  List<_ChartPoint> get chartPoints {
    final sessionCounts = <DateTime, int>{};
    for (final summary in sessions) {
      final local = summary.session.startedAt.toLocal();
      final date = DateTime(local.year, local.month, local.day);
      sessionCounts.update(date, (count) => count + 1, ifAbsent: () => 1);
    }
    if (period == _ReportPeriod.week) {
      const labels = ['月', '火', '水', '木', '金', '土', '日'];
      return [
        for (var index = 0; index < 7; index++)
          _ChartPoint(
            label: labels[index],
            count: sessionCounts[start.add(Duration(days: index))] ?? 0,
          ),
      ];
    }
    final points = <_ChartPoint>[];
    for (var day = 1; day <= end.day; day += 5) {
      final rangeEnd = (day + 4).clamp(1, end.day);
      var count = 0;
      for (var current = day; current <= rangeEnd; current++) {
        count += sessionCounts[DateTime(start.year, start.month, current)] ?? 0;
      }
      points.add(_ChartPoint(label: '$day', count: count));
    }
    return points;
  }

  String get periodLabel => period == _ReportPeriod.week
      ? '${start.month}月${start.day}日〜${end.month}月${end.day}日'
      : '${start.year}年${start.month}月';

  factory _ReportData.create({
    required List<WorkoutSessionSummary> history,
    required _ReportPeriod period,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = period == _ReportPeriod.week
        ? today.subtract(Duration(days: today.weekday - 1))
        : DateTime(today.year, today.month);
    final end = period == _ReportPeriod.week
        ? start.add(const Duration(days: 6))
        : DateTime(today.year, today.month + 1, 0);
    final sessions = history.where((summary) {
      final local = summary.session.startedAt.toLocal();
      final date = DateTime(local.year, local.month, local.day);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    final byEquipment = <String, List<WorkoutExerciseSummary>>{};
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        byEquipment.putIfAbsent(exercise.equipmentId, () => []).add(exercise);
      }
    }
    final equipment = [
      for (final entry in byEquipment.entries)
        _EquipmentReport(
          id: entry.key,
          name: entry.value.first.equipmentName,
          records: entry.value,
        ),
    ]..sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return _ReportData(
      period: period,
      start: start,
      end: end,
      sessions: sessions,
      equipment: equipment,
    );
  }
}

class _ChartPoint {
  const _ChartPoint({required this.label, required this.count});

  final String label;
  final int count;
}

class _EquipmentReport {
  const _EquipmentReport({
    required this.id,
    required this.name,
    required this.records,
  });

  final String id;
  final String name;
  final List<WorkoutExerciseSummary> records;

  int get usageCount => records.length;
  String get performanceLabel {
    final cardioSeconds = records.fold(
      0,
      (sum, record) => sum + (record.durationSeconds ?? 0),
    );
    if (cardioSeconds > 0) return '累計 ${cardioSeconds ~/ 60}分';
    final sets = records.expand((record) => record.sets).toList();
    final weights = sets.map((set) => set.weightKg).whereType<int>();
    final maximum = weights.isEmpty
        ? null
        : weights.reduce((a, b) => a > b ? a : b);
    return maximum == null
        ? '合計 ${sets.length}セット'
        : '合計 ${sets.length}セット・最大 ${maximum}kg';
  }
}
