import 'dart:async';

import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/core/widgets/chocolog_loading_indicator.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:chocolog/features/workout/data/cardio_live_activity_service.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:chocolog/features/workout/presentation/workout_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CardioTimerScreen extends ConsumerStatefulWidget {
  const CardioTimerScreen({
    super.key,
    required this.equipmentId,
    this.returnToHome = false,
    this.studioId,
  });

  final String equipmentId;
  final bool returnToHome;
  final String? studioId;

  @override
  ConsumerState<CardioTimerScreen> createState() => _CardioTimerScreenState();
}

class _CardioTimerScreenState extends ConsumerState<CardioTimerScreen> {
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController(text: '20');
  EquipmentItem? _equipment;
  CardioRecordSnapshot? _record;
  Timer? _ticker;
  var _loading = true;
  var _processing = false;
  var _manualEntry = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _distanceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_equipment?.name ?? '有酸素運動')),
      body: _loading
          ? const Center(child: ChocoLogLoadingIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_record == null)
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.timer_outlined),
                          label: Text('タイマー'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.edit_outlined),
                          label: Text('手動で記録'),
                        ),
                      ],
                      selected: {_manualEntry},
                      onSelectionChanged: _processing
                          ? null
                          : (value) =>
                                setState(() => _manualEntry = value.first),
                    ),
                  const Spacer(),
                  if (!_manualEntry || _record != null) ...[
                    Text(
                      _formatDuration(
                        _record?.elapsedSecondsAt(DateTime.now().toUtc()) ?? 0,
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusLabel(_record?.timerStatus),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ] else ...[
                    Text(
                      '運動した時間',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final minutes in [10, 20, 30, 45])
                          ChoiceChip(
                            label: Text('$minutes分'),
                            selected: _durationController.text == '$minutes',
                            onSelected: (_) => setState(
                              () => _durationController.text = '$minutes',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _durationController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '時間',
                        suffixText: '分',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextField(
                    controller: _distanceController,
                    enabled: _record?.timerStatus != 'completed',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: '距離（任意）',
                      suffixText: 'km',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_record == null && _manualEntry)
                    FilledButton.icon(
                      onPressed: _processing ? null : _saveManual,
                      icon: const Icon(Icons.add),
                      label: const Text('この内容で記録'),
                    )
                  else if (_record == null)
                    FilledButton.icon(
                      onPressed: _processing ? null : _start,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('タイマーを開始'),
                    )
                  else if (_record!.timerStatus == 'running') ...[
                    OutlinedButton.icon(
                      onPressed: _processing ? null : _pause,
                      icon: const Icon(Icons.pause),
                      label: const Text('一時停止'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _processing ? null : _finish,
                      child: const Text('この器具を終了'),
                    ),
                  ] else if (_record!.timerStatus == 'paused') ...[
                    OutlinedButton.icon(
                      onPressed: _processing ? null : _resume,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('再開'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _processing ? null : _finish,
                      child: const Text('この器具を終了'),
                    ),
                  ] else
                    FilledButton(
                      onPressed: _finishNavigation,
                      child: const Text('ホームへ戻る'),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final equipmentRepository = ref.read(equipmentRepositoryProvider);
      await equipmentRepository.seedDefaults();
      final equipment = await equipmentRepository.findById(widget.equipmentId);
      final record = await ref
          .read(workoutFlowControllerProvider.notifier)
          .currentCardio(widget.equipmentId);
      final editableRecord =
          widget.returnToHome && record?.timerStatus == 'completed'
          ? null
          : record;
      if (!mounted) return;
      setState(() {
        _equipment = equipment;
        _record = editableRecord;
        _loading = false;
        if (record?.distanceKm != null) {
          _distanceController.text = '${record!.distanceKm}';
        }
      });
      _syncTicker();
      if (record != null && record.timerStatus != 'completed') {
        await CardioLiveActivityService().sync(
          record: record,
          equipmentName: equipment?.name ?? '有酸素運動',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'タイマーを読み込めませんでした';
      });
    }
  }

  Future<void> _start() => _update(
    () => ref
        .read(workoutFlowControllerProvider.notifier)
        .startCardio(widget.equipmentId, studioId: widget.studioId),
  );

  Future<void> _pause() => _update(
    () => ref
        .read(workoutFlowControllerProvider.notifier)
        .pauseCardio(_record!.id),
  );

  Future<void> _resume() => _update(
    () => ref
        .read(workoutFlowControllerProvider.notifier)
        .resumeCardio(_record!.id),
  );

  Future<void> _finish() async {
    final distance = _parseDistance();
    if (!distance.valid) return;
    await _update(
      () => ref
          .read(workoutFlowControllerProvider.notifier)
          .finishCardio(recordId: _record!.id, distanceKm: distance.value),
    );
    if (mounted && _record?.timerStatus == 'completed') {
      await _finishNavigation();
    }
  }

  Future<void> _saveManual() async {
    final minutes = int.tryParse(_durationController.text.trim());
    if (minutes == null || minutes <= 0) {
      _showError('時間を1分以上で入力してください');
      return;
    }
    final distance = _parseDistance();
    if (!distance.valid) return;
    setState(() => _processing = true);
    try {
      await ref
          .read(workoutFlowControllerProvider.notifier)
          .addManualCardio(
            equipmentId: widget.equipmentId,
            durationMinutes: minutes,
            distanceKm: distance.value,
            studioId: widget.studioId,
          );
      if (mounted) await _finishNavigation();
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      _showError('記録を保存できませんでした');
    }
  }

  ({bool valid, double? value}) _parseDistance() {
    final text = _distanceController.text.trim();
    final value = text.isEmpty ? null : double.tryParse(text);
    if (text.isNotEmpty && value == null) {
      _showError('距離を正しく入力してください');
      return (valid: false, value: null);
    }
    return (valid: true, value: value);
  }

  Future<void> _finishNavigation() async {
    if (mounted) context.go('/home');
  }

  Future<void> _update(
    Future<CardioRecordSnapshot> Function() operation,
  ) async {
    setState(() => _processing = true);
    try {
      final record = await operation();
      if (!mounted) return;
      setState(() {
        _record = record;
        _processing = false;
      });
      _syncTicker();
      await CardioLiveActivityService().sync(
        record: record,
        equipmentName: _equipment?.name ?? '有酸素運動',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      _showError('タイマーを更新できませんでした');
    }
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (_record?.timerStatus != 'running') return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
        ],
      ),
    );
  }
}

String _statusLabel(String? status) => switch (status) {
  'running' => '計測中',
  'paused' => '一時停止中',
  'completed' => '記録済み',
  _ => '開始前',
};

String _formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return [
    hours,
    minutes,
    seconds,
  ].map((value) => value.toString().padLeft(2, '0')).join(':');
}
