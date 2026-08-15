import 'package:chocolog/app/theme.dart';
import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/core/widgets/chocolog_loading_indicator.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:chocolog/features/workout/presentation/workout_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StrengthEntryScreen extends ConsumerStatefulWidget {
  const StrengthEntryScreen({
    super.key,
    required this.equipmentId,
    this.returnToHome = false,
    this.studioId,
  });

  final String equipmentId;
  final bool returnToHome;
  final String? studioId;

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
      appBar: AppBar(title: Text(_equipment?.name ?? '記録')),
      body: _loading
          ? const Center(child: ChocoLogLoadingIndicator())
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
              key: const Key('strength-entry-list'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_previous.isNotEmpty) _previousCard(),
                if (_previous.isNotEmpty) const SizedBox(height: 20),
                if (_recommendation != null) _recommendationCard(),
                if (_recommendation != null) const SizedBox(height: 20),
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
                      trailing: PopupMenuButton<String>(
                        enabled: !_saving && set.id != null,
                        tooltip: '${index + 1}セット目の操作',
                        onSelected: (action) {
                          if (action == 'edit') {
                            _editSet(set);
                          } else if (action == 'delete') {
                            _deleteSet(set);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('編集')),
                          PopupMenuItem(value: 'delete', child: Text('削除')),
                        ],
                      ),
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

  _StrengthRecommendation? get _recommendation =>
      _recommendations[widget.equipmentId];

  Widget _recommendationCard() {
    final recommendation = _recommendation!;
    return Container(
      decoration: BoxDecoration(
        color: ChocoLogColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ChocoLogColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'おすすめ',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: ChocoLogColors.softYellow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text('回数・セット', style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  Text(
                    '${recommendation.reps}回 × 3セット',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (recommendation.womenWeight != null)
                  Expanded(
                    child: _recommendationWeightButton(
                      label: '女性の目安',
                      weight: recommendation.womenWeight!,
                      recommendation: recommendation,
                    ),
                  ),
                if (recommendation.womenWeight != null &&
                    recommendation.menWeight != null)
                  const SizedBox(width: 8),
                if (recommendation.menWeight != null)
                  Expanded(
                    child: _recommendationWeightButton(
                      label: '男性の目安',
                      weight: recommendation.menWeight!,
                      recommendation: recommendation,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recommendationWeightButton({
    required String label,
    required int weight,
    required _StrengthRecommendation recommendation,
  }) {
    return OutlinedButton(
      onPressed: () => setState(() {
        _weightController.text = '$weight';
        _repsController.text = '${recommendation.reps}';
      }),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 70),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: ChocoLogColors.surface,
        side: const BorderSide(color: ChocoLogColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: ChocoLogColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  '$weight kg',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.touch_app_outlined, size: 19),
        ],
      ),
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
            for (final reps in [10, 15, 20, 25])
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
          .addSets(
            equipmentId: widget.equipmentId,
            sets: sets,
            studioId: widget.studioId,
          );
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

  Future<void> _editSet(ExerciseSetValue set) async {
    final updated = await showDialog<ExerciseSetValue>(
      context: context,
      builder: (context) =>
          _EditSetDialog(set: set, isBodyweight: _isBodyweight),
    );
    if (updated == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(workoutFlowControllerProvider.notifier)
          .updateSet(
            equipmentId: widget.equipmentId,
            setId: set.id!,
            weightKg: updated.weightKg,
            reps: updated.reps,
          );
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      if (mounted) _showError('セットを更新できませんでした');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSet(ExerciseSetValue set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('セットを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(workoutFlowControllerProvider.notifier)
          .deleteSet(equipmentId: widget.equipmentId, setId: set.id!);
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      if (mounted) _showError('セットを削除できませんでした');
    } finally {
      if (mounted) setState(() => _saving = false);
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

class _StrengthRecommendation {
  const _StrengthRecommendation({
    required this.reps,
    this.womenWeight,
    this.menWeight,
  });

  final int reps;
  final int? womenWeight;
  final int? menWeight;
}

const _recommendations = <String, _StrengthRecommendation>{
  'chest-press': _StrengthRecommendation(
    reps: 15,
    womenWeight: 5,
    menWeight: 20,
  ),
  'shoulder-press': _StrengthRecommendation(
    reps: 15,
    womenWeight: 5,
    menWeight: 5,
  ),
  'lat-pulldown': _StrengthRecommendation(
    reps: 15,
    womenWeight: 10,
    menWeight: 20,
  ),
  'leg-press': _StrengthRecommendation(
    reps: 15,
    womenWeight: 25,
    menWeight: 50,
  ),
  'adduction': _StrengthRecommendation(
    reps: 15,
    womenWeight: 15,
    menWeight: 20,
  ),
  'abduction': _StrengthRecommendation(
    reps: 15,
    womenWeight: 15,
    menWeight: 20,
  ),
};

class _EditSetDialog extends StatefulWidget {
  const _EditSetDialog({required this.set, required this.isBodyweight});

  final ExerciseSetValue set;
  final bool isBodyweight;

  @override
  State<_EditSetDialog> createState() => _EditSetDialogState();
}

class _EditSetDialogState extends State<_EditSetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.set.weightKg?.toString() ?? '',
    );
    _repsController = TextEditingController(text: '${widget.set.reps}');
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('セットを編集'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.isBodyweight)
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '重量',
                    suffixText: 'kg',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    final weight = int.tryParse(value);
                    return weight != null && weight % 5 == 0
                        ? null
                        : '5kg単位で入力してください';
                  },
                ),
              if (!widget.isBodyweight) const SizedBox(height: 12),
              TextFormField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '回数',
                  suffixText: '回',
                ),
                validator: (value) {
                  final reps = int.tryParse(value ?? '');
                  return reps != null && reps > 0 ? null : '1回以上で入力してください';
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(
              context,
              ExerciseSetValue(
                weightKg: widget.isBodyweight || _weightController.text.isEmpty
                    ? null
                    : int.parse(_weightController.text),
                reps: int.parse(_repsController.text),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
