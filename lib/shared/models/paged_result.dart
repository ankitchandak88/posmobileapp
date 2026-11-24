/// One page of a Laravel `->paginate()` response:
/// `{ "current_page", "data": [...], "last_page", "per_page", "total", ... }`.
///
/// Used by screens whose lists can grow without bound (History & Audit) so
/// they load page-by-page instead of the whole table (master prompt §11/§15:
/// "pagination for large lists", "avoid loading the entire inventory").
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  static int _int(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  /// Tolerates both the bare paginator shape and a plain `{data: [...]}` /
  /// bare-list response (treated as a single, final page).
  factory PagedResult.fromLaravel(
    dynamic body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final List raw;
    if (body is List) {
      raw = body;
    } else if (body is Map && body['data'] is List) {
      raw = body['data'] as List;
    } else {
      raw = const [];
    }
    final items = raw
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final meta = body is Map ? body : const {};
    final current = _int(meta['current_page'], 1);
    return PagedResult<T>(
      items: items,
      currentPage: current,
      lastPage: _int(meta['last_page'], current),
      total: _int(meta['total'], items.length),
    );
  }
}
