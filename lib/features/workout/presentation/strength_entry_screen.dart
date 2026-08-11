import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:chocolog/features/workout/presentation/workout_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StrengthEntryScreen extends ConsumerStatefulWidget {
  const StrengthEntryScreen({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  ConsumerState<StrengthEntryScreen> createState() =>
      _StrengthEntryScreenState();
}

class _StrengthEntryScreenState extends ConsumerState<StrengthEntryScreen> {
  final _weightController = TextEditingController(text: '20');
  final _repsController = TextEditingController(text: '15');
  EquipmentItem? _equipment;
  List<ExerciseSetValue> _previous = const [];
  List<ExerciseSetValue> _saved = const [];
  var _loading = true;
  var _saving = false;
  String? _loadError;

  bool get _isBodyweight => _equipment?.metricType == 'bodyweight';

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final equipmentRepository = ref.read(equipmentRepositoryProvider);
      await equipmentRepository.seedDefaults();
      final equipment = await equipmentRepository.findById(widget.equipmentId);
      final workoutRepository = ref.read(workoutRepositoryProvider);
      final previous = await workoutRepository.getPreviousSets(
        widget.equipmentId,
      );
      final saved = await ref
          .read(workoutFlowControllerProvider.notifier)
          .currentSets(widget.equipmentId);
      if (!mounted) return;
      setState(() {
        _equipment = equipment;
        _previous = previous;
        _saved = saved;
        _loading = false;
        _loadError = null;
        if (equipment?.metricType == 'bodyweight') {
          _weightController.clear();
        } else if (previous.isNotEmpty && previous.first.weightKg != null) {
          _weightController.text = '${previous.first.weightKg}';
        }
        if (previous.isNotEmpty) {
          _repsController.text = '${previous.first.reps}';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '記録を読み込めませんでした';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_equipment?.name ?? '記録'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => context.go('/workout/session'),
            child: const Text('完了'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _loading = true);
                      _load();
                    },
                    child: const Text('再試行'),
                  ),
                ],
              ),
            )
          : _equipment == null
          ? const Center(child: Text('器具が見つかりません'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_previous.isNotEmpty) _previousCard(),
                if (_previous.isNotEmpty) const SizedBox(height: 20),
                if (_isBodyweight)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('自重トレーニング', textAlign: TextAlign.center),
                    ),
                  )
                else
                  _weightInput(),
                const SizedBox(height: 20),
                _repsInput(),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : () => _saveRepeated(1),
                  child: const Text('このセットを追加'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _saving ? null : () => _saveRepeated(3),
                  child: const Text('同じ内容を3セット追加'),
                ),
                if (_saved.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    '今回のセット',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final (index, set) in _saved.indexed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(_setLabel(set)),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _previousCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('前回 ${_summary(_previous)}'),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _saving ? null : _copyPrevious,
              child: Text('前回の${_previous.length}セットをコピー'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weightInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('重量', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final weight in [10, 15, 20, 25])
              ActionChip(
                label: Text('$weight kg'),
                onPressed: () =>
                    setState(() => _weightController.text = '$weight'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.outlined(
              onPressed: () => _adjustWeight(-5),
              tooltip: '5kg減らす',
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _weightController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  suffixText: 'kg',
                  hintText: '未設定',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.outlined(
              onPressed: () => _adjustWeight(5),
              tooltip: '5kg増やす',
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _repsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('回数', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final reps in [10, 12, 15])
              ActionChip(
                label: Text('$reps 回'),
                onPressed: () => setState(() => _repsController.text = '$reps'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.outlined(
              onPressed: () => _adjustReps(-1),
              tooltip: '1回減らす',
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _repsController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  suffixText: '回',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.outlined(
              onPressed: () => _adjustReps(1),
              tooltip: '1回増やす',
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveRepeated(int count) async {
    final reps = int.tryParse(_repsController.text);
    final weight = _isBodyweight || _weightController.text.isEmpty
        ? null
        : int.tryParse(_weightController.text);
    if (reps == null || reps <= 0) return _showError('回数は1回以上で入力してください');
    if (!_isBodyweight && weight != null && weight % 5 != 0) {
      return _showError('重量は5kg単位で入力してください');
    }
    await _save(
      List.filled(count, ExerciseSetValue(weightKg: weight, reps: reps)),
    );
  }

  Future<void> _copyPrevious() => _save(_previous);

  Future<void> _save(List<ExerciseSetValue> sets) async {
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(workoutFlowControllerProvider.notifier)
          .addSets(equipmentId: widget.equipmentId, sets: sets);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('セットを保存できませんでした');
    }
  }

  void _adjustWeight(int delta) {
    final current = int.tryParse(_weightController.text) ?? 0;
    _weightController.text = '${(current + delta).clamp(0, 999)}';
    setState(() {});
  }

  void _adjustReps(int delta) {
    final current = int.tryParse(_repsController.text) ?? 1;
    _repsController.text = '${(current + delta).clamp(1, 999)}';
    setState(() {});
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _summary(List<ExerciseSetValue> sets) {
    final first = sets.first;
    return '${_setLabel(first)} × ${sets.length}セット';
  }

  String _setLabel(ExerciseSetValue set) {
    if (set.weightKg != null) return '${set.weightKg}kg × ${set.reps}回';
    return _isBodyweight ? '自重 × ${set.reps}回' : '重量未設定 × ${set.reps}回';
  }
}
