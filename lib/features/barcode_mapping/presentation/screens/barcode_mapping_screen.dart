import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/state/auth_providers.dart';
import '../../../dashboard/state/dashboard_providers.dart';
import '../../data/barcode_mapping_repository.dart';

/// Unknown-barcode mapping request screen: staff flags a scanned barcode
/// that doesn't resolve to a product, for authorized manager review.
class BarcodeMappingScreen extends ConsumerStatefulWidget {
  const BarcodeMappingScreen({super.key, this.scannedBarcode});

  final String? scannedBarcode;

  @override
  ConsumerState<BarcodeMappingScreen> createState() =>
      _BarcodeMappingScreenState();
}

class _BarcodeMappingScreenState extends ConsumerState<BarcodeMappingScreen> {
  late final TextEditingController _barcodeController;
  final _remarksController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(
      text: widget.scannedBarcode ?? '',
    );
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_barcodeController.text.trim().isEmpty) {
      setState(() => _error = 'Barcode is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final branches = ref.read(branchesProvider).value;
    final branchId = ref.read(selectedBranchIdProvider) ??
        ref.read(authControllerProvider).user?.branchId ??
        (branches != null && branches.isNotEmpty ? branches.first.id : '1');
    try {
      await ref
          .read(barcodeMappingRepositoryProvider)
          .submitRequest(
            scannedBarcode: _barcodeController.text.trim(),
            branchId: branchId,
            remarks: _remarksController.text.trim().isEmpty
                ? null
                : _remarksController.text.trim(),
          );
      setState(() => _submitted = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Barcode Mapping')),
      body: _submitted
          ? EmptyState(
              title: 'Request submitted',
              message:
                  'A manager will review this unknown barcode and map it to the correct product.',
              icon: Icons.check_circle_outline,
              actionLabel: 'Back to Home',
              onAction: () => context.go('/home'),
            )
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'Scanned Barcode',
                    controller: _barcodeController,
                    hintText: 'e.g. 8901234567890',
                    prefixIcon: Icons.qr_code,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Remarks (Optional)',
                    controller: _remarksController,
                    hintText: 'Any notes to help identify the product',
                    maxLines: 3,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Submit Request',
                    loading: _submitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
    );
  }
}

final barcodeMappingRepositoryProvider = Provider<BarcodeMappingRepository>((
  ref,
) {
  return BarcodeMappingRepository(apiClient: ref.read(apiClientProvider));
});
