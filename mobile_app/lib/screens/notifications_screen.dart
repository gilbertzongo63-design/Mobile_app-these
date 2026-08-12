import 'package:flutter/material.dart';
import '../l10n.dart';

import '../services/notification_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../app_routes.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _reminders = true;
  bool _tips = true;
  bool _activity = false;
  final bool _criticalAlerts = true;
  final NotificationService _notificationService = NotificationService();
  late Future<List<NotificationItem>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    _notificationsFuture = _notificationService.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F9F0);
    const darkGreen = Color(0xFF0A8A52);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              Navigator.of(context)
                                  .pushReplacementNamed(AppRoutes.settings),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: darkGreen,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)
                                .t('notifications.title'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: darkGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _NotificationsHero(),
                    const SizedBox(height: 26),
                    FutureBuilder<List<NotificationItem>>(
                      future: _notificationsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              AppLocalizations.of(context)
                                  .t('notifications.load_error'),
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          );
                        }

                        final notifications = snapshot.data ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppLocalizations.of(context)
                                      .t('notifications.recent'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0A8A52),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _loadNotifications();
                                    });
                                  },
                                  child: Text(AppLocalizations.of(context)
                                      .t('notifications.refresh')),
                                ),
                              ],
                            ),
                            if (notifications.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(AppLocalizations.of(context)
                                    .t('notifications.empty')),
                              )
                            else
                              ...notifications.map(
                                (notification) => GestureDetector(
                                  onTap: notification.isRead
                                      ? null
                                      : () async {
                                          await _notificationService
                                              .markAsRead(notification.id);
                                          setState(() {
                                            _loadNotifications();
                                          });
                                        },
                                  child: Container(
                                    width: double.infinity,
                                    margin:
                                        const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: notification.isRead
                                          ? Colors.white
                                          : const Color(0xFFEAF9F0),
                                      borderRadius:
                                          BorderRadius.circular(18),
                                      border: Border.all(
                                          color: const Color(0xFFBFE8C5)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notification.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0A8A52),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          notification.message,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF374047)),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          notification.createdAt,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6B7A6F)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 26),
                    _NotificationCard(
                      title: AppLocalizations.of(context)
                          .t('notifications.reminders.title'),
                      description: AppLocalizations.of(context)
                          .t('notifications.reminders.description'),
                      value: _reminders,
                      onChanged: (value) {
                        setState(() {
                          _reminders = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    _NotificationCard(
                      title: AppLocalizations.of(context)
                          .t('notifications.tips.title'),
                      description: AppLocalizations.of(context)
                          .t('notifications.tips.description'),
                      value: _tips,
                      onChanged: (value) {
                        setState(() {
                          _tips = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    _NotificationCard(
                      title: AppLocalizations.of(context)
                          .t('notifications.activity.title'),
                      description: AppLocalizations.of(context)
                          .t('notifications.activity.description'),
                      value: _activity,
                      onChanged: (value) {
                        setState(() {
                          _activity = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    _NotificationCard(
                      title: AppLocalizations.of(context)
                          .t('notifications.critical.title'),
                      description: AppLocalizations.of(context)
                          .t('notifications.critical.description'),
                      value: _criticalAlerts,
                      locked: true,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F8E6),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFBFE8C5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.info_outline_rounded,
                              color: darkGreen,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)
                                  .t('notifications.critical_note'),
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF284230),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppBottomNavBar(
              selectedIndex: 3,
              onChanged: (index) {
                if (index == 0) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.home,
                    (route) => false,
                  );
                } else if (index == 1) {
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.scan);
                } else if (index == 2) {
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.history);
                } else if (index == 3) {
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.settings);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsHero extends StatelessWidget {
  const _NotificationsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 272,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          AppLocalizations.of(context).t('notifications.title'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final bool locked;
  final ValueChanged<bool> onChanged;

  const _NotificationCard({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17211C),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.4,
                    color: Color(0xFF334038),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Switch(
            value: value,
            onChanged: locked ? null : onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF71F59D),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFDCE7DA),
          ),
        ],
      ),
    );
  }
}
