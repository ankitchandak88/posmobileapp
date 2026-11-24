import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/storage/quick_unlock_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// A simple numeric keypad that collects exactly [length] digits and then
/// calls [onSubmitted]. Used for both setting and entering the quick-unlock
/// PIN. Stateless about validity — the caller decides what a submitted PIN
/// means (first entry, confirmation, or an unlock attempt).
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.length,
    required this.onSubmitted,
    this.errorText,
  });

  final int length;
  final ValueChanged<String> onSubmitted;
  final String? errorText;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _entered = '';

  @override
  void didUpdateWidget(PinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != null && widget.errorText != oldWidget.errorText) {
      HapticFeedback.heavyImpact();
    }
  }

  void _tap(String digit) {
    if (_entered.length >= widget.length) return;
    HapticFeedback.lightImpact();
    setState(() => _entered += digit);
    if (_entered.length == widget.length) {
      final pin = _entered;
      setState(() => _entered = '');
      widget.onSubmitted(pin);
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            key: const Key('pin_dots_row'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (i) {
              final filled = i < _entered.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? AppColors.navy : Colors.transparent,
                  border: Border.all(color: AppColors.navy, width: 1.5),
                ),
              );
            }),
          ),
          if (widget.errorText != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.errorText!,
              key: const Key('pin_error_text'),
              style: const TextStyle(color: AppColors.critical),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((d) => _key(d, () => _tap(d))).toList(),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 72),
              _key('0', () => _tap('0')),
              _iconKey(Icons.backspace_outlined, _backspace),
            ],
          ),
        ],
      ),
    );
  }

  Widget _key(String label, VoidCallback onTap) {
    return InkWell(
      key: Key('pin_key_$label'),
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: Text(label, style: AppTextStyles.h1),
      ),
    );
  }

  Widget _iconKey(IconData icon, VoidCallback onTap) {
    return InkWell(
      key: const Key('pin_key_backspace'),
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Icon(icon, color: AppColors.textMuted),
      ),
    );
  }
}

/// Reusable "enter it twice" PIN-setup flow — used both by the post-login
/// quick-unlock prompt and by Profile's "Set/Change PIN" action. Pops the
/// chosen PIN back to the caller via [Navigator.pop] once both entries
/// match; the caller is responsible for actually persisting it.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _firstPin;
  String? _error;

  void _onSubmitted(String pin) {
    if (_firstPin == null) {
      setState(() {
        _firstPin = pin;
        _error = null;
      });
      return;
    }
    if (pin == _firstPin) {
      Navigator.of(context).pop(pin);
    } else {
      setState(() {
        _firstPin = null;
        _error = "PINs didn't match. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _firstPin != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(confirming ? 'Confirm PIN' : 'Set a 4-digit PIN'),
      ),
      body: PinPad(
        key: ValueKey(confirming),
        length: QuickUnlockService.pinLength,
        errorText: _error,
        onSubmitted: _onSubmitted,
      ),
    );
  }
}
