import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../state/scanner_providers.dart';

/// Real camera barcode scanner wired to mobile_scanner, with a manual-entry
/// fallback shown automatically when the camera/permission is unavailable
/// (handles permission denial gracefully per master prompt §10/§15).
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key, required this.mode, this.taskId});

  /// 'stock_count' | 'expiry_check' | 'view'
  final String mode;
  final String? taskId;

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _controller;
  bool _cameraUnavailable = false;
  bool _torchEnabled = false;
  double _zoomLevel = 0.0;
  bool _processing = false;
  String? _lastError;
  String? _lastScannedBarcode;
  final _manualController = TextEditingController();
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      autoZoom: true,
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller?.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _setZoom(double zoom) async {
    HapticFeedback.selectionClick();
    setState(() => _zoomLevel = zoom);
    try {
      await _controller?.setZoomScale(zoom);
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller?.toggleTorch();
      if (mounted) {
        setState(() => _torchEnabled = !_torchEnabled);
      }
    } catch (_) {
      // Ignored if torch is unavailable on the device
    }
  }

  Future<void> _handleCode(String code) async {
    if (_processing) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.alert);
    setState(() {
      _processing = true;
      _lastError = null;
      _lastScannedBarcode = code;
    });
    try {
      final item = await ref.read(itemRepositoryProvider).byBarcode(code);
      if (!mounted) return;
      await _navigateToEntry(item, code);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastError = e is ApiException
            ? 'Unknown barcode ($code). You can request a mapping or try manual entry.'
            : e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        _controller?.start();
      }
    }
  }

  Future<void> _navigateToEntry(dynamic item, String scannedCode) async {
    try {
      _controller?.stop();
    } catch (_) {}
    if (widget.mode == 'purchase') {
      if (context.canPop()) {
        context.pop(scannedCode);
      } else {
        context.pushReplacement(
          '/purchase-lookup',
          extra: {'code': scannedCode},
        );
      }
      return;
    }
    if (widget.mode == 'inward') {
      if (context.canPop()) {
        context.pop(item);
      } else {
        context.pushReplacement(
          '/inward-entry',
          extra: {'item': item},
        );
      }
      return;
    }
    if (widget.mode == 'expiry_check') {
      await context.push(
        '/expiry-check',
        extra: {'item': item, 'batch': null, 'taskId': widget.taskId},
      );
    } else if (widget.mode == 'view') {
      await context.push(
        '/quick-item-view',
        extra: {'item': item, 'taskId': widget.taskId},
      );
    } else {
      await context.push(
        '/stock-count',
        extra: {'item': item, 'batch': null, 'taskId': widget.taskId},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == 'expiry_check'
        ? 'Scan — Expiry Check'
        : (widget.mode == 'purchase'
              ? 'Scan — Purchase Lookup'
              : (widget.mode == 'view'
                    ? 'Scan — Item View'
                    : (widget.mode == 'inward'
                          ? 'Scan — Inward Stock'
                          : 'Scan — Stock & Expiry')));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.navy,
        actions: [
          if (!_cameraUnavailable)
            IconButton(
              icon: Icon(
                _torchEnabled
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                color: _torchEnabled ? AppColors.warning : Colors.white,
              ),
              tooltip: _torchEnabled ? 'Turn Flash Off' : 'Turn Flash On',
              onPressed: _toggleTorch,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _cameraUnavailable
                ? _buildManualFallback()
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        errorBuilder: (context, error) {
                          // Camera/permission unavailable — show manual entry
                          // instead of crashing (permission-denial handling).
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && !_cameraUnavailable) {
                              setState(() => _cameraUnavailable = true);
                            }
                          });
                          return _buildManualFallback();
                        },
                        onDetect: (capture) {
                          final barcodes = capture.barcodes;
                          if (barcodes.isEmpty) return;
                          final value = barcodes.first.rawValue;
                          if (value != null && value.isNotEmpty) {
                            _handleCode(value);
                          }
                        },
                      ),
                      _ScannerReticle(animation: _animController),
                      Positioned(
                        bottom: AppSpacing.md,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ZoomButton(
                                  label: '1x',
                                  selected: _zoomLevel == 0.0,
                                  onTap: () => _setZoom(0.0),
                                ),
                                const SizedBox(width: 4),
                                _ZoomButton(
                                  label: '2x',
                                  selected: _zoomLevel == 0.45,
                                  onTap: () => _setZoom(0.45),
                                ),
                                const SizedBox(width: 4),
                                _ZoomButton(
                                  label: '3x',
                                  selected: _zoomLevel == 0.85,
                                  onTap: () => _setZoom(0.85),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 12,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_processing)
                  const LoadingState(message: 'Looking up item…'),
                if (_lastError != null) ...[
                  Text(
                    _lastError!,
                    style: const TextStyle(
                      color: AppColors.critical,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Request Barcode Mapping',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.push(
                      '/barcode-mapping',
                      extra: {'scannedBarcode': _lastScannedBarcode},
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (!_cameraUnavailable)
                  TextButton.icon(
                    onPressed: () => setState(() => _cameraUnavailable = true),
                    icon: const Icon(Icons.keyboard_outlined),
                    label: const Text('Enter barcode manually'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualFallback() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Camera unavailable or permission denied',
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enter the barcode manually below.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Barcode',
            controller: _manualController,
            hintText: 'e.g. 8901234567890',
            prefixIcon: Icons.numbers,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Look up',
            onPressed: () {
              final code = _manualController.text.trim();
              if (code.isNotEmpty) _handleCode(code);
            },
          ),
        ],
      ),
    );
  }
}

class _ScannerReticle extends StatelessWidget {
  const _ScannerReticle({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _ReticlePainter(progress: animation.value),
          child: child,
        );
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 280),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 16,
                    color: AppColors.primaryBlueLight,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Align barcode inside the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  _ReticlePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final boxSize = (size.width * 0.72).clamp(220.0, 270.0);
    final left = (size.width - boxSize) / 2;
    final top = (size.height - boxSize) / 2;
    final rect = Rect.fromLTWH(left, top, boxSize, boxSize);

    // 1. Semi-transparent backdrop scrim outside scan window
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    // 2. Corner brackets
    final cornerPaint = Paint()
      ..color = AppColors.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;
    const cornerRadius = 16.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top + cornerRadius)
        ..arcToPoint(
          Offset(left + cornerRadius, top),
          radius: const Radius.circular(cornerRadius),
        )
        ..lineTo(left + cornerLength, top),
      cornerPaint,
    );

    // Top-right
    final right = left + boxSize;
    canvas.drawPath(
      Path()
        ..moveTo(right - cornerLength, top)
        ..lineTo(right - cornerRadius, top)
        ..arcToPoint(
          Offset(right, top + cornerRadius),
          radius: const Radius.circular(cornerRadius),
        )
        ..lineTo(right, top + cornerLength),
      cornerPaint,
    );

    // Bottom-left
    final bottom = top + boxSize;
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - cornerLength)
        ..lineTo(left, bottom - cornerRadius)
        ..arcToPoint(
          Offset(left + cornerRadius, bottom),
          radius: const Radius.circular(cornerRadius),
        )
        ..lineTo(left + cornerLength, bottom),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(right - cornerLength, bottom)
        ..lineTo(right - cornerRadius, bottom)
        ..arcToPoint(
          Offset(right, bottom - cornerRadius),
          radius: const Radius.circular(cornerRadius),
        )
        ..lineTo(right, bottom - cornerLength),
      cornerPaint,
    );

    // 3. Animated scanning laser beam with soft glow
    final laserY = top + (boxSize * progress);

    // Subtle laser beam glow
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primaryBlue.withValues(alpha: 0.0),
          AppColors.primaryBlueLight.withValues(alpha: 0.35),
          AppColors.primaryBlue.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(left + 8, laserY - 3, boxSize - 16, 8))
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(left + 14, laserY),
      Offset(right - 14, laserY),
      glowPaint,
    );

    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primaryBlue.withValues(alpha: 0.0),
          AppColors.primaryBlueLight,
          AppColors.primaryBlue.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(left + 8, laserY, boxSize - 16, 2))
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(left + 12, laserY),
      Offset(right - 12, laserY),
      laserPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
