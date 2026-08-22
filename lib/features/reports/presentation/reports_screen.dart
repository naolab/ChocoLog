import 'package:chocolog/app/theme.dart';
import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/core/widgets/chocolog_loading_indicator.dart';
import 'package:chocolog/features/account/data/supabase_auth_repository.dart';
import 'package:chocolog/features/equipment/presentation/equipment_image.dart';
import 'package:chocolog/features/friends/data/supabase_friends_repository.dart';
import 'package:chocolog/features/history/data/supabase_friend_history_repository.dart';
import 'package:chocolog/features/history/presentation/history_screens.dart';
import 'package:chocolog/features/onboarding/data/onboarding_preferences.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:chocolog/features/workout/presentation/workout_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _ReportPeriod { week, month }

enum _ReportSection { history, analysis }

enum _ActivityMetric { strength, cardio }

const _chartColors = [
  ChocoLogColors.yellow,
  Color(0xFF27A8E8),
  Color(0xFF24B883),
  Color(0xFFEF73AC),
  Color(0xFFF26A4F),
  Color(0xFF5CC9F5),
  Color(0xFFF5B82E),
  Color(0xFF7969D8),
  Color(0xFF4BC5AE),
  Color(0xFFA5B943),
  Color(0xFFE48591),
  Color(0xFFC66BC4),
];

/// The catalog order is also the vertical stacking order in the daily chart.
/// Keeping it independent of a day's record order makes every color and segment
/// land in the same place throughout the report.
const _chartEquipmentOrder = [
  'shoulder-press',
  'chest-press',
  'lat-pulldown',
  'biceps-curl',
  'dips',
  'abdominal-trainer',
  'ab-bench',
  'leg-press',
  'adduction',
  'abduction',
  'treadmill',
  'bike',
];

int _chartEquipmentIndex(String equipmentId) {
  final index = _chartEquipmentOrder.indexOf(equipmentId);
  return index < 0 ? _chartEquipmentOrder.length : index;
}

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
  var _activityMetric = _ActivityMetric.strength;
  DateTime? _selectedChartDate;
  late DateTime _periodAnchor;
  Future<FriendsSnapshot>? _friendsFuture;
  String? _selectedFriendId;

  @override
  void initState() {
    super.initState();
    _history = _load();
    _periodAnchor = _dateOnly(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(workoutFlowControllerProvider, (previous, next) {
      if (previous != next && !next.isLoading) _reload();
    });
    final session = ref.watch(supabaseSessionProvider).valueOrNull;
    if (session != null && _friendsFuture == null) {
      _friendsFuture = ref.read(supabaseFriendsRepositoryProvider).load();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 25),
            SizedBox(width: 8),
            Text('レポート'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (session != null) _buildOwnerPicker(),
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
              children: [
                HistoryScreen(
                  key: ValueKey('history-owner-$_selectedFriendId'),
                  embedded: true,
                  ownerId: _selectedFriendId,
                ),
                _buildAnalysis(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerPicker() {
    return FutureBuilder<FriendsSnapshot>(
      future: _friendsFuture,
      builder: (context, snapshot) {
        final friends = snapshot.data?.friends ?? const <Friendship>[];
        if (friends.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedFriendId ?? 'self',
            decoration: const InputDecoration(
              labelText: '表示する履歴',
              prefixIcon: Icon(Icons.people_alt_outlined),
            ),
            items: [
              const DropdownMenuItem(value: 'self', child: Text('自分の履歴')),
              for (final friend in friends)
                DropdownMenuItem(
                  value: friend.profile.userId,
                  child: Text('${friend.profile.displayName}さんの履歴'),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedFriendId = value == 'self' ? null : value;
                _history = _load();
                _selectedChartDate = null;
                _periodAnchor = _dateOnly(DateTime.now());
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildAnalysis() {
    return FutureBuilder<List<WorkoutSessionSummary>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: ChocoLogLoadingIndicator());
        }
        if (snapshot.hasError) {
          return _ReportError(onRetry: _reload);
        }
        final report = _ReportData.create(
          history: snapshot.requireData,
          period: _period,
          anchor: _periodAnchor,
        );
        return ChocoLogRefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            key: const ValueKey('analysis-list'),
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
                  setState(() {
                    _period = selection.single;
                    _periodAnchor = _dateOnly(DateTime.now());
                    _selectedChartDate = null;
                  });
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  IconButton(
                    tooltip: _period == _ReportPeriod.week ? '前の週' : '前の月',
                    onPressed: _canGoPreviousPeriod(snapshot.requireData)
                        ? () => _changePeriod(-1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      report.periodLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ChocoLogColors.muted),
                    ),
                  ),
                  IconButton(
                    tooltip: _period == _ReportPeriod.week ? '次の週' : '次の月',
                    onPressed: _isCurrentPeriod ? null : () => _changePeriod(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
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
                _ReportSectionTitle(
                  icon: Icons.bar_chart_rounded,
                  label: '日ごとの運動量',
                ),
                const SizedBox(height: 10),
                _ActivityChart(
                  report: report,
                  metric: _activityMetric,
                  selectedDate: _selectedChartDate,
                  onMetricChanged: (metric) => setState(() {
                    _activityMetric = metric;
                    _selectedChartDate = null;
                  }),
                  onDateSelected: (date) =>
                      setState(() => _selectedChartDate = date),
                ),
                const SizedBox(height: 24),
                _ReportSectionTitle(
                  icon: Icons.workspace_premium_rounded,
                  label: 'よく使った器具',
                ),
                const SizedBox(height: 10),
                if (report.strengthEquipment.isNotEmpty) ...[
                  Text(
                    '筋トレ（セット数順）',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final (index, equipment)
                      in report.strengthEquipment.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EquipmentCard(
                        rank: index + 1,
                        equipment: equipment,
                        trailing: '${equipment.totalSets}セット',
                      ),
                    ),
                ],
                if (report.cardioEquipment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '有酸素（時間順）',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final (index, equipment)
                      in report.cardioEquipment.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EquipmentCard(
                        rank: index + 1,
                        equipment: equipment,
                        trailing: '${equipment.cardioMinutes}分',
                      ),
                    ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Future<List<WorkoutSessionSummary>> _load() {
    if (_selectedFriendId != null) {
      return ref
          .read(supabaseFriendHistoryRepositoryProvider)
          .load(_selectedFriendId!);
    }
    return ref.read(workoutRepositoryProvider).getCompletedSessionSummaries();
  }

  Future<void> _reload() async {
    final history = _load();
    setState(() {
      _history = history;
    });
    await history;
  }

  bool get _isCurrentPeriod {
    final today = _dateOnly(DateTime.now());
    if (_period == _ReportPeriod.week) return !_periodAnchor.isBefore(today);
    return _periodAnchor.year == today.year &&
        _periodAnchor.month == today.month;
  }

  bool _canGoPreviousPeriod(List<WorkoutSessionSummary> history) {
    if (history.isEmpty) return false;
    final earliestRecord = _dateOnly(history.last.session.startedAt);
    if (_period == _ReportPeriod.week) {
      final previousWeekEnd = _periodAnchor.subtract(const Duration(days: 7));
      return !previousWeekEnd.isBefore(earliestRecord);
    }
    final previousMonth = DateTime(_periodAnchor.year, _periodAnchor.month - 1);
    final earliestMonth = DateTime(earliestRecord.year, earliestRecord.month);
    return !previousMonth.isBefore(earliestMonth);
  }

  void _changePeriod(int offset) {
    setState(() {
      _periodAnchor = _period == _ReportPeriod.week
          ? _periodAnchor.add(Duration(days: 7 * offset))
          : DateTime(_periodAnchor.year, _periodAnchor.month + offset, 1);
      _selectedChartDate = null;
    });
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report, required this.weeklyTarget});

  final _ReportData report;
  final int weeklyTarget;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('概要', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                _Metric(label: 'トレーニング', value: '${report.activeDayCount}日'),
                _Metric(label: '合計セット', value: '${report.totalSets}セット'),
                _Metric(label: '有酸素', value: '${report.cardioMinutes}分'),
              ],
            ),
            const SizedBox(height: 18),
            _GoalStatus(report: report, weeklyTarget: weeklyTarget),
          ],
        ),
      ),
    );
  }
}

class _GoalStatus extends StatelessWidget {
  const _GoalStatus({required this.report, required this.weeklyTarget});

  final _ReportData report;
  final int weeklyTarget;

  @override
  Widget build(BuildContext context) {
    final weeklyAchieved = report.activeDayCount >= weeklyTarget;
    final achievedWeeks = report.achievedWeekCount(weeklyTarget);
    final title = report.period == _ReportPeriod.week
        ? weeklyAchieved
              ? '今週の目標を達成！'
              : '目標まであと${weeklyTarget - report.activeDayCount}回'
        : '週目標を達成した週 $achievedWeeks週';
    final detail = report.period == _ReportPeriod.week
        ? '週$weeklyTarget回の目標'
        : '週$weeklyTarget回の目標';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ChocoLogColors.softYellow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            report.period == _ReportPeriod.week && !weeklyAchieved
                ? Icons.flag_outlined
                : Icons.check_circle,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: ChocoLogColors.muted),
                ),
              ],
            ),
          ),
        ],
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

class _ReportSectionTitle extends StatelessWidget {
  const _ReportSectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: ChocoLogColors.ink, size: 25),
      const SizedBox(width: 9),
      Text(label, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({
    required this.report,
    required this.metric,
    required this.selectedDate,
    required this.onMetricChanged,
    required this.onDateSelected,
  });

  final _ReportData report;
  final _ActivityMetric metric;
  final DateTime? selectedDate;
  final ValueChanged<_ActivityMetric> onMetricChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final points = report.chartPoints(metric);
    final maximum = points.fold(1, (value, point) {
      return point.total > value ? point.total : value;
    });
    final selectedPoint = selectedDate == null
        ? null
        : points
              .where((point) => _sameDay(point.date, selectedDate!))
              .firstOrNull;
    final visibleEquipment = <String, _DailyEquipmentValue>{};
    for (final point in points) {
      for (final item in point.equipment) {
        visibleEquipment[item.id] = item;
      }
    }
    Color colorForEquipment(String equipmentId) {
      return _chartColors[_chartEquipmentIndex(equipmentId) %
          _chartColors.length];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_ActivityMetric>(
                segments: const [
                  ButtonSegment(
                    value: _ActivityMetric.strength,
                    label: Text('筋トレ'),
                  ),
                  ButtonSegment(
                    value: _ActivityMetric.cardio,
                    label: Text('有酸素'),
                  ),
                ],
                selected: {metric},
                onSelectionChanged: (value) => onMetricChanged(value.first),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              metric == _ActivityMetric.strength
                  ? '器具ごとのセット数を日別に表示'
                  : '器具ごとの運動時間を日別に表示',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ChocoLogColors.muted),
            ),
            if (visibleEquipment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final item
                      in visibleEquipment.values.toList()..sort(
                        (first, second) => _chartEquipmentIndex(
                          first.id,
                        ).compareTo(_chartEquipmentIndex(second.id)),
                      ))
                    _ChartLegendItem(
                      name: item.name,
                      color: colorForEquipment(item.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: report.period == _ReportPeriod.month,
              child: SizedBox(
                width: report.period == _ReportPeriod.week
                    ? MediaQuery.sizeOf(context).width - 72
                    : points.length * 42,
                height: 184,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final point in points)
                      SizedBox(
                        width: report.period == _ReportPeriod.week
                            ? (MediaQuery.sizeOf(context).width - 72) / 7
                            : 42,
                        child: _ChartBar(
                          point: point,
                          maximum: maximum,
                          unit: metric == _ActivityMetric.strength
                              ? 'セット'
                              : '分',
                          colorForEquipment: colorForEquipment,
                          selected:
                              selectedDate != null &&
                              _sameDay(point.date, selectedDate!),
                          dimmed:
                              selectedDate != null &&
                              !_sameDay(point.date, selectedDate!),
                          onTap: () => onDateSelected(point.date),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (selectedPoint != null) ...[
              const Divider(height: 28),
              _SelectedDayDetails(point: selectedPoint, metric: metric),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: ValueKey('chart-legend-$name'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(name, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({
    required this.point,
    required this.maximum,
    required this.unit,
    required this.colorForEquipment,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final _ChartPoint point;
  final int maximum;
  final String unit;
  final Color Function(String equipmentId) colorForEquipment;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('analysis-day-${point.date.toIso8601String()}'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Column(
          children: [
            SizedBox(
              height: 20,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: point.total == 0
                    ? null
                    : Text(
                        '${point.total}$unit',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedOpacity(
                  key: ValueKey(
                    'analysis-opacity-${point.date.toIso8601String()}',
                  ),
                  opacity: dimmed ? 0.38 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    key: ValueKey(
                      'analysis-bar-${point.date.toIso8601String()}-${point.total}',
                    ),
                    height: point.total == 0
                        ? 6
                        : 100 * point.total / maximum + 10,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: point.total == 0
                          ? ChocoLogColors.border
                          : ChocoLogColors.surface,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: point.total == 0
                        ? null
                        : SizedBox.expand(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final item in point.equipment)
                                  Expanded(
                                    flex: item.value,
                                    child: ColoredBox(
                                      color: colorForEquipment(item.id),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 22,
              child: Center(
                child: AnimatedContainer(
                  key: ValueKey(
                    'analysis-date-label-${point.date.toIso8601String()}',
                  ),
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? ChocoLogColors.softYellow
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    point.label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDayDetails extends StatelessWidget {
  const _SelectedDayDetails({required this.point, required this.metric});

  final _ChartPoint point;
  final _ActivityMetric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${point.date.month}月${point.date.day}日の記録',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        if (point.equipment.isEmpty)
          const Text('この日の記録はありません')
        else
          for (final item in point.equipment)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  EquipmentImage(equipmentId: item.id, size: 42),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.name)),
                  Text(
                    metric == _ActivityMetric.strength
                        ? '${item.value}セット'
                        : '${item.value}分',
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.rank,
    required this.equipment,
    required this.trailing,
  });

  final int rank;
  final _EquipmentReport equipment;
  final String trailing;

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
        trailing: Text(trailing),
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

  List<_EquipmentReport> get strengthEquipment =>
      equipment.where((item) => !item.isCardio).toList()
        ..sort((a, b) => b.totalSets.compareTo(a.totalSets));
  List<_EquipmentReport> get cardioEquipment =>
      equipment.where((item) => item.isCardio).toList()
        ..sort((a, b) => b.cardioSeconds.compareTo(a.cardioSeconds));

  int get totalSets =>
      sessions.fold(0, (sum, item) => sum + item.totalSetCount);
  int get cardioMinutes =>
      sessions.fold(0, (sum, item) => sum + item.totalCardioSeconds) ~/ 60;
  int get activeDayCount => sessions
      .map((summary) => _dateOnly(summary.session.startedAt.toLocal()))
      .toSet()
      .length;
  int achievedWeekCount(int weeklyTarget) {
    final activeDates = sessions
        .map((summary) => _dateOnly(summary.session.startedAt.toLocal()))
        .toSet();
    var count = 0;
    final monthStart = DateTime(end.year, end.month);
    for (
      var weekStart = monthStart.subtract(
        Duration(days: monthStart.weekday - 1),
      );
      !weekStart.isAfter(end);
      weekStart = weekStart.add(const Duration(days: 7))
    ) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final days = activeDates
          .where((date) => !date.isBefore(weekStart) && !date.isAfter(weekEnd))
          .length;
      if (days >= weeklyTarget) count++;
    }
    return count;
  }

  List<_ChartPoint> chartPoints(_ActivityMetric metric) {
    final byDate = <DateTime, Map<String, _DailyEquipmentValue>>{};
    for (final summary in sessions) {
      final local = summary.session.startedAt.toLocal();
      final date = DateTime(local.year, local.month, local.day);
      final equipment = byDate.putIfAbsent(date, () => {});
      for (final exercise in summary.exercises) {
        final isCardio = exercise.recordType == 'cardio';
        if ((metric == _ActivityMetric.cardio) != isCardio) continue;
        final value = isCardio
            ? ((exercise.durationSeconds ?? 0) / 60).ceil()
            : exercise.sets.length;
        if (value <= 0) continue;
        equipment.update(
          exercise.equipmentId,
          (item) => item.copyWith(value: item.value + value),
          ifAbsent: () => _DailyEquipmentValue(
            id: exercise.equipmentId,
            name: exercise.equipmentName,
            value: value,
          ),
        );
      }
    }
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return [
      for (
        var date = start;
        !date.isAfter(end);
        date = date.add(const Duration(days: 1))
      )
        _ChartPoint(
          date: date,
          label: period == _ReportPeriod.week
              ? weekdays[date.weekday - 1]
              : '${date.day}',
          equipment: _orderedDailyEquipment(byDate[date]?.values),
        ),
    ];
  }

  String get periodLabel => period == _ReportPeriod.week
      ? '${start.month}月${start.day}日〜${end.month}月${end.day}日'
      : '${start.year}年${start.month}月';

  factory _ReportData.create({
    required List<WorkoutSessionSummary> history,
    required _ReportPeriod period,
    required DateTime anchor,
  }) {
    final anchorDate = _dateOnly(anchor);
    final actualToday = _dateOnly(DateTime.now());
    final start = period == _ReportPeriod.week
        ? anchorDate.subtract(const Duration(days: 6))
        : DateTime(anchorDate.year, anchorDate.month);
    final end = period == _ReportPeriod.week
        ? anchorDate
        : anchorDate.year == actualToday.year &&
              anchorDate.month == actualToday.month
        ? actualToday
        : DateTime(anchorDate.year, anchorDate.month + 1, 0);
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
    ];
    return _ReportData(
      period: period,
      start: start,
      end: end,
      sessions: sessions,
      equipment: equipment,
    );
  }
}

List<_DailyEquipmentValue> _orderedDailyEquipment(
  Iterable<_DailyEquipmentValue>? values,
) {
  final equipment = List<_DailyEquipmentValue>.of(values ?? const []);
  equipment.sort(
    (first, second) => _chartEquipmentIndex(
      first.id,
    ).compareTo(_chartEquipmentIndex(second.id)),
  );
  return equipment;
}

class _ChartPoint {
  const _ChartPoint({
    required this.date,
    required this.label,
    required this.equipment,
  });

  final DateTime date;
  final String label;
  final List<_DailyEquipmentValue> equipment;

  int get total => equipment.fold(0, (sum, item) => sum + item.value);
}

class _DailyEquipmentValue {
  const _DailyEquipmentValue({
    required this.id,
    required this.name,
    required this.value,
  });

  final String id;
  final String name;
  final int value;

  _DailyEquipmentValue copyWith({required int value}) =>
      _DailyEquipmentValue(id: id, name: name, value: value);
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

  bool get isCardio => records.first.recordType == 'cardio';
  int get totalSets =>
      records.fold(0, (sum, record) => sum + record.sets.length);
  int get cardioSeconds =>
      records.fold(0, (sum, record) => sum + (record.durationSeconds ?? 0));
  int get cardioMinutes => cardioSeconds ~/ 60;

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

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
