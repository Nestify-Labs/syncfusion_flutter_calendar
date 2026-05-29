// [SF-8] Nestify patch unit tests — pure-logic coverage for the value
// classes introduced by SF-8. Widget-mount-level coverage of the callback
// dispatch path (build-phase wrapping / isCurrentView gating) lives in the
// host (Nestify mono-repo) integration tests, since constructing a full
// SfCalendar widget tree in fork-side unit tests has too many transitive
// dependencies for the value of what is being tested here.

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

SfCalendarTimelineCoordinates _coords({
  double viewportTopInBody = 60,
  double scrollOffset = 0,
  double intervalHeight = 60,
  double pinnedAllDayHeight = 0,
  List<DateTime>? visibleDates,
  double viewportWidth = 300,
  double viewportHeight = 600,
  double maxScrollExtent = 800,
}) {
  return SfCalendarTimelineCoordinates(
    viewportTopInBody: viewportTopInBody,
    scrollOffset: scrollOffset,
    intervalHeight: intervalHeight,
    pinnedAllDayHeight: pinnedAllDayHeight,
    visibleDates: visibleDates ?? <DateTime>[DateTime(2026, 5, 29)],
    viewportWidth: viewportWidth,
    viewportHeight: viewportHeight,
    maxScrollExtent: maxScrollExtent,
  );
}

void main() {
  group('SfCalendarTimelineCoordinates.yForTime', () {
    test('formula: top + hour*intervalH - scrollOffset', () {
      final c = _coords(
        viewportTopInBody: 100,
        scrollOffset: 50,
        intervalHeight: 60,
      );
      // 10:30 → 10.5 * 60 = 630 → 100 + 630 - 50 = 680
      expect(c.yForTime(DateTime(2026, 5, 29, 10, 30)), closeTo(680, 0.01));
    });

    test('midnight = top - scrollOffset', () {
      final c = _coords(viewportTopInBody: 56, scrollOffset: 100);
      expect(c.yForTime(DateTime(2026, 5, 29, 0, 0)), closeTo(-44, 0.01));
    });

    test('non-zero pinnedAllDayHeight reflected via viewportTopInBody only', () {
      // pinnedAllDayHeight itself is metadata; yForTime is driven by
      // viewportTopInBody (which the producer already incorporates the
      // pinnedAllDayHeight into for Week / 3-Day).
      final c = _coords(
        viewportTopInBody: 116, // 56 viewHeader + 60 pinnedAllDay
        pinnedAllDayHeight: 60,
        intervalHeight: 60,
        scrollOffset: 0,
      );
      expect(c.yForTime(DateTime(2026, 5, 29, 1, 0)), closeTo(176, 0.01));
    });
  });

  group('SfCalendarTimelineCoordinates.equalsWithTolerance', () {
    test('returns true within 0.5px tolerance on all numeric fields', () {
      final a = _coords(viewportTopInBody: 60.0, scrollOffset: 100.0);
      final b = _coords(viewportTopInBody: 60.3, scrollOffset: 100.2);
      expect(a.equalsWithTolerance(b), isTrue);
    });

    test('returns false when over tolerance', () {
      final a = _coords(viewportTopInBody: 60.0);
      final b = _coords(viewportTopInBody: 60.6);
      expect(a.equalsWithTolerance(b), isFalse);
    });

    test('returns false when visibleDates length differs', () {
      final a = _coords(visibleDates: <DateTime>[DateTime(2026, 5, 29)]);
      final b = _coords(
        visibleDates: <DateTime>[
          DateTime(2026, 5, 29),
          DateTime(2026, 5, 30),
        ],
      );
      expect(a.equalsWithTolerance(b), isFalse);
    });

    test('returns false when visibleDates content differs', () {
      final a = _coords(visibleDates: <DateTime>[DateTime(2026, 5, 29)]);
      final b = _coords(visibleDates: <DateTime>[DateTime(2026, 5, 30)]);
      expect(a.equalsWithTolerance(b), isFalse);
    });

    test('returns false when other is null', () {
      final a = _coords();
      expect(a.equalsWithTolerance(null), isFalse);
    });
  });

  group('SfCalendarEmptySlotQueryResult', () {
    test('constructs with all fields', () {
      final r = SfCalendarEmptySlotQueryResult(
        time: DateTime(2026, 5, 29, 14, 30),
        date: DateTime(2026, 5, 29),
        localPosition: const Offset(100, 200),
        isOnAppointment: false,
      );
      expect(r.time, DateTime(2026, 5, 29, 14, 30));
      expect(r.date, DateTime(2026, 5, 29));
      expect(r.localPosition, const Offset(100, 200));
      expect(r.isOnAppointment, isFalse);
    });
  });
}
