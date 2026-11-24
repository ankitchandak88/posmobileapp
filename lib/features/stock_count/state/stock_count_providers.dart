import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/models.dart';
import '../../review/data/observation_repository.dart';
import '../../review/state/review_providers.dart';

const _uuid = Uuid();

enum SubmissionStatus { idle, submitting, success, failure }

class SubmissionState {
  const SubmissionState({
    this.status = SubmissionStatus.idle,
    this.errorMessage,
  });
  final SubmissionStatus status;
  final String? errorMessage;
}

/// Generates and owns ONE idempotency key per submission attempt. The same
/// key is reused if [submit] is retried for the same logical attempt
/// (e.g. automatic retry-on-network-error inside ApiClient), preventing
/// duplicate observation rows server-side.
class ObservationSubmissionController extends StateNotifier<SubmissionState> {
  ObservationSubmissionController(this._repository)
    : super(const SubmissionState());

  final ObservationRepository _repository;
  String? _currentIdempotencyKey;

  String _keyForThisAttempt() {
    // A fresh key is minted only when starting a brand-new attempt; a retry
    // of the in-flight attempt (handled transparently inside ApiClient's
    // Dio layer) reuses _currentIdempotencyKey rather than regenerating it.
    _currentIdempotencyKey ??= _uuid.v4();
    return _currentIdempotencyKey!;
  }

  void resetForNewAttempt() {
    _currentIdempotencyKey = null;
    state = const SubmissionState();
  }

  Future<ObservationModel?> submit({
    required String type,
    String? taskId,
    required String itemId,
    required String branchId,
    String? supplierId,
    String? batchNo,
    DateTime? expDateObserved,
    num? physicalQty,
    String? remarks,
    String? photoPath,
  }) async {
    state = const SubmissionState(status: SubmissionStatus.submitting);
    try {
      final result = await _repository.submit(
        type: type,
        taskId: taskId,
        itemId: itemId,
        branchId: branchId,
        supplierId: supplierId,
        batchNo: batchNo,
        expDateObserved: expDateObserved,
        physicalQty: physicalQty,
        remarks: remarks,
        photoPath: photoPath,
        idempotencyKey: _keyForThisAttempt(),
      );
      state = const SubmissionState(status: SubmissionStatus.success);
      resetForNewAttempt();
      return result;
    } catch (e) {
      state = SubmissionState(
        status: SubmissionStatus.failure,
        errorMessage: e.toString(),
      );
      // _currentIdempotencyKey is intentionally kept so a user-triggered
      // "retry" button resubmits with the SAME key instead of creating a
      // duplicate observation.
      return null;
    }
  }
}

final observationSubmissionProvider =
    StateNotifierProvider.autoDispose<
      ObservationSubmissionController,
      SubmissionState
    >((ref) {
      return ObservationSubmissionController(
        ref.read(observationRepositoryProvider),
      );
    });
