import 'dart:io';
import 'dart:math';
import 'dart:typed_list';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

final Map<String, String> _soundFiles = {};
final List<AudioPlayer> _playerPool = [];
int _nextPlayerIndex = 0;
const int _poolSize = 8;

Future<void> initAudioEngineImpl() async {
  final dir = await getTemporaryDirectory();
  final dirPath = dir.path;
  
  await _initSound('playLaser', () => _generateLaser(22050), dirPath);
  await _initSound('playEnemyLaser', () => _generateEnemyLaser(22050), dirPath);
  await _initSound('playExplosion', () => _generateExplosion(22050), dirPath);
  await _initSound('playHit', () => _generateHit(22050), dirPath);
  await _initSound('playPowerUp', () => _generatePowerUp(22050), dirPath);
  await _initSound('playGameOver', () => _generateGameOver(22050), dirPath);

  // Pre-allocate audio player pool
  _playerPool.clear();
  for (int i = 0; i < _poolSize; i++) {
    _playerPool.add(AudioPlayer());
  }
}

Future<void> _initSound(String name, List<double> Function() generator, String dirPath) async {
  final filePath = '$dirPath/neon_$name.wav';
  final file = File(filePath);
  
  // Always regenerate or check existence
  if (!await file.exists()) {
    final samples = generator();
    final bytes = _generateWavBytes(samples, 22050);
    await file.writeAsBytes(bytes);
  }
  _soundFiles[name] = filePath;
}

void playSfxImpl(String name, double volume) {
  final filePath = _soundFiles[name];
  if (filePath == null) return;

  try {
    if (_playerPool.isEmpty) return;
    
    final player = _playerPool[_nextPlayerIndex];
    _nextPlayerIndex = (_nextPlayerIndex + 1) % _poolSize;

    player.stop().then((_) {
      player.play(DeviceFileSource(filePath), volume: volume);
    });
  } catch (_) {
    // Ignore native playback errors (e.g. headless runners/no audio device)
  }
}

// ============================================================================
// WAV Byte Generator (16-bit Mono PCM)
// ============================================================================
Uint8List _generateWavBytes(List<double> samples, int sampleRate) {
  final int dataSize = samples.length * 2;
  final int fileSize = 36 + dataSize;
  final ByteData header = ByteData(44);

  // RIFF header
  header.setUint8(0, 0x52); // 'R'
  header.setUint8(1, 0x49); // 'I'
  header.setUint8(2, 0x46); // 'F'
  header.setUint8(3, 0x46); // 'F'
  header.setUint32(4, fileSize, Endian.little);
  
  // WAVE
  header.setUint8(8, 0x57); // 'W'
  header.setUint8(9, 0x41); // 'A'
  header.setUint8(10, 0x56); // 'V'
  header.setUint8(11, 0x45); // 'E'
  
  // fmt 
  header.setUint8(12, 0x66); // 'f'
  header.setUint8(13, 0x6d); // 'm'
  header.setUint8(14, 0x74); // 't'
  header.setUint8(15, 0x20); // ' '
  header.setUint32(16, 16, Endian.little); // Subchunk size (16 for PCM)
  header.setUint16(20, 1, Endian.little);  // Audio format (1 = PCM)
  header.setUint16(22, 1, Endian.little);  // Number of channels (1 = Mono)
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // Byte rate (sampleRate * 2)
  header.setUint16(32, 2, Endian.little);  // Block align
  header.setUint16(34, 16, Endian.little); // Bits per sample (16)
  
  // data
  header.setUint8(36, 0x64); // 'd'
  header.setUint8(37, 0x61); // 'a'
  header.setUint8(38, 0x74); // 't'
  header.setUint8(39, 0x61); // 'a'
  header.setUint32(40, dataSize, Endian.little);

  final Uint8List fileBytes = Uint8List(44 + dataSize);
  fileBytes.setRange(0, 44, header.buffer.asUint8List());

  final ByteData dataView = ByteData.sublistView(fileBytes, 44);
  for (int i = 0; i < samples.length; i++) {
    double s = samples[i].clamp(-1.0, 1.0);
    int val = (s * 32767.0).round();
    dataView.setInt16(i * 2, val, Endian.little);
  }

  return fileBytes;
}

// ============================================================================
// Sound Synthesis Algorithms (Matching Web Audio equivalents)
// ============================================================================

List<double> _generateLaser(int sampleRate) {
  final double duration = 0.15;
  final int numSamples = (sampleRate * duration).round();
  final List<double> samples = List.filled(numSamples, 0.0);
  double phase = 0.0;
  
  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    // Exponential frequency sweep: starts at 820Hz, ramps down to 110Hz
    final double freq = 820.0 * pow(110.0 / 820.0, t / duration);
    phase += 2.0 * pi * freq / sampleRate;
    
    // Sawtooth wave formulation
    final double p = phase / (2.0 * pi);
    final double sample = 2.0 * (p - p.round());
    // Volume envelope: linear ramp to 0
    final double vol = 1.0 - (t / duration);
    samples[i] = sample * vol * 0.35;
  }
  return samples;
}

List<double> _generateEnemyLaser(int sampleRate) {
  final double duration = 0.12;
  final int numSamples = (sampleRate * duration).round();
  final List<double> samples = List.filled(numSamples, 0.0);
  double phase = 0.0;
  
  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    // Exponential frequency sweep: starts at 620Hz, ramps down to 140Hz
    final double freq = 620.0 * pow(140.0 / 620.0, t / duration);
    phase += 2.0 * pi * freq / sampleRate;
    
    // Triangle wave formulation
    final double p = phase / (2.0 * pi);
    final double sample = 2.0 * (2.0 * (p - p.round())).abs() - 1.0;
    // Volume envelope: linear ramp to 0
    final double vol = 1.0 - (t / duration);
    samples[i] = sample * vol * 0.2;
  }
  return samples;
}

List<double> _generateExplosion(int sampleRate) {
  final double duration = 0.28;
  final int numSamples = (sampleRate * duration).round();
  final List<double> samples = List.filled(numSamples, 0.0);
  final Random rand = Random();
  double lastOutput = 0.0;
  
  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    final double rawNoise = rand.nextDouble() * 2.0 - 1.0;
    
    // Exponential sweeping lowpass filter cutoff from 750Hz to 75Hz
    final double cutoff = 750.0 * pow(75.0 / 750.0, t / duration);
    final double dt = 1.0 / sampleRate;
    final double rc = 1.0 / (2.0 * pi * cutoff);
    final double alpha = dt / (rc + dt);
    
    // Apply first-order lowpass filter to white noise
    final double filtered = lastOutput + alpha * (rawNoise - lastOutput);
    lastOutput = filtered;
    
    // Exponential volume decay
    final double vol = exp(-4.0 * t / duration);
    samples[i] = filtered * vol * 0.5;
  }
  return samples;
}

List<double> _generateHit(int sampleRate) {
  final double duration = 0.09;
  final int numSamples = (sampleRate * duration).round();
  final List<double> samples = List.filled(numSamples, 0.0);
  double phase = 0.0;
  
  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    // Linear frequency sweep from 380Hz down to 70Hz
    final double freq = 380.0 - (310.0 * (t / duration));
    phase += 2.0 * pi * freq / sampleRate;
    
    // Triangle wave formulation
    final double p = phase / (2.0 * pi);
    final double sample = 2.0 * (2.0 * (p - p.round())).abs() - 1.0;
    // Volume envelope: linear ramp to 0
    final double vol = 1.0 - (t / duration);
    samples[i] = sample * vol * 0.25;
  }
  return samples;
}

List<double> _generatePowerUp(int sampleRate) {
  final double noteSpacing = 0.075;
  final double noteDuration = 0.11;
  final double totalDuration = noteSpacing * 3 + noteDuration;
  final int numSamples = (sampleRate * totalDuration).round();
  final List<double> samples = List.filled(numSamples, 0.0);
  
  final freqs = [261.63, 329.63, 392.00, 523.25]; // C4 -> E4 -> G4 -> C5
  
  for (int noteIdx = 0; noteIdx < 4; noteIdx++) {
    final double startTime = noteIdx * noteSpacing;
    final int startSample = (startTime * sampleRate).round();
    final int noteLength = (noteDuration * sampleRate).round();
    final double freq = freqs[noteIdx];
    
    for (int j = 0; j < noteLength; j++) {
      final int idx = startSample + j;
      if (idx >= numSamples) break;
      final double t = j / sampleRate;
      final double sample = sin(2.0 * pi * freq * t);
      // Exponential volume decay for each note
      final double vol = exp(-4.0 * t / noteDuration);
      samples[idx] += sample * vol * 0.12;
    }
  }
  return samples;
}

List<double> _generateGameOver(int sampleRate) {
  final double duration = 0.75;
  final int numSamples = (sampleRate * duration).round();
  final List<double> samples = List.filled(numSamples, 0.0);
  double phase = 0.0;
  
  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    // Linear frequency sweep from 240Hz down to 30Hz
    final double freq = 240.0 - (210.0 * (t / duration));
    phase += 2.0 * pi * freq / sampleRate;
    
    // Sawtooth wave formulation
    final double p = phase / (2.0 * pi);
    final double sample = 2.0 * (p - p.round());
    // Volume envelope: linear ramp to 0
    final double vol = 1.0 - (t / duration);
    samples[i] = sample * vol * 0.25;
  }
  return samples;
}
