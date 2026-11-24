import '../../core/utils/parse_helpers.dart';

/// `GET /v1/dashboard/summary` response (`data` object). The shape differs
/// by caller role — see URBANPETS_API_DOCUMENTATION.md "Dashboard" section:
///
/// - Staff: `tasks` + `observations` counts only. NEVER any system-quantity
///   or variance field (blind counting applies to dashboards too).
/// - Manager/Owner: additionally `pendingReviewCount`, `reviewedToday`,
///   `reviewedThisWeek`, `expiryBuckets`, `pendingBarcodeMappingRequests`.
///
/// UI code must branch on [isManagerOrOwner] (or null-check the
/// manager-only fields directly) rather than assuming they exist — a Staff
/// session's JSON genuinely omits them, this isn't just empty/zero data.
class DashboardModel {
  DashboardModel({
    required this.role,
    this.branchId,
    this.branchIds,
    required this.taskCounts,
    this.observationCounts,
    this.pendingReviewCount,
    this.reviewedToday,
    this.reviewedThisWeek,
    this.pendingBarcodeMappingRequests,
    this.expiryBuckets,
  });

  final String role;
  final String? branchId;
  final List<String>? branchIds;
  final DashboardTaskCounts taskCounts;

  /// Staff-only: the submitter's own observation counts over the last
  /// `period_days`. Null for Manager/Owner payloads.
  final DashboardObservationCounts? observationCounts;

  /// Manager/Owner-only fields below. Each is null when absent from the
  /// response rather than defaulted to 0, so the UI can tell "not present
  /// for this role" apart from "present and zero".
  final int? pendingReviewCount;
  final DashboardReviewTally? reviewedToday;
  final DashboardReviewTally? reviewedThisWeek;
  final int? pendingBarcodeMappingRequests;
  final List<DashboardExpiryBucket>? expiryBuckets;

  bool get isManagerOrOwner => role == 'manager' || role == 'owner';

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      role: json['role'] as String? ?? 'staff',
      branchId: json['branch_id']?.toString(),
      branchIds: (json['branch_ids'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      taskCounts: DashboardTaskCounts.fromJson(
        json['tasks'] as Map<String, dynamic>? ?? const {},
      ),
      observationCounts: json['observations'] != null
          ? DashboardObservationCounts.fromJson(
              json['observations'] as Map<String, dynamic>,
            )
          : null,
      pendingReviewCount: parseInt(json['pending_review_count']),
      reviewedToday: json['reviewed_today'] != null
          ? DashboardReviewTally.fromJson(
              json['reviewed_today'] as Map<String, dynamic>,
            )
          : null,
      reviewedThisWeek: json['reviewed_this_week'] != null
          ? DashboardReviewTally.fromJson(
              json['reviewed_this_week'] as Map<String, dynamic>,
            )
          : null,
      pendingBarcodeMappingRequests:
          parseInt(json['pending_barcode_mapping_requests']),
      expiryBuckets: json['expiry_buckets'] != null
          ? (json['expiry_buckets'] as List)
                .map(
                  (e) =>
                      DashboardExpiryBucket.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : null,
    );
  }
}

class DashboardTaskCounts {
  DashboardTaskCounts({
    required this.pending,
    required this.inProgress,
    required this.completed,
    this.cancelled,
  });

  final int pending;
  final int inProgress;
  final int completed;

  /// Only present on the Manager/Owner payload.
  final int? cancelled;

  factory DashboardTaskCounts.fromJson(Map<String, dynamic> json) {
    return DashboardTaskCounts(
      pending: parseInt(json['pending']) ?? 0,
      inProgress: parseInt(json['in_progress']) ?? 0,
      completed: parseInt(json['completed']) ?? 0,
      cancelled: parseInt(json['cancelled']),
    );
  }
}

/// Staff-only: the submitter's own observation counts over `periodDays`.
class DashboardObservationCounts {
  DashboardObservationCounts({
    required this.periodDays,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.recountRequested,
  });

  final int periodDays;
  final int pending;
  final int approved;
  final int rejected;
  final int recountRequested;

  factory DashboardObservationCounts.fromJson(Map<String, dynamic> json) {
    return DashboardObservationCounts(
      periodDays: parseInt(json['period_days']) ?? 30,
      pending: parseInt(json['pending']) ?? 0,
      approved: parseInt(json['approved']) ?? 0,
      rejected: parseInt(json['rejected']) ?? 0,
      recountRequested: parseInt(json['recount_requested']) ?? 0,
    );
  }
}

/// `{ "approved": n, "rejected": n }` — used for both `reviewed_today` and
/// `reviewed_this_week`.
class DashboardReviewTally {
  DashboardReviewTally({required this.approved, required this.rejected});

  final int approved;
  final int rejected;

  factory DashboardReviewTally.fromJson(Map<String, dynamic> json) {
    return DashboardReviewTally(
      approved: parseInt(json['approved']) ?? 0,
      rejected: parseInt(json['rejected']) ?? 0,
    );
  }
}

class DashboardExpiryBucketItem {
  DashboardExpiryBucketItem({
    required this.itemId,
    this.itemName,
    required this.branchId,
    this.batchNo,
    this.expDate,
    required this.daysUntilExpiry,
    required this.isExpired,
    this.remainingQty,
  });

  final String itemId;
  final String? itemName;
  final String branchId;
  final String? batchNo;
  final String? expDate;
  final int daysUntilExpiry;
  final bool isExpired;
  final num? remainingQty;

  factory DashboardExpiryBucketItem.fromJson(Map<String, dynamic> json) {
    return DashboardExpiryBucketItem(
      itemId: json['item_id'].toString(),
      itemName: json['item_name'] as String?,
      branchId: json['branch_id'].toString(),
      batchNo: json['batch_no'] as String?,
      expDate: json['exp_date'] as String?,
      daysUntilExpiry: parseInt(json['days_until_expiry']) ?? 0,
      isExpired: json['is_expired'] as bool? ?? false,
      remainingQty: parseNum(json['remaining_qty']),
    );
  }
}

class DashboardExpiryBucket {
  DashboardExpiryBucket({
    required this.label,
    required this.minDays,
    required this.maxDays,
    required this.severity,
    required this.sortOrder,
    required this.count,
    required this.hasMore,
    required this.items,
  });

  final String label;
  final int minDays;
  final int maxDays;
  final String severity; // info | warning | critical
  final int sortOrder;
  final int count;
  final bool hasMore;
  final List<DashboardExpiryBucketItem> items;

  factory DashboardExpiryBucket.fromJson(Map<String, dynamic> json) {
    return DashboardExpiryBucket(
      label: json['label'] as String? ?? '',
      minDays: parseInt(json['min_days']) ?? 0,
      maxDays: parseInt(json['max_days']) ?? 0,
      severity: json['severity'] as String? ?? 'info',
      sortOrder: parseInt(json['sort_order']) ?? 0,
      count: parseInt(json['count']) ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
      items: (json['items'] as List? ?? [])
          .map(
            (e) =>
                DashboardExpiryBucketItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
