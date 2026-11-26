import 'package:flutter/services.dart';

/// Service to trigger scanner feedback: audible audio beep + haptic confirmation.
class BeepService {
  BeepService._();

  static const MethodChannel _channel =
      MethodChannel('com.urbanpets.verify/sound');

  /// Plays a crisp retail barcode scanner beep tone and medium haptic vibration.
  static Future<void> playScanBeep() async {
    try {
      HapticFeedback.mediumImpact();
      final played = await _channel.invokeMethod<bool>('playScanBeep');
      if (played != true) {
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }
}
