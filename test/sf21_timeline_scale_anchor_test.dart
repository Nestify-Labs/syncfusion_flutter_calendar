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

  for (final publishPrepared in [false, true]) {
    testWidgets(
      'SF-21 prelayout coordinates stay paired (prepared: $publishPrepared)',
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
          nextIntervalHeight: publishPrepared ? 120 : null,
        );

        expect(applied, closeTo(targetOffset, 0.5));
        if (publishPrepared) {
          expect(coordinateHistory, hasLength(1));
          expect(coordinateHistory.single.intervalHeight, 120);
          expect(
            coordinateHistory.single.scrollOffset,
            closeTo(targetOffset, 0.5),
          );
          expect(
            coordinateHistory.single.maxScrollExtent,
            closeTo(120 * 24 - position.viewportDimension, 0.5),
          );
        } else {
          expect(coordinateHistory, isEmpty);
        }

        rebuild(() {
          preserveScaleOffset = true;
          intervalHeight = 120;
        });
        await tester.pump();
        if (publishPrepared) {
          expect(
            coordinateHistory.last.maxScrollExtent,
            closeTo(position.maxScrollExtent, 0.5),
            reason: 'The completed layout must replace the prepared extent',
          );
        }
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
        if (publishPrepared) {
          for (final nextHeight in [180.0, 90.0, 150.0]) {
            final previous = coordinateHistory.last;
            final target =
                (previous.scrollOffset + 200) *
                    nextHeight /
                    previous.intervalHeight -
                200;
            calendarKey.currentState!.setTimelineScrollOffset(
              target,
              allowOutOfRange: true,
              nextIntervalHeight: nextHeight,
            );
            rebuild(() => intervalHeight = nextHeight);
            await tester.pump();
            expect(position.pixels, closeTo(target, 0.5));
            expect(coordinateHistory.last.intervalHeight, nextHeight);
            expect(
              coordinateHistory.last.maxScrollExtent,
              closeTo(position.maxScrollExtent, 0.5),
            );
          }
        }
      },
    );
  }

  for (final days in [1, 3]) {
    testWidgets('SF-21 prepared scale targets arriving $days-day page', (
      tester,
    ) async {
      final key = GlobalKey<SfCalendarTimelineQueryApi>();
      final history = <SfCalendarTimelineCoordinates>[];
      List<DateTime> visibleDates = [];
      double intervalHeight = 60;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SfCalendar(
                  key: key,
                  view: CalendarView.day,
                  initialDisplayDate: DateTime(2026, 10, 4),
                  headerHeight: 0,
                  viewHeaderHeight: 56,
                  showCurrentTimeIndicator: false,
                  onViewChanged:
                      (details) => visibleDates = details.visibleDates,
                  onTimelineCoordinatesChanged: history.add,
                  preserveTimelineScaleOffset: intervalHeight != 60,
                  timeSlotViewSettings: TimeSlotViewSettings(
                    numberOfDaysInView: days,
                    timeIntervalHeight: intervalHeight,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = visibleDates.toList();
      final width = tester.getSize(find.byType(SfCalendar)).width;
      await tester.drag(find.byType(SfCalendar), Offset(-width * 0.8, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(visibleDates, isNot(equals(before)));
      history.clear();
      key.currentState!.setTimelineScrollOffset(
        300,
        allowOutOfRange: true,
        nextIntervalHeight: 120,
      );
      expect(history, hasLength(1));
      expect(
        history.single.visibleDates,
        visibleDates,
        reason: 'A finishing page animation must not publish the departed page',
      );
      rebuild(() => intervalHeight = 120);
      await tester.pumpAndSettle();
      expect(history.last.visibleDates, visibleDates);
      expect(history.last.intervalHeight, 120);
    });
  }
}
