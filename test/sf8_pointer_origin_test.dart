// SF-8: pointer conversions and date clamping follow the rendered viewport.
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/views/day_view.dart';

class _Events extends CalendarDataSource {
  _Events() {
    appointments = <Appointment>[
      Appointment(
        id: 'timed',
        startTime: DateTime(2026, 10, 4, 11),
        endTime: DateTime(2026, 10, 4, 12),
      ),
      for (var row = 0; row < 6; row++)
        Appointment(
          id: 'all-day-$row',
          startTime: DateTime(2026, 10, 4),
          endTime: DateTime(2026, 10, 4, 23),
          isAllDay: true,
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
  expect(
    elements,
    hasLength(1),
    reason: finder
        .evaluate()
        .map((e) {
          final b = e.findRenderObject()! as RenderBox;
          return '${e.widget.key}: ${b.localToGlobal(Offset.zero) & b.size}';
        })
        .join('; '),
  );
  return find.byElementPredicate(
    (element) => identical(element, elements.single),
  );
}

void main() {
  for (final changingHeight in [false, true]) {
    testWidgets(
      'SF-8 desktop resize uses rendered origin, transition=$changingHeight',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final data = _Events();
        final starts = <AppointmentResizeStartDetails>[];
        final updates = <AppointmentResizeUpdateDetails>[];
        final ends = <AppointmentResizeEndDetails>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.windows),
            home: Scaffold(
              body: SfCalendar(
                initialDisplayDate: DateTime(2026, 10, 4),
                initialSelectedDate: DateTime(2026, 10, 4),
                headerHeight: 0,
                viewHeaderHeight: 56,
                showCurrentTimeIndicator: false,
                dataSource: data,
                onTimelineCoordinatesChanged: (_) {},
                allowAppointmentResize: true,
                onAppointmentResizeStart: starts.add,
                onAppointmentResizeUpdate: updates.add,
                onAppointmentResizeEnd: ends.add,
                appointmentBuilder:
                    (context, details) => ColoredBox(
                      key:
                          details.appointments.length == 1
                              ? ValueKey<String>(
                                (details.appointments.single as Appointment).id!
                                    as String,
                              )
                              : null,
                      color: Colors.blue,
                    ),
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
        if (changingHeight) {
          data.appointments =
              data.appointments!
                  .cast<Appointment>()
                  .where((event) => !event.isAllDay)
                  .toList();
          data.notifyListeners(
            CalendarDataSourceAction.reset,
            data.appointments!,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));
        }
        final eventRect = tester.getRect(
          _visible(tester, find.byKey(const ValueKey('timed'))),
        );
        final gridTop =
            tester.getTopLeft(_visible(tester, find.byType(TimeSlotWidget))).dy;
        final pointer = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          pointer: 20,
        );
        final start = Offset(eventRect.center.dx, eventRect.bottom - 2);
        await pointer.addPointer(location: start);
        await pointer.moveTo(start);
        await tester.pump();
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.resizeUpDown,
        );
        await pointer.down(start);
        await pointer.moveTo(start + const Offset(0, 4));
        await pointer.moveTo(Offset(start.dx, gridTop + 12 * 60 + 30));
        await pointer.up();
        await tester.pumpAndSettle();
        expect(starts, hasLength(1));
        expect((starts.single.appointment as Appointment).id, 'timed');
        expect(updates, isNotEmpty);
        expect(ends, hasLength(1));
        expect(ends.single.startTime, DateTime(2026, 10, 4, 11));
        expect(ends.single.endTime, DateTime(2026, 10, 4, 12, 30));
        await pointer.removePointer();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('SF-8 interval rebuild retains the expanded viewport end', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final query = GlobalKey<SfCalendarTimelineQueryApi>();
    late StateSetter rebuild;
    double interval = 60;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return SfCalendar(
                key: query,

                initialDisplayDate: DateTime(2026, 10, 4),
                initialSelectedDate: DateTime(2026, 10, 4),
                headerHeight: 0,
                viewHeaderHeight: 56,
                dataSource: _Events(),
                onTimelineCoordinatesChanged: (_) {},
                timeSlotViewSettings: TimeSlotViewSettings(
                  numberOfDaysInView: 3,
                  timeIntervalHeight: interval,
                  timeRulerSize: 48,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final collapsedTop =
        tester.getTopLeft(_visible(tester, find.byType(TimeSlotWidget))).dy;
    await tester.tapAt(Offset(24, collapsedTop - 10));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(_visible(tester, find.byType(TimeSlotWidget))).dy,
      greaterThan(collapsedTop),
    );
    query.currentState!.setTimelineScrollOffset(10000);
    await tester.pumpAndSettle();
    rebuild(() => interval = 59);
    await tester.pumpAndSettle();
    final positions = find
        .byType(Scrollable)
        .hitTestable()
        .evaluate()
        .map((element) => (element as StatefulElement).state)
        .whereType<ScrollableState>()
        .map((state) => state.position)
        .where(
          (position) =>
              position.axis == Axis.vertical && position.maxScrollExtent > 500,
        );
    expect(positions, hasLength(1));
    expect(
      positions.single.pixels,
      closeTo(positions.single.maxScrollExtent, 1),
    );
    expect(tester.takeException(), isNull);
  });
}
