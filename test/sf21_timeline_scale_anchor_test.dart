// [SF-21] A host-prepositioned timeline offset must survive the interval
// height rebuild instead of being overwritten by viewport-top retention.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

void main() {
  testWidgets('SF-21 preserves a host-prepositioned scale offset', (
    WidgetTester tester,
  ) async {
    double intervalHeight = 60;
    bool preserveScaleOffset = false;
    SfCalendarTimelineCoordinates? coordinates;
    final calendarKey = GlobalKey<SfCalendarTimelineQueryApi>();
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              rebuild = setState;
              return SfCalendar(
                key: calendarKey,
                headerHeight: 0,
                viewHeaderHeight: 56,
                preserveTimelineScaleOffset: preserveScaleOffset,
                onTimelineCoordinatesChanged: (value) {
                  coordinates = value;
                },
                timeSlotViewSettings: TimeSlotViewSettings(
                  timeIntervalHeight: intervalHeight,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final verticalPositions =
        find
            .descendant(
              of: find.byType(SfCalendar),
              matching: find.byType(Scrollable),
            )
            .hitTestable()
            .evaluate()
            .map((Element element) => (element as StatefulElement).state)
            .whereType<ScrollableState>()
            .map((ScrollableState state) => state.position)
            .where(
              (position) =>
                  position.axis == Axis.vertical &&
                  position.maxScrollExtent > 500,
            )
            .toList();
    expect(verticalPositions, hasLength(1));
    final position = verticalPositions.single;
    position.jumpTo(position.maxScrollExtent * 0.2);
    await tester.pump();
    await tester.pump();

    final before = coordinates!;
    final calendarTop = tester.getTopLeft(find.byType(SfCalendar)).dy;
    final focalY = tester.getCenter(find.byType(SfCalendar)).dy;
    final focalViewportY = focalY - calendarTop - before.viewportTopInBody;
    final anchorContentY = before.scrollOffset + focalViewportY;
    final targetOffset =
        anchorContentY * (120 / before.intervalHeight) - focalViewportY;
    expect(targetOffset, lessThan(position.maxScrollExtent));

    // This mirrors the host transaction: stop any drag and preposition first,
    // then publish the new row height with preservation enabled.
    expect(calendarKey.currentState, isNotNull);
    final applied = calendarKey.currentState!.setTimelineScrollOffset(
      targetOffset,
      allowOutOfRange: true,
    );
    expect(applied, closeTo(targetOffset, 0.5));
    rebuild(() {
      preserveScaleOffset = true;
      intervalHeight = 120;
    });
    await tester.pump();

    expect(position.pixels, closeTo(targetOffset, 0.5));
  });

  testWidgets('SF-21 can preposition beyond the old scroll extent', (
    WidgetTester tester,
  ) async {
    double intervalHeight = 60;
    bool preserveScaleOffset = false;
    final calendarKey = GlobalKey<SfCalendarTimelineQueryApi>();
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              rebuild = setState;
              return SfCalendar(
                key: calendarKey,
                headerHeight: 0,
                viewHeaderHeight: 56,
                preserveTimelineScaleOffset: preserveScaleOffset,
                timeSlotViewSettings: TimeSlotViewSettings(
                  timeIntervalHeight: intervalHeight,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final position = find
        .descendant(
          of: find.byType(SfCalendar),
          matching: find.byType(Scrollable),
        )
        .hitTestable()
        .evaluate()
        .map((element) => (element as StatefulElement).state)
        .whereType<ScrollableState>()
        .map((state) => state.position)
        .singleWhere(
          (position) =>
              position.axis == Axis.vertical && position.maxScrollExtent > 500,
        );
    final oldMaxScrollExtent = position.maxScrollExtent;
    final targetOffset = oldMaxScrollExtent + 300;

    expect(calendarKey.currentState, isNotNull);
    final applied = calendarKey.currentState!.setTimelineScrollOffset(
      targetOffset,
      allowOutOfRange: true,
    );
    expect(applied, closeTo(targetOffset, 0.5));

    rebuild(() {
      preserveScaleOffset = true;
      intervalHeight = 120;
    });
    await tester.pump();

    expect(position.maxScrollExtent, greaterThan(oldMaxScrollExtent));
    expect(position.pixels, closeTo(targetOffset, 0.5));
  });

  testWidgets(
    'SF-21 prelayout offset does not publish stale-height coordinates',
    (WidgetTester tester) async {
      double intervalHeight = 60;
      bool preserveScaleOffset = false;
      final coordinateHistory = <SfCalendarTimelineCoordinates>[];
      final calendarKey = GlobalKey<SfCalendarTimelineQueryApi>();
      late StateSetter rebuild;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                rebuild = setState;
                return SfCalendar(
                  key: calendarKey,
                  headerHeight: 0,
                  viewHeaderHeight: 56,
                  preserveTimelineScaleOffset: preserveScaleOffset,
                  onTimelineCoordinatesChanged: coordinateHistory.add,
                  timeSlotViewSettings: TimeSlotViewSettings(
                    timeIntervalHeight: intervalHeight,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final position = find
          .descendant(
            of: find.byType(SfCalendar),
            matching: find.byType(Scrollable),
          )
          .hitTestable()
          .evaluate()
          .map((element) => (element as StatefulElement).state)
          .whereType<ScrollableState>()
          .map((state) => state.position)
          .singleWhere(
            (position) =>
                position.axis == Axis.vertical &&
                position.maxScrollExtent > 500,
          );
      position.jumpTo(position.maxScrollExtent * 0.2);
      await tester.pump();
      await tester.pump();
      coordinateHistory.clear();

      final normalTarget = position.pixels + 20;
      calendarKey.currentState!.setTimelineScrollOffset(normalTarget);
      expect(coordinateHistory, isNotEmpty);
      expect(coordinateHistory.last.scrollOffset, closeTo(normalTarget, 0.5));
      coordinateHistory.clear();

      final targetOffset = position.pixels + 80;
      final applied = calendarKey.currentState!.setTimelineScrollOffset(
        targetOffset,
        allowOutOfRange: true,
      );

      expect(applied, closeTo(targetOffset, 0.5));
      expect(coordinateHistory, isEmpty);

      rebuild(() {
        preserveScaleOffset = true;
        intervalHeight = 120;
      });
      await tester.pump();
      await tester.pump();

      expect(coordinateHistory, isNotEmpty);
      expect(
        coordinateHistory.map((value) => value.intervalHeight),
        everyElement(120),
        reason:
            'The rebuild must not publish the prepositioned offset before '
            'adopting the new interval height.',
      );
      expect(coordinateHistory.last.intervalHeight, 120);
      expect(coordinateHistory.last.scrollOffset, closeTo(targetOffset, 0.5));
    },
  );
}
