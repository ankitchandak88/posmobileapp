import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum StatusKind {
  pending,
  approved,
  rejected,
  recountRequested,
  info,
  inProgress,
  completed,
  cancelled,
}

/// Small pill badge for observation/task status (Pending, Approved, etc.)
/// matching the yellow "Pending" pill seen in the review queue reference.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
    this.showDot = true,
  });

  final StatusKind status;

  /// Short labels used on dense list rows (History & Audit reference shows a
  /// blue "Recount" pill rather than the long "Recount Requested").
  final bool compact;

  /// Whether to show a leading micro-status dot indicator
  final bool showDot;

  _StatusStyle get _style {
    switch (status) {
      case StatusKind.pending:
        return _StatusStyle('Pending', AppColors.pending, AppColors.pendingBg);
      case StatusKind.approved:
      case StatusKind.completed:
        return _StatusStyle(
          status == StatusKind.approved ? 'Approved' : 'Completed',
          AppColors.success,
          AppColors.successBg,
        );
      case StatusKind.rejected:
      case StatusKind.cancelled:
        return _StatusStyle(
          status == StatusKind.rejected ? 'Rejected' : 'Cancelled',
          AppColors.critical,
          AppColors.criticalBg,
        );
      case StatusKind.recountRequested:
        if (compact) {
          return _StatusStyle('Recount', AppColors.info, AppColors.infoBg);
        }
        return _StatusStyle(
          'Recount Requested',
          AppColors.warning,
          AppColors.warningBg,
        );
      case StatusKind.inProgress:
        return _StatusStyle('In Progress', AppColors.info, AppColors.infoBg);
      case StatusKind.info:
        return _StatusStyle('Info', AppColors.info, AppColors.infoBg);
    }
  }

  factory StatusBadge.fromString(
    String raw, {
    Key? key,
    bool compact = false,
    bool showDot = true,
  }) {
    final kind = switch (raw) {
      'pending' => StatusKind.pending,
      'approved' => StatusKind.approved,
      'rejected' => StatusKind.rejected,
      'recount_requested' => StatusKind.recountRequested,
      'in_progress' => StatusKind.inProgress,
      'completed' => StatusKind.completed,
      'cancelled' => StatusKind.cancelled,
      _ => StatusKind.pending,
    };
    return StatusBadge(
      key: key,
      status: kind,
      compact: compact,
      showDot: showDot,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: style.fg.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: style.fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            style.label,
            style: TextStyle(
              color: style.fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStyle {
  _StatusStyle(this.label, this.fg, this.bg);
  final String label;
  final Color fg;
  final Color bg;
}
