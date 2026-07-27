import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/notification_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _totalMessages = 0;
  int _streakDays = 0;
  int _wordsLearned = 0;
  bool _notificationsEnabled = true;
  int _notificationHour = 9;
  int _notificationMinute = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalMessages = prefs.getInt('total_messages') ?? 0;
      _streakDays = prefs.getInt('streak_days') ?? 0;
      _wordsLearned = prefs.getInt('words_learned') ?? 0;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _notificationHour = prefs.getInt('notification_hour') ?? 9;
      _notificationMinute = prefs.getInt('notification_minute') ?? 0;
    });
  }

  Future<void> _updateNotificationTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notification_hour', hour);
    await prefs.setInt('notification_minute', minute);
    setState(() {
      _notificationHour = hour;
      _notificationMinute = minute;
    });
    await NotificationService.scheduleDailyReminder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        backgroundColor: const Color(0xFF16213E),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statCard(
              icon: Icons.chat_bubble_outline,
              label: 'Mensajes enviados',
              value: _totalMessages.toString(),
              color: Colors.blue,
            ),
            _statCard(
              icon: Icons.local_fire_department,
              label: 'Racha de días',
              value: '$_streakDays 🔥',
              color: Colors.orange,
            ),
            _statCard(
              icon: Icons.book,
              label: 'Palabras aprendidas',
              value: _wordsLearned.toString(),
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            const Text(
              'Notificaciones',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Recordatorio diario', style: TextStyle(color: Colors.white70)),
              value: _notificationsEnabled,
              onChanged: (value) async {
                await NotificationService.setEnabled(value);
                setState(() => _notificationsEnabled = value);
              },
              activeColor: const Color(0xFF7C3AED),
            ),
            if (_notificationsEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Hora: ', style: TextStyle(color: Colors.white70)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: _notificationHour,
                            minute: _notificationMinute,
                          ),
                        );
                        if (time != null) {
                          await _updateNotificationTime(time.hour, time.minute);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A2A4A),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        '${_notificationHour.toString().padLeft(2, '0')}:${_notificationMinute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
