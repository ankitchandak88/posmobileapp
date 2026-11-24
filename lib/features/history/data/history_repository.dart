import '../../../shared/models/models.dart';
import '../../review/data/observation_repository.dart';
import 'history_filters.dart';

/// Data-layer entry point for the History & Audit screen. Delegates to
/// [ObservationRepository] (same resource, no duplicated HTTP/parsing code)
/// and picks the endpoint by role:
///
/// - reviewer (Manager/Owner) → `GET /v1/observations`: every submitter in
///   the caller's permitted branch(es), with system qty / variance.
/// - everyone else (Staff) → `GET /v1/observations/mine`: own rows only,
///   blind shape. The server enforces this (the cross-staff endpoint returns
///   403 for Staff, and /mine is hard-scoped to `submitted_by = me`), so this
///   choice is a UX convenience, not the security boundary.
class HistoryRepository {
  HistoryRepository({required ObservationRepository observationRepository})
    : _observationRepository = observationRepository;

  final ObservationRepository _observationRepository;

  Future<PagedResult<ObservationModel>> search({
    required bool asReviewer,
    required HistoryFilters filters,
    int page = 1,
    int perPage = 20,
  }) {
    final type = filters.tab.apiValue;
    return asReviewer
        ? _observationRepository.history(
            branchId: filters.branchId,
            dateFrom: filters.dateFrom,
            dateTo: filters.dateTo,
            type: type,
            status: filters.status,
            page: page,
            perPage: perPage,
          )
        : _observationRepository.myHistory(
            branchId: filters.branchId,
            dateFrom: filters.dateFrom,
            dateTo: filters.dateTo,
            type: type,
            status: filters.status,
            page: page,
            perPage: perPage,
          );
  }
}
