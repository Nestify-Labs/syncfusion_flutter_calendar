// SF-22: immutable geometry shared by native paint, host rows and hit queries.
import 'package:flutter/foundation.dart';

/// Motion phase of an opt-in continuous day window.
enum DayWindowPhase { idle, dragging, ballistic, settling }

/// One atomic horizontal coordinate frame for a continuous 3/7-day view.
@immutable
class DayWindowSnapshot {
  DayWindowSnapshot({
    required List<DateTime> renderedDates,
    required this.visibleDayCount,
    required this.columnWidth,
    required this.contentLeft,
    required this.horizontalOffset,
    required this.settledFirstDate,
    required this.phase,
    required this.generation,
    required this.sequence,
    required this.isRTL,
  }) : renderedDates = List<DateTime>.unmodifiable(renderedDates);

  /// Chronological bounded buffer; may include dates clipped outside the body.
  final List<DateTime> renderedDates;
  final int visibleDayCount;
  final double columnWidth;

  /// Left edge of the date viewport, excluding the fixed time ruler.
  final double contentLeft;

  /// First rendered date's left edge relative to [contentLeft].
  final double horizontalOffset;

  /// Last committed business window; remains stable during dragging.
  final DateTime settledFirstDate;
  final DayWindowPhase phase;
  final int generation;
  final int sequence;
  final bool isRTL;

  /// Date-column left edge in calendar-body coordinates (including clipping).
  double xForDate(DateTime date) {
    final DateTime first = renderedDates.first;
    final int days =
        DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
    return contentLeft +
        horizontalOffset +
        days * columnWidth * (isRTL ? -1 : 1);
  }

  bool equalsWithTolerance(DayWindowSnapshot? other, {double tol = .5}) =>
      other != null &&
      visibleDayCount == other.visibleDayCount &&
      (columnWidth - other.columnWidth).abs() <= tol &&
      (contentLeft - other.contentLeft).abs() <= tol &&
      (horizontalOffset - other.horizontalOffset).abs() <= tol &&
      settledFirstDate == other.settledFirstDate &&
      phase == other.phase &&
      generation == other.generation &&
      sequence == other.sequence &&
      isRTL == other.isRTL &&
      listEquals(renderedDates, other.renderedDates);
}
