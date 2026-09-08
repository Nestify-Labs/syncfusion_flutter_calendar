// SF-8: a layout snapshot must not overwrite a newer post-frame scroll.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

void main() {
  for (final view in [
    CalendarView.day,
    CalendarView.week,
    CalendarView.workWeek,
  ]) {
    testWidgets('SF-8 keeps latest coordinates after post-frame scroll $view', (
      tester,
    ) async {
      double height = 60;
      SfCalendarTimelineCoordinates? coords;
      late StateSetter rebuild;
      final key = GlobalKey<SfCalendarTimelineQueryApi>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SfCalendar(
                  key: key,
                  view: view,
                  headerHeight: 0,
                  viewHeaderHeight: 56,
                  preserveTimelineScaleOffset: true,
                  onTimelineCoordinatesChanged: (value) => coords = value,
                  timeSlotViewSettings: TimeSlotViewSettings(
                    timeIntervalHeight: height,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.setTimelineScrollOffset(400, allowOutOfRange: false);
      await tester.pumpAndSettle();
      rebuild(() => height = 100);
      // Registered before layout's deferred dispatch; this emits newer truth
      // synchronously, before that older callback gets its turn.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        key.currentState!.setTimelineScrollOffset(150, allowOutOfRange: false);
      });
      await tester.pump();
      await tester.pump();
      expect(coords!.scrollOffset, closeTo(150, 0.5));
      expect(coords!.intervalHeight, 100);
      expect(tester.takeException(), isNull);
    });
  }
}
