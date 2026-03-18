import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/chime_settings.dart';
import 'tone_generator.dart';

class ChimeService extends ChangeNotifier {
  ChimeSettings settings;
  Timer? _timer;
  DateTime? _nextChimeTime;
  bool _isChiming = false;

  String? _dongFilePath;
  String? _dingFilePath;

  final AudioPlayer _audioPlayer = AudioPlayer();

  ChimeService({required this.settings});

  DateTime? get nextChimeTime => _nextChimeTime;
  bool get isChiming => _isChiming;
  bool get isRunning => _timer != null;

  /// Start the chime timer.
  Future<void> start() async {
    settings.isActive = true;
    await settings.save();
    await _prepareSounds();
    _scheduleNext();
    notifyListeners();
  }

  /// Stop the chime timer.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _nextChimeTime = null;
    settings.isActive = false;
    await settings.save();
    notifyListeners();
  }

  /// Update settings and restart if active.
  Future<void> updateSettings(ChimeSettings newSettings) async {
    final wasActive = isRunning;
    if (wasActive) await stop();
    settings = newSettings;
    await settings.save();
    if (wasActive) await start();
    notifyListeners();
  }

  /// Prepare sound files, with fallback for missing custom sounds.
  Future<void> _prepareSounds() async {
    _dongFilePath = await _resolveSound(
      customPath: settings.customDongPath,
      name: 'dong',
      frequency: settings.dongFrequency,
      durationMs: settings.dongDurationMs,
    );

    _dingFilePath = await _resolveSound(
      customPath: settings.customDingPath,
      name: 'ding',
      frequency: settings.dingFrequency,
      durationMs: settings.dingDurationMs,
    );
  }

  Future<String> _resolveSound({
    required String? customPath,
    required String name,
    required double frequency,
    required int durationMs,
  }) async {
    if (customPath != null && await File(customPath).exists()) {
      return customPath;
    }
    if (customPath != null) {
      debugPrint('ChimeService: Custom $name file not found at "$customPath", falling back to generated tone.');
    }
    return ToneGenerator.writeToneFile(
      name: name,
      frequency: frequency,
      durationMs: durationMs,
      volume: settings.volume,
    );
  }

  /// Generate a preview tone with the given draft parameters (not yet saved).
  Future<void> previewTone({
    required double frequency,
    required int durationMs,
    required double volume,
    String? customPath,
  }) async {
    final path = await _resolveSound(
      customPath: customPath,
      name: 'preview',
      frequency: frequency,
      durationMs: durationMs,
    );
    await _playSound(path, durationMs);
  }

  /// Calculate the next chime time aligned to the interval.
  DateTime _calculateNextChime() {
    final now = DateTime.now();
    final intervalSecs = settings.intervalMinutes * 60;
    final secondsSinceMidnight =
        now.hour * 3600 + now.minute * 60 + now.second;
    final nextIntervalSecs =
        ((secondsSinceMidnight ~/ intervalSecs) + 1) * intervalSecs;

    final midnight = DateTime(now.year, now.month, now.day);
    return midnight.add(Duration(seconds: nextIntervalSecs));
  }

  void _scheduleNext() {
    _nextChimeTime = _calculateNextChime();
    final delay = _nextChimeTime!.difference(DateTime.now());

    _timer?.cancel();
    _timer = Timer(delay, () async {
      await _playChime();
      if (settings.isActive) {
        _scheduleNext();
        notifyListeners();
      }
    });
    notifyListeners();
  }

  /// Play the chime sequence: dongs for hour, then dings for 10-min subdivisions.
  Future<void> _playChime() async {
    _isChiming = true;
    notifyListeners();

    final now = DateTime.now();
    final dongs = ChimeSettings.dongsForHour(now.hour);
    final dings = ChimeSettings.dingsForMinute(now.minute);

    // Play dongs
    for (int i = 0; i < dongs; i++) {
      await _playSound(_dongFilePath!, settings.dongDurationMs);
      if (i < dongs - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    // Pause between dongs and dings
    if (dings > 0) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Play dings
    for (int i = 0; i < dings; i++) {
      await _playSound(_dingFilePath!, settings.dingDurationMs);
      if (i < dings - 1) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    _isChiming = false;
    notifyListeners();
  }

  Future<void> _playSound(String filePath, int durationMs) async {
    final completer = Completer<void>();
    late StreamSubscription<void> subscription;
    subscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await _audioPlayer.setVolume(settings.volume);
    await _audioPlayer.play(DeviceFileSource(filePath));

    try {
      await completer.future
          .timeout(Duration(milliseconds: durationMs + 500), onTimeout: () {});
    } finally {
      await subscription.cancel();
    }
  }

  /// Preview the dong sound using current saved settings.
  Future<void> previewDong() async {
    await _prepareSounds();
    await _playSound(_dongFilePath!, settings.dongDurationMs);
  }

  /// Preview the ding sound using current saved settings.
  Future<void> previewDing() async {
    await _prepareSounds();
    await _playSound(_dingFilePath!, settings.dingDurationMs);
  }

  /// Preview the full chime for the current time.
  Future<void> previewCurrentChime() async {
    await _prepareSounds();
    await _playChime();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
