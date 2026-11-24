/// The All / Stock Count / Expiry Check segmented tabs on the History &
/// Audit screen (10_history_audit_3x.png).
enum HistoryTab { all, stockCount, expiryCheck }

extension HistoryTabX on HistoryTab {
  /// The `type` query param value, or null for the "All" tab (no filter).
  String? get apiValue => switch (this) {
    HistoryTab.all => null,
    HistoryTab.stockCount => 'stock_count',
    HistoryTab.expiryCheck => 'expiry_check',
  };

  String get label => switch (this) {
    HistoryTab.all => 'All',
    HistoryTab.stockCount => 'Stock Count',
    HistoryTab.expiryCheck => 'Expiry Check',
  };
}

/// Observation review statuses the status filter offers (server enum).
const historyStatuses = <String, String>{
  'pending': 'Pending',
  'approved': 'Approved',
  'recount_requested': 'Recount',
  'rejected': 'Rejected',
};

/// Immutable filter set for the History & Audit list. Every field maps 1:1
/// to a query param accepted by both `GET /v1/observations` (Manager/Owner)
/// and `GET /v1/observations/mine` (Staff).
class HistoryFilters {
  const HistoryFilters({
    this.branchId,
    this.dateFrom,
    this.dateTo,
    this.tab = HistoryTab.all,
    this.status,
  });

  final String? branchId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final HistoryTab tab;
  final String? status;

  bool get hasDateRange => dateFrom != null && dateTo != null;

  HistoryFilters copyWith({
    String? branchId,
    bool clearBranch = false,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDateRange = false,
    HistoryTab? tab,
    String? status,
    bool clearStatus = false,
  }) {
    return HistoryFilters(
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      dateFrom: clearDateRange ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateRange ? null : (dateTo ?? this.dateTo),
      tab: tab ?? this.tab,
      status: clearStatus ? null : (status ?? this.status),
    );
  }
}
