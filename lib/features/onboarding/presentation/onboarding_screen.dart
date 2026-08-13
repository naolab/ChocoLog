import 'package:chocolog/app/theme.dart';
import 'package:chocolog/features/onboarding/data/onboarding_preferences.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCompleted});

  final Future<void> Function(OnboardingSettings settings) onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  var _step = 0;
  var _weeklyTarget = 2;
  var _reminderEnabled = false;
  var _reminderTime = const TimeOfDay(hour: 19, minute: 0);
  final _reminderWeekdays = <int>{DateTime.tuesday, DateTime.saturday};
  var _isSaving = false;

  void _next() => setState(() => _step += 1);

  void _back() => setState(() => _step -= 1);

  Future<void> _complete() async {
    setState(() => _isSaving = true);
    try {
      await widget.onCompleted(
        OnboardingSettings(
          weeklyTarget: _weeklyTarget,
          reminderEnabled: _reminderEnabled,
          reminderWeekdays: _reminderWeekdays.toList()..sort(),
          reminderHour: _reminderTime.hour,
          reminderMinute: _reminderTime.minute,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存できませんでした。もう一度お試しください。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    if (_step > 0)
                      IconButton(
                        onPressed: _isSaving ? null : _back,
                        tooltip: '戻る',
                        icon: const Icon(Icons.arrow_back),
                      ),
                    const Spacer(),
                    if (_step > 0)
                      Text(
                        '$_step / 3',
                        style: const TextStyle(color: ChocoLogColors.muted),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: switch (_step) {
                      0 => const _IntroductionStep(),
                      1 => _GoalStep(
                        selected: _weeklyTarget,
                        onSelected: (value) =>
                            setState(() => _weeklyTarget = value),
                      ),
                      2 => const _StudioStep(),
                      _ => _ReminderStep(
                        enabled: _reminderEnabled,
                        weekdays: _reminderWeekdays,
                        time: _reminderTime,
                        onEnabledChanged: (value) =>
                            setState(() => _reminderEnabled = value),
                        onWeekdayChanged: (day) {
                          setState(() {
                            if (_reminderWeekdays.contains(day)) {
                              if (_reminderWeekdays.length == 1) return;
                              _reminderWeekdays.remove(day);
                            } else {
                              _reminderWeekdays.add(day);
                            }
                          });
                        },
                        onTimePressed: _selectTime,
                      ),
                    },
                  ),
                ),
              ),
              FilledButton(
                onPressed: _isSaving ? null : (_step == 3 ? _complete : _next),
                child: Text(
                  _isSaving
                      ? '保存中…'
                      : switch (_step) {
                          0 => 'はじめる',
                          1 => '次へ',
                          2 => '今は設定しない',
                          _ when _reminderEnabled => '設定を保存して始める',
                          _ => '通知なしで始める',
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (selected != null && mounted) {
      setState(() => _reminderTime = selected);
    }
  }
}

class _IntroductionStep extends StatelessWidget {
  const _IntroductionStep();

  @override
  Widget build(BuildContext context) {
    return const _StepLayout(
      icon: Icons.fitness_center,
      title: 'chocoLOG',
      description: 'いつものトレーニングを\nかんたんに記録',
      details: ['筋トレの重量・回数・セット', '有酸素運動の時間', '前回メニューをすぐにコピー'],
      footnote: 'ログイン不要・記録は端末内に保存されます\nchocoZAP公式・公認アプリではありません',
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      icon: Icons.flag_outlined,
      title: '週の目標',
      description: '週に何回運動しますか？',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final count in [1, 2, 3])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ChoiceChip(
                label: SizedBox(
                  width: double.infinity,
                  child: Text(
                    count == 2 ? '週$count回　おすすめ' : '週$count回',
                    textAlign: TextAlign.center,
                  ),
                ),
                selected: selected == count,
                onSelected: (_) => onSelected(count),
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            '目標は設定画面からいつでも変更できます',
            textAlign: TextAlign.center,
            style: TextStyle(color: ChocoLogColors.muted),
          ),
        ],
      ),
    );
  }
}

class _StudioStep extends StatelessWidget {
  const _StudioStep();

  @override
  Widget build(BuildContext context) {
    return const _StepLayout(
      icon: Icons.location_on_outlined,
      title: 'よく行く店舗',
      description: '店舗を登録すると、設置されている器具を見つけやすくなります',
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            '店舗はホームや設定からいつでも登録できます。\nまずは店舗を選ばずに始められます。',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ReminderStep extends StatelessWidget {
  const _ReminderStep({
    required this.enabled,
    required this.weekdays,
    required this.time,
    required this.onEnabledChanged,
    required this.onWeekdayChanged,
    required this.onTimePressed,
  });

  final bool enabled;
  final Set<int> weekdays;
  final TimeOfDay time;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onWeekdayChanged;
  final VoidCallback onTimePressed;

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = {
      1: '月',
      2: '火',
      3: '水',
      4: '木',
      5: '金',
      6: '土',
      7: '日',
    };
    return _StepLayout(
      icon: Icons.notifications_none,
      title: 'リマインダー',
      description: '運動するタイミングをお知らせします',
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('リマインダーを設定'),
            value: enabled,
            onChanged: onEnabledChanged,
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final entry in weekdayLabels.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: weekdays.contains(entry.key),
                    onSelected: (_) => onWeekdayChanged(entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onTimePressed,
              icon: const Icon(Icons.schedule),
              label: Text(time.format(context)),
            ),
            const SizedBox(height: 8),
            const Text(
              '通知設定は、設定画面からいつでも変更できます',
              style: TextStyle(color: ChocoLogColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.icon,
    required this.title,
    required this.description,
    this.details = const [],
    this.footnote,
    this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> details;
  final String? footnote;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Column(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: ChocoLogColors.yellow,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Icon(icon, size: 42),
              ),
            ),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 28),
              for (final detail in details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(detail)),
                    ],
                  ),
                ),
            ],
            if (child != null) ...[const SizedBox(height: 28), child!],
            if (footnote != null) ...[
              const SizedBox(height: 28),
              Text(
                footnote!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ChocoLogColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
