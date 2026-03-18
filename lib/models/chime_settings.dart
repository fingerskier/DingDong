import 'package:shared_preferences/shared_preferences.dart';

class ChimeSettings {
  /// Interval in minutes between chimes.
  int intervalMinutes;

  /// Path to custom dong sound file, or null for built-in tone.
  String? customDongPath;

  /// Path to custom ding sound file, or null for built-in tone.
  String? customDingPath;

  /// Dong frequency in Hz (used when no custom sound).
  double dongFrequency;

  /// Ding frequency in Hz (used when no custom sound).
  double dingFrequency;

  /// Dong duration in milliseconds.
  int dongDurationMs;

  /// Ding duration in milliseconds.
  int dingDurationMs;

  /// Volume from 0.0 to 1.0.
  double volume;

  /// Whether chiming is active.
  bool isActive;

  /// Whether to keep screen on while active.
  bool keepScreenOn;

  ChimeSettings({
    this.intervalMinutes = 10,
    this.customDongPath,
    this.customDingPath,
    this.dongFrequency = 262.0, // Middle C
    this.dingFrequency = 523.0, // C5
    this.dongDurationMs = 600,
    this.dingDurationMs = 350,
    this.volume = 0.8,
    this.isActive = false,
    this.keepScreenOn = true,
  });

  /// Calculate the number of dongs for a given hour (12-hour format).
  static int dongsForHour(int hour24) {
    final h = hour24 % 12;
    return h == 0 ? 12 : h;
  }

  /// Calculate the number of dings for the 10-minute subdivisions.
  static int dingsForMinute(int minute) {
    return minute ~/ 10;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('intervalMinutes', intervalMinutes);
    await prefs.setString('customDongPath', customDongPath ?? '');
    await prefs.setString('customDingPath', customDingPath ?? '');
    await prefs.setDouble('dongFrequency', dongFrequency);
    await prefs.setDouble('dingFrequency', dingFrequency);
    await prefs.setInt('dongDurationMs', dongDurationMs);
    await prefs.setInt('dingDurationMs', dingDurationMs);
    await prefs.setDouble('volume', volume);
    await prefs.setBool('isActive', isActive);
    await prefs.setBool('keepScreenOn', keepScreenOn);
  }

  static Future<ChimeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final dongPath = prefs.getString('customDongPath') ?? '';
    final dingPath = prefs.getString('customDingPath') ?? '';
    final interval = (prefs.getInt('intervalMinutes') ?? 10).clamp(1, 60);
    return ChimeSettings(
      intervalMinutes: interval,
      customDongPath: dongPath.isEmpty ? null : dongPath,
      customDingPath: dingPath.isEmpty ? null : dingPath,
      dongFrequency: prefs.getDouble('dongFrequency') ?? 262.0,
      dingFrequency: prefs.getDouble('dingFrequency') ?? 523.0,
      dongDurationMs: prefs.getInt('dongDurationMs') ?? 600,
      dingDurationMs: prefs.getInt('dingDurationMs') ?? 350,
      volume: prefs.getDouble('volume') ?? 0.8,
      isActive: prefs.getBool('isActive') ?? false,
      keepScreenOn: prefs.getBool('keepScreenOn') ?? true,
    );
  }
}
