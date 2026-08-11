import 'dart:async';

import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:chocolog/features/workout/presentation/workout_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CardioTimerScreen extends ConsumerStatefulWidget {
  const CardioTimerScreen({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  ConsumerState<CardioTimerScreen> createState() => _CardioTimerScreenState();
}

class _CardioTimerScreenState extends ConsumerState<CardioTimerScreen> {
  final _distanceController = TextEditingController();
  EquipmentItem? _equipment;
  CardioRecordSnapshot? _record;
  Timer? _ticker;
  var _loading = true;
  var _processing = false;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return Scaffold(
      appBar: AppBar(
        title: Text(_equipment?.name ?? '有酸素運動'),
        actions: [
          if (record?.timerStatus == 'completed')
            TextButton(
              onPressed: () => context.go('/workout/session'),
              child: const Text('完了'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    _formatDuration(
                      record?.elapsedSecondsAt(DateTime.now().toUtc()) ?? 0,
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusLabel(record?.timerStatus),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextField(
                    controller: _distanceController,
                    enabled: record?.timerStatus != 'completed',
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
                  if (record == null)
                    FilledButton.icon(
                      onPressed: _processing ? null : _start,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('タイマーを開始'),
                    )
                  else if (record.timerStatus == 'running') ...[
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
                  ] else if (record.timerStatus == 'paused') ...[
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
                      onPressed: () => context.go('/workout/session'),
                      child: const Text('今日の記録へ戻る'),
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
      if (!mounted) return;
      setState(() {
        _equipment = equipment;
        _record = record;
        _loading = false;
        if (record?.distanceKm != null) {
          _distanceController.text = '${record!.distanceKm}';
        }
      });
      _syncTicker();
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
        .startCardio(widget.equipmentId),
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
    final distanceText = _distanceController.text.trim();
    final distance = distanceText.isEmpty
        ? null
        : double.tryParse(distanceText);
    if (distanceText.isNotEmpty && distance == null) {
      _showError('距離を正しく入力してください');
      return;
    }
    await _update(
      () => ref
          .read(workoutFlowControllerProvider.notifier)
          .finishCardio(recordId: _record!.id, distanceKm: distance),
    );
    if (mounted && _record?.timerStatus == 'completed') {
      context.go('/workout/session');
    }
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
