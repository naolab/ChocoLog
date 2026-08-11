import 'package:shared_preferences/shared_preferences.dart';

class OnboardingSettings {
  const OnboardingSettings({
    required this.weeklyTarget,
    required this.reminderEnabled,
    required this.reminderWeekdays,
    required this.reminderHour,
    required this.reminderMinute,
  });

  final int weeklyTarget;
  final bool reminderEnabled;
  final List<int> reminderWeekdays;
  final int reminderHour;
  final int reminderMinute;
}

class OnboardingPreferences {
  OnboardingPreferences(this._preferences);

  static const _completedKey = 'onboarding.completed';
  static const _weeklyTargetKey = 'training.weeklyTarget';
  static const _reminderEnabledKey = 'reminder.enabled';
  static const _reminderWeekdaysKey = 'reminder.weekdays';
  static const _reminderHourKey = 'reminder.hour';
  static const _reminderMinuteKey = 'reminder.minute';

  final SharedPreferences _preferences;

  static Future<OnboardingPreferences> load() async {
    return OnboardingPreferences(await SharedPreferences.getInstance());
  }

  bool get isCompleted => _preferences.getBool(_completedKey) ?? false;
  int get weeklyTarget => _preferences.getInt(_weeklyTargetKey) ?? 2;
  bool get reminderEnabled =>
      _preferences.getBool(_reminderEnabledKey) ?? false;
  List<int> get reminderWeekdays =>
      (_preferences.getStringList(_reminderWeekdaysKey) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toList();
  int get reminderHour => _preferences.getInt(_reminderHourKey) ?? 19;
  int get reminderMinute => _preferences.getInt(_reminderMinuteKey) ?? 0;

  Future<void> complete(OnboardingSettings settings) async {
    await _preferences.setInt(_weeklyTargetKey, settings.weeklyTarget);
    await _preferences.setBool(_reminderEnabledKey, settings.reminderEnabled);
    await _preferences.setStringList(
      _reminderWeekdaysKey,
      settings.reminderWeekdays.map((day) => '$day').toList(),
    );
    await _preferences.setInt(_reminderHourKey, settings.reminderHour);
    await _preferences.setInt(_reminderMinuteKey, settings.reminderMinute);
    await _preferences.setBool(_completedKey, true);
  }
}
