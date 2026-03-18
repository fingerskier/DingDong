import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/chime_settings.dart';
import '../services/chime_service.dart';

class HomeScreen extends StatefulWidget {
  final ChimeService chimeService;

  const HomeScreen({super.key, required this.chimeService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer _clockTimer;

  ChimeService get _chime => widget.chimeService;

  @override
  void initState() {
    super.initState();
    _chime.addListener(_onChimeUpdate);
    // Update the clock display every second
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
    _restoreState();
  }

  Future<void> _restoreState() async {
    if (_chime.settings.isActive) {
      await _chime.start();
      if (_chime.settings.keepScreenOn) {
        await WakelockPlus.enable();
      }
    }
  }

  void _onChimeUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _chime.removeListener(_onChimeUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dongs = ChimeSettings.dongsForHour(now.hour);
    final dings = ChimeSettings.dingsForMinute(now.minute);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DingDong'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(flex: 1),
              // Current time display
              Text(
                _formatTime(now),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w300,
                  fontSize: 64,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(now),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              // Chime preview for current time
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Current chime pattern',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ChimeIndicator(
                          label: 'DONG',
                          count: dongs,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 32),
                        _ChimeIndicator(
                          label: 'DING',
                          count: dings,
                          color: theme.colorScheme.tertiary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Interval display
              Text(
                'Every ${_chime.settings.intervalMinutes} min',
                style: theme.textTheme.titleMedium,
              ),
              if (_chime.nextChimeTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Next: ${_formatTime(_chime.nextChimeTime!)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              if (_chime.isChiming) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_note,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Chiming...',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(flex: 2),
              // Preview button
              OutlinedButton.icon(
                onPressed: _chime.isChiming
                    ? null
                    : () => _chime.previewCurrentChime(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Preview Current Time'),
              ),
              const SizedBox(height: 16),
              // Start/Stop button
              SizedBox(
                width: 200,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _toggleChime,
                  icon: Icon(
                    _chime.isRunning ? Icons.stop : Icons.play_arrow,
                  ),
                  label: Text(_chime.isRunning ? 'Stop' : 'Start'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _chime.isRunning
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleChime() async {
    if (_chime.isRunning) {
      await _chime.stop();
      await WakelockPlus.disable();
    } else {
      await _chime.start();
      if (_chime.settings.keepScreenOn) {
        await WakelockPlus.enable();
      }
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _SettingsSheet(
        settings: _chime.settings,
        onSave: (newSettings) async {
          await _chime.updateSettings(newSettings);
          if (_chime.isRunning) {
            if (newSettings.keepScreenOn) {
              await WakelockPlus.enable();
            } else {
              await WakelockPlus.disable();
            }
          }
        },
        chimeService: _chime,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m:$s $ampm';
  }

  String _formatDate(DateTime dt) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }
}

class _ChimeIndicator extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ChimeIndicator({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.7),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  final ChimeSettings settings;
  final Future<void> Function(ChimeSettings) onSave;
  final ChimeService chimeService;

  const _SettingsSheet({
    required this.settings,
    required this.onSave,
    required this.chimeService,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late int _interval;
  late double _dongFreq;
  late double _dingFreq;
  late int _dongDuration;
  late int _dingDuration;
  late double _volume;
  late bool _keepScreenOn;
  String? _customDongPath;
  String? _customDingPath;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _interval = s.intervalMinutes;
    _dongFreq = s.dongFrequency;
    _dingFreq = s.dingFrequency;
    _dongDuration = s.dongDurationMs;
    _dingDuration = s.dingDurationMs;
    _volume = s.volume;
    _keepScreenOn = s.keepScreenOn;
    _customDongPath = s.customDongPath;
    _customDingPath = s.customDingPath;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Settings',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Interval
            Text('Chime Interval', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _interval.toDouble(),
                    min: 1,
                    max: 60,
                    divisions: 59,
                    label: '$_interval min',
                    onChanged: (v) => setState(() => _interval = v.round()),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '$_interval min',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Volume
            Text('Volume', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.volume_down, size: 20),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) => setState(() => _volume = v),
                  ),
                ),
                const Icon(Icons.volume_up, size: 20),
              ],
            ),
            const SizedBox(height: 24),

            // Dong settings
            _buildSoundSection(
              title: 'Dong Sound (hours)',
              frequency: _dongFreq,
              duration: _dongDuration,
              customPath: _customDongPath,
              onFreqChanged: (v) => setState(() => _dongFreq = v),
              onDurationChanged: (v) => setState(() => _dongDuration = v),
              onPickFile: () => _pickSoundFile(isDong: true),
              onClearFile: () => setState(() => _customDongPath = null),
              onPreview: () => widget.chimeService.previewTone(
                frequency: _dongFreq,
                durationMs: _dongDuration,
                volume: _volume,
                customPath: _customDongPath,
              ),
              freqRange: const RangeValues(100, 500),
            ),
            const SizedBox(height: 24),

            // Ding settings
            _buildSoundSection(
              title: 'Ding Sound (10-min marks)',
              frequency: _dingFreq,
              duration: _dingDuration,
              customPath: _customDingPath,
              onFreqChanged: (v) => setState(() => _dingFreq = v),
              onDurationChanged: (v) => setState(() => _dingDuration = v),
              onPickFile: () => _pickSoundFile(isDong: false),
              onClearFile: () => setState(() => _customDingPath = null),
              onPreview: () => widget.chimeService.previewTone(
                frequency: _dingFreq,
                durationMs: _dingDuration,
                volume: _volume,
                customPath: _customDingPath,
              ),
              freqRange: const RangeValues(300, 1000),
            ),
            const SizedBox(height: 24),

            // Keep screen on
            SwitchListTile(
              title: const Text('Keep screen on'),
              subtitle: const Text('Prevents the screen from sleeping'),
              value: _keepScreenOn,
              onChanged: (v) => setState(() => _keepScreenOn = v),
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton(
              onPressed: _save,
              child: const Text('Save Settings'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundSection({
    required String title,
    required double frequency,
    required int duration,
    required String? customPath,
    required ValueChanged<double> onFreqChanged,
    required ValueChanged<int> onDurationChanged,
    required VoidCallback onPickFile,
    required VoidCallback onClearFile,
    required VoidCallback onPreview,
    required RangeValues freqRange,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: theme.textTheme.titleSmall),
            ),
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              onPressed: onPreview,
              tooltip: 'Preview',
            ),
          ],
        ),
        if (customPath != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.audio_file, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customPath.split('/').last,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onClearFile,
                child: const Text('Reset'),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text('Frequency: ${frequency.round()} Hz'),
          Slider(
            value: frequency,
            min: freqRange.start,
            max: freqRange.end,
            onChanged: onFreqChanged,
          ),
          Text('Duration: $duration ms'),
          Slider(
            value: duration.toDouble(),
            min: 100,
            max: 1500,
            divisions: 28,
            onChanged: (v) => onDurationChanged(v.round()),
          ),
        ],
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: onPickFile,
          icon: const Icon(Icons.folder_open, size: 18),
          label: const Text('Use custom sound file'),
        ),
      ],
    );
  }

  Future<void> _pickSoundFile({required bool isDong}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        if (isDong) {
          _customDongPath = result.files.single.path;
        } else {
          _customDingPath = result.files.single.path;
        }
      });
    }
  }

  Future<void> _save() async {
    final newSettings = ChimeSettings(
      intervalMinutes: _interval,
      customDongPath: _customDongPath,
      customDingPath: _customDingPath,
      dongFrequency: _dongFreq,
      dingFrequency: _dingFreq,
      dongDurationMs: _dongDuration,
      dingDurationMs: _dingDuration,
      volume: _volume,
      isActive: widget.settings.isActive,
      keepScreenOn: _keepScreenOn,
    );
    await widget.onSave(newSettings);
    if (mounted) Navigator.of(context).pop();
  }
}
