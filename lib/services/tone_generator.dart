import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Generates simple WAV tone files in memory or on disk.
class ToneGenerator {
  static const int _sampleRate = 44100;
  static const int _bitsPerSample = 16;
  static const int _numChannels = 1;

  /// Generate a WAV file byte buffer for a sine wave tone with decay envelope.
  static Uint8List generateToneWav({
    required double frequency,
    required int durationMs,
    double volume = 0.8,
  }) {
    final numSamples = (_sampleRate * durationMs / 1000).round();
    final dataSize = numSamples * _numChannels * (_bitsPerSample ~/ 8);
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    int offset = 0;

    // RIFF header
    buffer.setUint8(offset++, 0x52); // R
    buffer.setUint8(offset++, 0x49); // I
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    buffer.setUint8(offset++, 0x57); // W
    buffer.setUint8(offset++, 0x41); // A
    buffer.setUint8(offset++, 0x56); // V
    buffer.setUint8(offset++, 0x45); // E

    // fmt chunk
    buffer.setUint8(offset++, 0x66); // f
    buffer.setUint8(offset++, 0x6D); // m
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x20); // (space)
    buffer.setUint32(offset, 16, Endian.little); // chunk size
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM format
    offset += 2;
    buffer.setUint16(offset, _numChannels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, _sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(
      offset,
      _sampleRate * _numChannels * (_bitsPerSample ~/ 8),
      Endian.little,
    );
    offset += 4;
    buffer.setUint16(
      offset,
      _numChannels * (_bitsPerSample ~/ 8),
      Endian.little,
    );
    offset += 2;
    buffer.setUint16(offset, _bitsPerSample, Endian.little);
    offset += 2;

    // data chunk
    buffer.setUint8(offset++, 0x64); // d
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // Generate samples with exponential decay envelope
    final maxAmplitude = 32767.0 * volume;
    final decayRate = 3.0 / (numSamples); // decay over duration

    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final envelope = exp(-decayRate * i);

      // Main tone + slight harmonics for richness
      final sample = sin(2.0 * pi * frequency * t) * 0.7 +
          sin(2.0 * pi * frequency * 2.0 * t) * 0.2 +
          sin(2.0 * pi * frequency * 3.0 * t) * 0.1;

      final value = (sample * envelope * maxAmplitude).round().clamp(-32768, 32767);
      buffer.setInt16(offset, value, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  /// Write a generated tone to a temporary file and return its path.
  static Future<String> writeToneFile({
    required String name,
    required double frequency,
    required int durationMs,
    double volume = 0.8,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name.wav');
    final data = generateToneWav(
      frequency: frequency,
      durationMs: durationMs,
      volume: volume,
    );
    await file.writeAsBytes(data);
    return file.path;
  }
}
