import 'package:chocolog/app/theme.dart';
import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:chocolog/features/studios/data/studio_repository.dart';
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
  String? _openingEquipmentId;

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
    final equipment = ref.watch(activeEquipmentProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('chocoLOG')),
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
                  _StudioCard(
                    studio: data.studio,
                    onChange: _changeStudio,
                    onClear: data.studio == null ? null : _clearStudio,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '器具を選んで記録',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.studio == null
                        ? 'すべての器具を表示しています'
                        : '${data.studio!.name}の設置器具',
                    style: const TextStyle(color: ChocoLogColors.muted),
                  ),
                  const SizedBox(height: 12),
                  equipment.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stackTrace) => const _EquipmentError(),
                    data: (items) {
                      final visible = data.studio == null
                          ? items
                          : items
                                .where(
                                  (item) => data.studio!.equipmentUnits
                                      .containsKey(item.id),
                                )
                                .toList(growable: false);
                      if (visible.isEmpty) {
                        return _EmptyEquipment(onChangeStudio: _changeStudio);
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              mainAxisExtent: 200,
                            ),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return _EquipmentCard(
                            equipment: item,
                            todayRecord: data.todayRecords[item.id],
                            loading: _openingEquipmentId == item.id,
                            enabled: _openingEquipmentId == null,
                            onTap: () => _openEquipment(item, data.studio?.id),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text('今日の記録', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (data.currentRecord != null &&
                      data.currentRecord!.exercises.isNotEmpty) ...[
                    _CurrentRecordCard(summary: data.currentRecord!),
                    const SizedBox(height: 10),
                  ],
                  if (data.completedToday.isEmpty &&
                      (data.currentRecord == null ||
                          data.currentRecord!.exercises.isEmpty))
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
    await ref
        .read(workoutFlowControllerProvider.notifier)
        .finalizeSavedSession();
    final active = await repository.getActiveSession();
    final history = await repository.getCompletedSessionSummaries();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedToday = history.where((summary) {
      final startedAt = summary.session.startedAt.toLocal();
      return DateTime(startedAt.year, startedAt.month, startedAt.day) == today;
    }).toList();
    StudioItem? studio;
    try {
      studio = await StudioRepository.instance.preferredStudio();
    } catch (_) {
      // 店舗情報を取得できない場合も全器具から記録できるようにする。
    }
    final currentRecord = active == null
        ? null
        : await repository.getSessionSummary(active.id);
    return _HomeData(
      studio: studio,
      currentRecord: currentRecord,
      completedToday: completedToday,
      todayRecords: _aggregateTodayRecords([?currentRecord, ...completedToday]),
    );
  }

  Future<void> _reload() async {
    final future = _loadData();
    if (mounted) {
      setState(() {
        _data = future;
        _openingEquipmentId = null;
      });
    }
    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the retry state.
    }
  }

  Future<void> _changeStudio() async {
    final studio = await context.push<StudioItem>('/workout/studio/search');
    if (studio == null || !mounted) return;
    await StudioRepository.instance.setPreferredStudio(studio);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _clearStudio() async {
    await StudioRepository.instance.setPreferredStudio(null);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openEquipment(EquipmentItem equipment, String? studioId) async {
    setState(() => _openingEquipmentId = equipment.id);
    try {
      final type = switch (equipment.metricType) {
        'cardio' => 'cardio',
        'bodyweight' => 'bodyweight',
        _ => 'strength',
      };
      final queryParameters = {'returnTo': 'home'};
      if (studioId != null) queryParameters['studioId'] = studioId;
      final location = Uri(
        path: '/workout/$type/${equipment.id}',
        queryParameters: queryParameters,
      ).toString();
      await context.push(location);
      if (mounted) await _reload();
    } catch (_) {
      if (!mounted) return;
      setState(() => _openingEquipmentId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('記録画面を開けませんでした')));
    }
  }
}

class _HomeData {
  const _HomeData({
    required this.studio,
    required this.currentRecord,
    required this.completedToday,
    required this.todayRecords,
  });

  final StudioItem? studio;
  final WorkoutSessionSummary? currentRecord;
  final List<WorkoutSessionSummary> completedToday;
  final Map<String, _TodayEquipmentRecord> todayRecords;
}

class _TodayEquipmentRecord {
  const _TodayEquipmentRecord({
    required this.recordType,
    required this.sets,
    required this.durationSeconds,
  });

  final String recordType;
  final List<ExerciseSetValue> sets;
  final int durationSeconds;

  String get label {
    if (recordType == 'cardio') {
      final minutes = durationSeconds ~/ 60;
      return minutes > 0 ? '今日 $minutes分' : '今日 $durationSeconds秒';
    }
    if (sets.isEmpty) return '今日 記録済み';
    final first = sets.first;
    final allSame = sets.every(
      (set) => set.weightKg == first.weightKg && set.reps == first.reps,
    );
    if (allSame) {
      final weight = first.weightKg == null ? '' : '${first.weightKg}kg × ';
      return '今日 $weight${first.reps}回 × ${sets.length}セット';
    }
    final totalReps = sets.fold(0, (sum, set) => sum + set.reps);
    return '今日 ${sets.length}セット・合計$totalReps回';
  }
}

Map<String, _TodayEquipmentRecord> _aggregateTodayRecords(
  List<WorkoutSessionSummary> sessions,
) {
  final sets = <String, List<ExerciseSetValue>>{};
  final types = <String, String>{};
  final durations = <String, int>{};
  for (final session in sessions) {
    for (final exercise in session.exercises) {
      types[exercise.equipmentId] = exercise.recordType;
      sets.putIfAbsent(exercise.equipmentId, () => []).addAll(exercise.sets);
      durations.update(
        exercise.equipmentId,
        (value) => value + (exercise.durationSeconds ?? 0),
        ifAbsent: () => exercise.durationSeconds ?? 0,
      );
    }
  }
  return {
    for (final id in types.keys)
      id: _TodayEquipmentRecord(
        recordType: types[id]!,
        sets: sets[id] ?? const [],
        durationSeconds: durations[id] ?? 0,
      ),
  };
}

class _StudioCard extends StatelessWidget {
  const _StudioCard({
    required this.studio,
    required this.onChange,
    required this.onClear,
  });

  final StudioItem? studio;
  final VoidCallback onChange;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onChange,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.location_on_outlined)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'いつもの店舗',
                      style: TextStyle(
                        color: ChocoLogColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      studio?.name ?? '店舗未設定',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Text(studio == null ? '設定' : '変更'),
              const SizedBox(width: 4),
              if (onClear == null)
                const Icon(Icons.chevron_right)
              else
                PopupMenuButton<String>(
                  tooltip: '店舗設定の操作',
                  onSelected: (value) {
                    if (value == 'clear') onClear!();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'clear', child: Text('店舗設定を解除')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.equipment,
    required this.todayRecord,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final EquipmentItem equipment;
  final _TodayEquipmentRecord? todayRecord;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCardio = equipment.metricType == 'cardio';
    return Card(
      color: todayRecord == null
          ? null
          : ChocoLogColors.yellow.withValues(alpha: 0.28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/equipment/${equipment.id}.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        isCardio ? Icons.directions_run : Icons.fitness_center,
                        size: 42,
                      ),
                    ),
                    if (loading)
                      const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    if (todayRecord != null)
                      const Align(
                        alignment: Alignment.topRight,
                        child: Icon(Icons.check_circle, size: 22),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                equipment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                todayRecord?.label ?? (isCardio ? '時間' : '回数・セット'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: todayRecord == null
                      ? ChocoLogColors.muted
                      : ChocoLogColors.ink,
                  fontSize: 13,
                  fontWeight: todayRecord == null
                      ? FontWeight.w500
                      : FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentRecordCard extends StatelessWidget {
  const _CurrentRecordCard({required this.summary});

  final WorkoutSessionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final exercise in summary.exercises)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(exercise.equipmentName),
                subtitle: Text(_exerciseLabel(exercise)),
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
            summary.exercises
                .map(
                  (exercise) =>
                      '${exercise.equipmentName}：${_exerciseLabel(exercise)}',
                )
                .join('\n'),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _EmptyEquipment extends StatelessWidget {
  const _EmptyEquipment({required this.onChangeStudio});

  final VoidCallback onChangeStudio;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('この店舗の器具情報が見つかりませんでした'),
            const SizedBox(height: 10),
            TextButton(onPressed: onChangeStudio, child: const Text('店舗を変更')),
          ],
        ),
      ),
    );
  }
}

class _EquipmentError extends StatelessWidget {
  const _EquipmentError();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('器具一覧を読み込めませんでした'),
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
          '器具を選ぶと、ここに今日の記録が追加されます',
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

String _exerciseLabel(WorkoutExerciseSummary exercise) {
  if (exercise.recordType == 'cardio') {
    final seconds = exercise.durationSeconds ?? 0;
    final minutes = seconds ~/ 60;
    final duration = minutes > 0 ? '$minutes分' : '$seconds秒';
    final distance = exercise.distanceKm;
    return distance == null ? duration : '$duration・${distance}km';
  }
  if (exercise.sets.isEmpty) return '記録済み';
  final first = exercise.sets.first;
  final allSame = exercise.sets.every(
    (set) => set.weightKg == first.weightKg && set.reps == first.reps,
  );
  if (!allSame) {
    final totalReps = exercise.sets.fold(0, (sum, set) => sum + set.reps);
    return '${exercise.sets.length}セット・合計$totalReps回';
  }
  final weight = first.weightKg == null ? '' : '${first.weightKg}kg × ';
  return '$weight${first.reps}回 × ${exercise.sets.length}セット';
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
