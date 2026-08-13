import 'package:chocolog/app/theme.dart';
import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/onboarding/data/onboarding_preferences.dart';
import 'package:chocolog/features/settings/data/reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.preferences});

  final OnboardingPreferences preferences;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late int _weeklyTarget;
  late bool _reminderEnabled;
  late Set<int> _weekdays;
  late TimeOfDay _time;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final preferences = widget.preferences;
    _weeklyTarget = preferences.weeklyTarget;
    _reminderEnabled = preferences.reminderEnabled;
    _weekdays = preferences.reminderWeekdays.toSet();
    if (_weekdays.isEmpty) {
      _weekdays = {DateTime.tuesday, DateTime.saturday};
    }
    _time = TimeOfDay(
      hour: preferences.reminderHour,
      minute: preferences.reminderMinute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _SectionTitle('トレーニング設定'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('よく行く店舗'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/studios'),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '週の目標回数',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ホームと週レポートに反映されます',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ChocoLogColors.muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _weeklyTarget,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '目標回数',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: [
                          for (final count in [1, 2, 3, 4, 5, 6, 7])
                            DropdownMenuItem(
                              value: count,
                              child: Text('週$count回'),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _weeklyTarget = value);
                                _save();
                              },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const ListTile(title: Text('週の開始曜日'), trailing: Text('月曜日')),
              ],
            ),
          ),
          const _SectionTitle('通知'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('週間リマインダー'),
                  subtitle: Text(
                    _reminderEnabled
                        ? '${_weekdayLabel(_weekdays)}・${_timeLabel(_time)}'
                        : 'オフ',
                  ),
                  value: _reminderEnabled,
                  onChanged: _saving ? null : _toggleReminder,
                ),
                if (_reminderEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final entry in _weekdayLabels.entries)
                          FilterChip(
                            label: Text(entry.value),
                            selected: _weekdays.contains(entry.key),
                            onSelected: _saving
                                ? null
                                : (_) => _toggleWeekday(entry.key),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '通知時刻',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: DropdownButtonFormField<bool>(
                                initialValue: _isPm,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: '午前・午後',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: false,
                                    child: Text('午前'),
                                  ),
                                  DropdownMenuItem(
                                    value: true,
                                    child: Text('午後'),
                                  ),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          _setMeridiem(value);
                                        }
                                      },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                initialValue: _hour12,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: '時',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                items: [
                                  for (var hour = 1; hour <= 12; hour++)
                                    DropdownMenuItem(
                                      value: hour,
                                      child: Text('$hour'),
                                    ),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (value) {
                                        if (value != null) _setHour(value);
                                      },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                initialValue: _time.minute,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: '分',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                items: [
                                  for (final minute in _minuteOptions)
                                    DropdownMenuItem(
                                      value: minute,
                                      child: Text(
                                        minute.toString().padLeft(2, '0'),
                                      ),
                                    ),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (value) {
                                        if (value != null) _setMinute(value);
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const _SectionTitle('データ'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('保存方法について'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showStorageInfo,
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    'すべての記録を削除',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: _saving ? null : _confirmDeleteAll,
                ),
              ],
            ),
          ),
          const _SectionTitle('アプリ情報'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('非公式アプリについて'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showUnofficialInfo,
                ),
                const Divider(height: 1),
                const ListTile(title: Text('バージョン'), trailing: Text('1.0.0')),
              ],
            ),
          ),
          if (_saving) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleReminder(bool enabled) async {
    setState(() => _reminderEnabled = enabled);
    await _save(requestPermission: enabled);
  }

  Future<void> _toggleWeekday(int day) async {
    setState(() {
      if (_weekdays.contains(day)) {
        if (_weekdays.length > 1) _weekdays.remove(day);
      } else {
        _weekdays.add(day);
      }
    });
    await _save();
  }

  bool get _isPm => _time.hour >= 12;

  int get _hour12 {
    final hour = _time.hour % 12;
    return hour == 0 ? 12 : hour;
  }

  List<int> get _minuteOptions => ({
    for (var minute = 0; minute < 60; minute += 5) minute,
    _time.minute,
  }.toList()..sort());

  Future<void> _setMeridiem(bool isPm) async {
    final hour = (_hour12 % 12) + (isPm ? 12 : 0);
    setState(() => _time = TimeOfDay(hour: hour, minute: _time.minute));
    await _save();
  }

  Future<void> _setHour(int hour12) async {
    final hour = (hour12 % 12) + (_isPm ? 12 : 0);
    setState(() => _time = TimeOfDay(hour: hour, minute: _time.minute));
    await _save();
  }

  Future<void> _setMinute(int minute) async {
    setState(() => _time = TimeOfDay(hour: _time.hour, minute: minute));
    await _save();
  }

  Future<void> _save({bool requestPermission = false}) async {
    setState(() => _saving = true);
    var reminderEnabled = _reminderEnabled;
    if (reminderEnabled) {
      final scheduled = await ReminderService.instance.scheduleWeekly(
        weekdays: _weekdays.toList()..sort(),
        hour: _time.hour,
        minute: _time.minute,
        requestPermission: requestPermission,
      );
      if (!scheduled) reminderEnabled = false;
    } else {
      await ReminderService.instance.cancelWeekly();
    }
    await widget.preferences.update(
      OnboardingSettings(
        weeklyTarget: _weeklyTarget,
        reminderEnabled: reminderEnabled,
        reminderWeekdays: _weekdays.toList()..sort(),
        reminderHour: _time.hour,
        reminderMinute: _time.minute,
      ),
    );
    if (!mounted) return;
    setState(() {
      _reminderEnabled = reminderEnabled;
      _saving = false;
    });
    if (requestPermission && !reminderEnabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('通知が許可されていないため、設定をオフにしました')));
    }
  }

  void _showStorageInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('記録の保存場所'),
        content: Text('記録はこの端末内だけに保存されます。現在はクラウド同期や、端末紛失・削除後の復元には対応していません。'),
      ),
    );
  }

  void _showUnofficialInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('非公式アプリについて'),
        content: Text(
          'chocoLOGはchocoZAPの公式・公認アプリではありません。器具や店舗の情報は、現地または公式サービスでも確認してください。',
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('すべての記録を削除しますか？'),
        content: const Text('筋トレ・有酸素・メモを含む全履歴が対象です。設定は残ります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認へ進む'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この操作は取り消せません'),
        content: const Text('本当にすべての記録を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('すべて削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    await ref.read(workoutRepositoryProvider).deleteAllWorkoutSessions();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('すべての記録を削除しました')));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(color: ChocoLogColors.muted),
    ),
  );
}

const _weekdayLabels = {
  DateTime.monday: '月',
  DateTime.tuesday: '火',
  DateTime.wednesday: '水',
  DateTime.thursday: '木',
  DateTime.friday: '金',
  DateTime.saturday: '土',
  DateTime.sunday: '日',
};

String _weekdayLabel(Set<int> weekdays) => [
  for (final entry in _weekdayLabels.entries)
    if (weekdays.contains(entry.key)) entry.value,
].join('・');

String _timeLabel(TimeOfDay time) {
  final isPm = time.hour >= 12;
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${isPm ? '午後' : '午前'} $hour:$minute';
}
