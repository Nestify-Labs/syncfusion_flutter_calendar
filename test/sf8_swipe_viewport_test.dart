// SF-8: every visible page must share the external ruler's timeline origin.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_layout/allday_appointment_layout.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/views/day_view.dart';

class _Events extends CalendarDataSource {
  _Events({int allDayRows = 2}) {
    appointments = <Appointment>[
      for (var day = 1; day <= 20; day++)
        Appointment(
          id: 'timed-$day',
          startTime: DateTime(2026, 10, day, 11),
          endTime: DateTime(2026, 10, day, 12),
          subject: '11 AM',
        ),
      for (var row = 0; row < allDayRows; row++)
        Appointment(
          id: 'all-day-$row',
          startTime: DateTime(2026, 10, 4),
          endTime: DateTime(2026, 10, 6, 23),
          isAllDay: true,
          subject: 'All day $row',
        ),
    ];
  }
}

Finder _visible(WidgetTester tester, Finder finder) {
  final calendar = tester.getRect(find.byType(SfCalendar));
  final elements =
      finder.evaluate().where((element) {
        final object = element.findRenderObject();
        if (object is! RenderBox || !object.hasSize) {
          return false;
        }
        final rect = object.localToGlobal(Offset.zero) & object.size;
        return rect.intersect(calendar).width > 1 &&
            rect.intersect(calendar).height > 1;
      }).toList();
  expect(elements, hasLength(1));
  return find.byElementPredicate(
    (element) => identical(element, elements.single),
  );
}

void main() {
  for (final configuration in [
    (name: 'Day', view: CalendarView.day, days: 1),
    (name: '3 Day', view: CalendarView.day, days: 3),
    (name: 'Week', view: CalendarView.week, days: -1),
  ]) {
    testWidgets(
      'SF-8 ${configuration.name} shares the rendered ruler through page and height transitions',
      (tester) async {
        tester.view.physicalSize = const Size(420, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final data = _Events(allDayRows: 6);
        final allDayEvents =
            data.appointments!
                .cast<Appointment>()
                .where((event) => event.isAllDay)
                .toList();
        SfCalendarTimelineCoordinates? coords;
        CalendarTapDetails? lastTap;
        const markerKey = ValueKey('external-11am-marker');
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, rebuild) {
                  return Stack(
                    children: [
                      SfCalendar(
                        view: configuration.view,
                        initialDisplayDate: DateTime(2026, 10, 4),
                        headerHeight: 0,
                        viewHeaderHeight: 56,
                        showCurrentTimeIndicator: false,
                        dataSource: data,
                        onTap: (details) => lastTap = details,
                        appointmentBuilder:
                            (context, details) => SizedBox.expand(
                              key:
                                  details.appointments.length == 1
                                      ? ValueKey(
                                        'appointment-${(details.appointments.single as Appointment).id}',
                                      )
                                      : null,
                            ),
                        onTimelineCoordinatesChanged: (value) {
                          if (value.equalsWithTolerance(coords, tol: 0)) {
                            return;
                          }
                          rebuild(() => coords = value);
                        },
                        timeSlotViewSettings: TimeSlotViewSettings(
                          numberOfDaysInView: configuration.days,
                          timeIntervalHeight: 60,
                          timeRulerSize: 48,
                        ),
                      ),
                      if (coords != null)
                        Positioned(
                          left: 0,
                          top: coords!.yForTime(DateTime(2026, 10, 4, 11)),
                          child: const SizedBox(
                            key: markerKey,
                            width: 1,
                            height: 1,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final errors = <String>[];
        var doublePageFrames = 0;
        var frames = 0;
        void inspect(String phase) {
          frames++;
          final calendarRect = tester.getRect(find.byType(SfCalendar));
          final rulerY = tester.getTopLeft(find.byKey(markerKey)).dy;
          var visible = 0;
          for (final element in find.byType(TimeSlotWidget).evaluate()) {
            final box = element.findRenderObject()! as RenderBox;
            final rect = box.localToGlobal(Offset.zero) & box.size;
            if (rect.intersect(calendarRect).width <= 48) {
              continue;
            }
            visible++;
            final delta = (rect.top + 11 * 60 - rulerY).abs();
            if (delta > 1) {
              errors.add('$phase/$frames: $delta');
            }
          }
          if (visible == 2) {
            doublePageFrames++;
          }
          for (final element
              in find.byType(AllDayAppointmentLayout).evaluate()) {
            final box = element.findRenderObject()! as RenderBox;
            var painted = (box.localToGlobal(Offset.zero) & box.size).intersect(
              calendarRect,
            );
            RenderObject child = box;
            while (child.parent != null) {
              final parent = child.parent!;
              final clip = parent.describeApproximatePaintClip(child);
              if (clip != null) {
                painted = painted.intersect(
                  MatrixUtils.transformRect(parent.getTransformTo(null), clip),
                );
              }
              child = parent;
            }
            if (painted.width <= 48 || painted.height <= 0) {
              continue;
            }
            final overlap = painted.bottom - (rulerY - 11 * 60);
            if (overlap > 1) {
              errors.add(
                '$phase/$frames: all-day overlaps timeline by $overlap',
              );
            }
          }
        }

        Future<void> frame(String phase) async {
          await tester.pump(const Duration(milliseconds: 16));
          inspect(phase);
        }

        Future<void> swipe(bool next, {bool cancel = false}) async {
          final direction = next ? -1.0 : 1.0;
          final gesture = await tester.startGesture(
            Offset(next ? 390 : 30, 500),
          );
          await gesture.moveBy(Offset(direction * 24, 0));
          await frame('start');
          for (var i = 0; i < (cancel ? 3 : 10); i++) {
            await gesture.moveBy(Offset(direction * 30, 0));
            await frame('drag');
          }
          if (cancel) {
            await tester.pump(const Duration(seconds: 1));
          }
          await gesture.up();
          for (var i = 0; i < 30; i++) {
            await frame('settle');
          }
          await tester.pumpAndSettle();
          inspect('settled');
        }

        await swipe(true);
        await swipe(false);
        await swipe(true, cancel: true);
        if (configuration.days != 1) {
          Offset? lastRowPoint;
          for (final phase in ['expand-all-day', 'collapse-all-day']) {
            final before =
                tester
                    .getTopLeft(_visible(tester, find.byType(TimeSlotWidget)))
                    .dy;
            await tester.tapAt(Offset(24, before - 10));
            for (var i = 0; i < 30; i++) {
              await frame(phase);
            }
            final after =
                tester
                    .getTopLeft(_visible(tester, find.byType(TimeSlotWidget)))
                    .dy;
            expect(
              after,
              phase == 'expand-all-day'
                  ? greaterThan(before)
                  : lessThan(before),
            );
            if (phase == 'expand-all-day') {
              lastRowPoint = tester.getCenter(
                _visible(
                  tester,
                  find.byKey(const ValueKey('appointment-all-day-5')),
                ),
              );
            }
            lastTap = null;
            await tester.tapAt(lastRowPoint!);
            await frame('all-day-hit');
            final tappedIds =
                lastTap?.appointments
                    ?.whereType<Appointment>()
                    .map((appointment) => appointment.id)
                    .toList() ??
                [];
            expect(
              tappedIds,
              phase == 'expand-all-day'
                  ? contains('all-day-5')
                  : isNot(contains('all-day-5')),
            );
          }
        }
        data.appointments =
            data.appointments!
                .cast<Appointment>()
                .where((event) => !event.isAllDay)
                .toList();
        data.notifyListeners(
          CalendarDataSourceAction.reset,
          data.appointments!,
        );
        for (var i = 0; i < 30; i++) {
          await frame('remove-all-day');
        }
        data.appointments = [...data.appointments!, ...allDayEvents];
        data.notifyListeners(
          CalendarDataSourceAction.reset,
          data.appointments!,
        );
        for (var i = 0; i < 30; i++) {
          await frame('add-all-day');
        }
        expect(doublePageFrames, greaterThan(10));
        expect(
          errors,
          isEmpty,
          reason: 'Actual rendered marker and grids must agree each frame',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('SF-8 aligns incoming 3-Day grid with the fixed ruler', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SfCalendarTimelineCoordinates? coords;
    final calendarKey = GlobalKey<SfCalendarTimelineQueryApi>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: SfCalendar(
            key: calendarKey,

            initialDisplayDate: DateTime(2026, 10, 4),
            headerHeight: 0,
            viewHeaderHeight: 56,
            showCurrentTimeIndicator: false,
            dataSource: _Events(),
            onTimelineCoordinatesChanged: (value) => coords = value,
            timeSlotViewSettings: const TimeSlotViewSettings(
              numberOfDaysInView: 3,
              timeIntervalHeight: 60,
              timeRulerSize: 48,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(coords!.pinnedAllDayHeight, greaterThan(0));
    final grid = find.byType(TimeSlotWidget).evaluate().firstWhere((element) {
      final box = element.findRenderObject()! as RenderBox;
      return box.localToGlobal(Offset.zero).dx.abs() < 1;
    });
    final gridTop =
        (grid.findRenderObject()! as RenderBox).localToGlobal(Offset.zero).dy;
    final visibleDate = coords!.visibleDates.first;
    expect(
      calendarKey.currentState!.queryTimeForGlobalY(gridTop + 11 * 60 + 1),
      DateTime(visibleDate.year, visibleDate.month, visibleDate.day, 11),
      reason:
          'Global pointer conversion must use the same rendered timeline origin',
    );
    expect(calendarKey.currentState!.queryTimeForGlobalY(gridTop - 1), isNull);
    expect(calendarKey.currentState!.queryTimeForGlobalY(850), isNull);

    // Stop midway through a real pointer gesture, while both pages are painted.
    final gesture = await tester.startGesture(const Offset(380, 500));
    await gesture.moveBy(const Offset(-24, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final calendarRect = tester.getRect(find.byType(SfCalendar));
    final visibleGrids =
        find.byType(TimeSlotWidget).evaluate().where((element) {
          final box = element.findRenderObject()! as RenderBox;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          return rect.intersect(calendarRect).width > 48;
        }).toList();
    expect(
      visibleGrids,
      hasLength(2),
      reason: 'Both paging surfaces must be visible',
    );
    final expectedTop =
        calendarRect.top + coords!.viewportTopInBody - coords!.scrollOffset;
    final errors = <double>[];
    for (final element in visibleGrids) {
      final box = element.findRenderObject()! as RenderBox;
      errors.add((box.localToGlobal(Offset.zero).dy - expectedTop).abs());
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      errors,
      everyElement(lessThanOrEqualTo(1)),
      reason: 'Every visible hour grid must align with the same fixed ruler',
    );
    expect(tester.takeException(), isNull);
  });
}
