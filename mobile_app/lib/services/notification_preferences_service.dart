import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  final bool reminders;
  final bool tips;
  final bool activity;
  final bool criticalAlerts;

  const NotificationPreferences({
    required this.reminders,
    required this.tips,
    required this.activity,
    required this.criticalAlerts,
  });

  static const defaults = NotificationPreferences(
    reminders: true,
    tips: true,
    activity: false,
    criticalAlerts: true,
  );

  bool get hasOptionalNotificationsEnabled => reminders || tips || activity;

  NotificationPreferences copyWith({
    bool? reminders,
    bool? tips,
    bool? activity,
    bool? criticalAlerts,
  }) {
    return NotificationPreferences(
      reminders: reminders ?? this.reminders,
      tips: tips ?? this.tips,
      activity: activity ?? this.activity,
      criticalAlerts: criticalAlerts ?? this.criticalAlerts,
    );
  }
}

class NotificationPreferencesService {
  static const _remindersKey = 'notifications_reminders';
  static const _tipsKey = 'notifications_tips';
  static const _activityKey = 'notifications_activity';
  static const _criticalAlertsKey = 'notifications_critical_alerts';

  Future<NotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      reminders: prefs.getBool(_remindersKey) ?? NotificationPreferences.defaults.reminders,
      tips: prefs.getBool(_tipsKey) ?? NotificationPreferences.defaults.tips,
      activity: prefs.getBool(_activityKey) ?? NotificationPreferences.defaults.activity,
      criticalAlerts: prefs.getBool(_criticalAlertsKey) ?? NotificationPreferences.defaults.criticalAlerts,
    );
  }

  Future<void> save(NotificationPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersKey, value.reminders);
    await prefs.setBool(_tipsKey, value.tips);
    await prefs.setBool(_activityKey, value.activity);
    await prefs.setBool(_criticalAlertsKey, value.criticalAlerts);
  }

  Future<void> disableOptionalNotifications() async {
    final current = await load();
    await save(
      current.copyWith(
        reminders: false,
        tips: false,
        activity: false,
      ),
    );
  }
}
