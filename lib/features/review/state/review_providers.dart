import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../auth/state/auth_providers.dart';
import '../data/observation_repository.dart';

final observationRepositoryProvider = Provider<ObservationRepository>((ref) {
  return ObservationRepository(apiClient: ref.read(apiClientProvider));
});

/// Calls the live `GET /v1/observations/mine` endpoint. A failure propagates
/// as an [AsyncError] so the UI renders its existing [ErrorState] widget —
/// it must NOT silently fall back to mock data.
final myObservationsProvider =
    FutureProvider.autoDispose<List<ObservationModel>>((ref) async {
      return ref.read(observationRepositoryProvider).mine();
    });

/// Calls the live `GET /v1/observations/pending` endpoint (Manager/Owner
/// only). A failure propagates as an [AsyncError] rather than falling back
/// to mock data.
final pendingReviewProvider =
    FutureProvider.autoDispose<List<ObservationModel>>((ref) async {
      return ref.read(observationRepositoryProvider).pending();
    });
