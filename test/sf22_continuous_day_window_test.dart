// SF-22: product-level day-window gestures, independent of private page state.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_layout/allday_appointment_layout.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/common/calendar_view_helper.dart';

void main() {
  for (final days in [3, 7]) {
    testWidgets(
      '$days-day slow drag snaps one day, preserving vertical offset',
      (tester) async {
        tester.view.physicalSize = const Size(420, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = CalendarController();
        final windows = <List<DateTime>>[];
        SfCalendarTimelineCoordinates? coords;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: Scaffold(
              body: SfCalendar(
                view: days == 3 ? CalendarView.day : CalendarView.week,
                firstDayOfWeek: 1,
                dayWindowNavigation: DayWindowNavigation.continuous,
                controller: controller,
                initialDisplayDate: DateTime(2026, 10, 19, 9),
                headerHeight: 0,
                viewHeaderHeight: 50,
                showCurrentTimeIndicator: false,
                onViewChanged: (value) => windows.add(value.visibleDates),
                onTimelineCoordinatesChanged: (value) => coords = value,
                timeSlotViewSettings: TimeSlotViewSettings(
                  numberOfDaysInView: days == 3 ? 3 : -1,
                  timeRulerSize: 42,
                  timeIntervalHeight: 60,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = coords!.scrollOffset;
        final count = windows.length;
        final drag = await tester.startGesture(const Offset(300, 400));
        // Cross the gesture slop first, then move a measured 0.8 column slowly.
        await drag.moveBy(const Offset(-20, 0));
        await tester.pump(const Duration(milliseconds: 100));
        await drag.moveBy(Offset(-378 / days * .8, 0));
        await tester.pump(const Duration(milliseconds: 500));
        expect(windows.length, count, reason: 'No business commit while held');
        await drag.up();
        await tester.pumpAndSettle();
        expect(windows.last.first, DateTime(2026, 10, 20));
        expect(windows.last.length, days);
        expect(coords!.scrollOffset, closeTo(before, .5));
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final days in [3, 7]) {
    testWidgets('$days-day held drag crosses old pages with accurate hit dates', (
      tester,
    ) async {
      final harness = await _mount(tester, days);
      final before = harness.coords!.scrollOffset;
      final initialCommits = harness.windows.length;
      final drag = await tester.startGesture(const Offset(330, 350));
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump();
      // Incremental real pointer travel; rebasing must work in either direction.
      for (var step = 0; step < days * 3 + 1; step++) {
        await drag.moveBy(Offset(-harness.column * .4, 0));
        await tester.pump(const Duration(milliseconds: 40));
        _checkVisibleEvents(tester, harness);
      }
      expect(harness.windows.length, initialCommits);
      expect(harness.coords!.scrollOffset, closeTo(before, .5));
      await tester.pump(const Duration(milliseconds: 500));
      await drag.up();
      await tester.pumpAndSettle();
      final advanced = ((days * 3 + 1) * .4).round();
      expect(harness.windows.last.first, DateTime(2026, 10, 19 + advanced));
      expect(harness.windows.length, initialCommits + 1);
      _checkVisibleEvents(tester, harness);
      expect(tester.takeException(), isNull);
    });
  }

  for (final days in [3, 7]) {
    testWidgets(
      '$days-day cancel settles and arrows retain full-window steps',
      (tester) async {
        final h = await _mount(tester, days);
        final drag = await tester.startGesture(const Offset(300, 400));
        await drag.moveBy(const Offset(-20, 0));
        await tester.pump();
        await drag.moveBy(Offset(-h.column * .8, 0));
        await tester.pump();
        await drag.cancel();
        await tester.pumpAndSettle();
        expect(h.windows.last.first, DateTime(2026, 10, 20));
        h.controller.forward!();
        await tester.pumpAndSettle();
        expect(h.windows.last.first, DateTime(2026, 10, 20 + days));
        h.controller.backward!();
        await tester.pumpAndSettle();
        expect(h.windows.last.first, DateTime(2026, 10, 20));
        _checkVisibleEvents(tester, h);
      },
    );
    testWidgets(
      '$days-day explicit navigation with weekday reconfiguration wins',
      (tester) async {
        final h = await _mount(tester, days);
        final target = DateTime(2026, 10, 22);
        h.rebuild(() => h.firstDayOfWeek = target.weekday);
        h.controller.displayDate = target;
        await tester.pumpAndSettle();
        expect(h.coords!.dayWindow!.settledFirstDate, target);
        expect(h.windows.last.first, target);
        _checkVisibleEvents(tester, h);
      },
    );
    testWidgets(
      '$days-day replacement sharing a controller retires the old listener',
      (tester) async {
        final h = await _mount(tester, days);
        h.rebuild(() {
          h.key = GlobalKey<SfCalendarTimelineQueryApi>();
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(h.coords!.dayWindow!.settledFirstDate, DateTime(2026, 10, 19));
        h.controller.displayDate = DateTime(2026, 11, 9);
        await tester.pumpAndSettle();
        expect(h.coords!.dayWindow!.settledFirstDate, DateTime(2026, 11, 9));
      },
    );
    testWidgets('$days-day explicit navigation invalidates active fling', (
      tester,
    ) async {
      final h = await _mount(tester, days);
      await tester.flingFrom(
        const Offset(350, 400),
        const Offset(-200, 0),
        1800,
      );
      await tester.pump(const Duration(milliseconds: 80));
      h.controller.displayDate = DateTime(2026, 11, 9, 9);
      await tester.pumpAndSettle();
      expect(h.windows.last.first, DateTime(2026, 11, 9));
      final count = h.windows.length;
      await tester.pump(const Duration(seconds: 2));
      expect(h.windows.length, count);
      _checkVisibleEvents(tester, h);
    });
    testWidgets(
      '$days-day reverse takeover preserves fractional paint position',
      (tester) async {
        final h = await _mount(tester, days);
        await tester.flingFrom(
          const Offset(350, 400),
          const Offset(-150, 0),
          1500,
        );
        await tester.pump(const Duration(milliseconds: 50));
        final before = h.key.currentState!.queryDateForGlobalX(100);
        final drag = await tester.startGesture(const Offset(150, 400));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          h.key.currentState!.queryDateForGlobalX(100),
          before,
          reason: 'Touch-down must stop inertia before drag recognition',
        );
        await drag.moveBy(const Offset(20, 0));
        await tester.pump();
        await drag.moveBy(Offset(h.column * 1.2, 0));
        await tester.pump(const Duration(milliseconds: 500));
        _checkVisibleEvents(tester, h);
        await drag.up();
        await tester.pumpAndSettle();
        _checkVisibleEvents(tester, h);
      },
    );
  }

  for (final days in [3, 7]) {
    testWidgets('$days-day RTL follows dates and ruler coordinates', (
      tester,
    ) async {
      final h = await _mount(tester, days, rtl: true);
      final drag = await tester.startGesture(const Offset(150, 400));
      await drag.moveBy(const Offset(20, 0));
      await tester.pump();
      await drag.moveBy(Offset(h.column * .8, 0));
      await tester.pump(const Duration(milliseconds: 500));
      _checkVisibleEvents(tester, h);
      await drag.up();
      await tester.pumpAndSettle();
      expect(h.windows.last.first, DateTime(2026, 10, 20));
      _checkVisibleEvents(tester, h);
    });
    testWidgets('$days-day min/max bound whole windows without oscillation', (
      tester,
    ) async {
      final h = await _mount(tester, days, bounded: true);
      await tester.flingFrom(
        const Offset(100, 400),
        const Offset(250, 0),
        2400,
      );
      await tester.pumpAndSettle();
      expect(h.windows.last.first, DateTime(2026, 10, 19));
      await tester.flingFrom(
        const Offset(350, 400),
        const Offset(-250, 0),
        2400,
      );
      await tester.pumpAndSettle();
      expect(h.windows.last.last, h.maxDate);
      _checkVisibleEvents(tester, h);
    });
    testWidgets(
      '$days-day data/style refresh retains held position and none locks it',
      (tester) async {
        final h = await _mount(tester, days, allDay: true);
        final drag = await tester.startGesture(const Offset(300, 500));
        await drag.moveBy(const Offset(-20, 0));
        await tester.pump();
        await drag.moveBy(Offset(-h.column * 1.4, 0));
        await tester.pump();
        final before = h.coords!.dayWindow!.xForDate(DateTime(2026, 10, 21));
        h.rebuild(() => h.background = Colors.grey);
        h.data.notifyListeners(
          CalendarDataSourceAction.reset,
          h.data.appointments!,
        );
        await tester.pumpAndSettle();
        expect(
          h.coords!.dayWindow!.xForDate(DateTime(2026, 10, 21)),
          closeTo(before, .1),
        );
        _checkVisibleEvents(tester, h);
        h.rebuild(() => h.navigation = ViewNavigationMode.none);
        await tester.pumpAndSettle();
        final locked = h.windows.last.first;
        await drag.moveBy(Offset(-h.column * 2, 0));
        await drag.up();
        await tester.pumpAndSettle();
        expect(h.windows.last.first, locked);
        expect(h.coords!.dayWindow!.phase, DayWindowPhase.idle);
        h.rebuild(() => h.navigation = ViewNavigationMode.snap);
        await tester.pumpAndSettle();
        await tester.timedDragFrom(
          const Offset(300, 500),
          Offset(-h.column * 1.1 - 20, 0),
          const Duration(seconds: 2),
        );
        await tester.pumpAndSettle();
        expect(h.windows.last.first.isAfter(locked), isTrue);
      },
    );
  }

  testWidgets('continuous events remain painted with composited layers', (
    tester,
  ) async {
    final h = await _mount(tester, 3);
    final point = tester.getCenter(find.byKey(const ValueKey('event-20')));
    final rgba = await tester.runAsync(() async {
      final boundary =
          h.rasterKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData();
      image.dispose();
      final at = (point.dy.floor() * 420 + point.dx.floor()) * 4;
      return [for (var i = 0; i < 4; i++) bytes!.getUint8(at + i)];
    });
    expect(
      rgba,
      [33, 150, 243, 255],
      reason:
          'Actual blue event pixels, not only correct RenderBox coordinates',
    );
  });

  testWidgets('next partial day already paints its all-day event', (
    tester,
  ) async {
    final h = await _mount(tester, 3);
    h.data.appointments!.add(
      Appointment(
        id: 'next-all',
        isAllDay: true,
        startTime: DateTime(2026, 10, 22),
        endTime: DateTime(2026, 10, 22, 23),
        subject: 'Next all day',
      ),
    );
    h.data.notifyListeners(
      CalendarDataSourceAction.reset,
      h.data.appointments!,
    );
    await tester.pumpAndSettle();
    final drag = await tester.startGesture(const Offset(300, 400));
    await drag.moveBy(const Offset(-20, 0));
    await tester.pump();
    await drag.moveBy(Offset(-h.column * .8, 0));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('next-all'));
    final debugPanels = tester
        .widgetList<AllDayAppointmentLayout>(
          find.byType(AllDayAppointmentLayout),
        )
        .map((w) {
          final d = UpdateCalendarStateDetails();
          w.updateCalendarState(d);
          return '${w.visibleDates.first}: h=${w.height}, visible=${w.visibleAppointments?.length}, owner=${d.currentViewVisibleDates.first}, views=${d.allDayAppointmentViewCollection.map((v) => '${v.appointment?.id}/${v.position}/${v.maxPositions}/${v.appointmentRect}').toList()}';
        })
        .join('\n');
    expect(
      tile,
      findsOneWidget,
      reason: 'top=${h.coords?.viewportTopInBody}\n$debugPanels',
    );
    final rect = tester
        .getRect(tile)
        .intersect(const Rect.fromLTWH(42, 0, 378, 850));
    expect(rect.width, greaterThan(20));
    expect(rect.bottom, lessThanOrEqualTo(h.coords!.viewportTopInBody + 1));
    await drag.cancel();
    await tester.pumpAndSettle();
  });
  testWidgets(
    'tap and vertical scroll never commit a horizontal business window',
    (tester) async {
      final h = await _mount(tester, 3);
      final count = h.windows.length;
      await tester.tapAt(const Offset(180, 500));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(180, 500), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(h.windows.length, count);
    },
  );

  testWidgets(
    'enable after paged navigation normalizes the painted date block',
    (tester) async {
      final h = await _mount(tester, 3, policy: DayWindowNavigation.paged);
      h.controller.forward!();
      await tester.pumpAndSettle();
      final first = h.windows.last.first;
      h.rebuild(() => h.policy = DayWindowNavigation.continuous);
      await tester.pumpAndSettle();
      expect(h.coords!.visibleDates.first, first);
      expect(h.key.currentState!.queryDateForGlobalX(100), first);
      _checkVisibleEvents(tester, h);
    },
  );
  testWidgets('resize and changed date bounds invalidate active motion', (
    tester,
  ) async {
    final h = await _mount(tester, 3);
    await tester.flingFrom(const Offset(350, 400), const Offset(-180, 0), 1800);
    await tester.pump(const Duration(milliseconds: 90));
    final generation = h.coords!.dayWindow!.generation;
    h.rebuild(() {
      h.minDate = DateTime(2026, 10, 19);
      h.maxDate = DateTime(2026, 10, 23);
    });
    tester.view.physicalSize = const Size(500, 750);
    await tester.pumpAndSettle();
    expect(h.coords!.dayWindow!.generation, greaterThan(generation));
    expect(h.coords!.dayWindow!.phase, DayWindowPhase.idle);
    expect(h.coords!.dayWindow!.settledFirstDate, h.windows.last.first);
    expect(h.windows.last.last.isAfter(h.maxDate!), isFalse);
    final first = h.windows.last.first;
    await tester.pump(const Duration(seconds: 2));
    expect(h.windows.last.first, first);
  });

  testWidgets(
    'add/remove notifications refresh partial-day appointments in place',
    (tester) async {
      final h = await _mount(tester, 3);
      final drag = await tester.startGesture(const Offset(300, 400));
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump();
      await drag.moveBy(Offset(-h.column * .8, 0));
      await tester.pumpAndSettle();
      final x = h.coords!.dayWindow!.xForDate(DateTime(2026, 10, 22));
      final extra = Appointment(
        id: 'added-all',
        isAllDay: true,
        startTime: DateTime(2026, 10, 22),
        endTime: DateTime(2026, 10, 22, 23),
        subject: 'Added',
      );
      h.data.appointments!.add(extra);
      h.data.notifyListeners(CalendarDataSourceAction.add, [extra]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('added-all')), findsOneWidget);
      expect(
        h.coords!.dayWindow!.xForDate(DateTime(2026, 10, 22)),
        closeTo(x, .01),
      );
      h.data.appointments!.remove(extra);
      h.data.notifyListeners(CalendarDataSourceAction.remove, [extra]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('added-all')), findsNothing);
      await drag.cancel();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'all-day panel and vertical scrolling work without a coordinate consumer',
    (tester) async {
      await _mount(tester, 3, allDay: true, captureCoordinates: false);
      final all = tester.getRect(find.byKey(const ValueKey('all-0')).first);
      final timed = tester.getRect(find.byKey(const ValueKey('event-20')));
      expect(all.bottom, lessThanOrEqualTo(timed.top));
      final before = timed.top;
      await tester.dragFrom(const Offset(220, 500), const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('event-20'))).top,
        lessThan(before),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final days in [3, 7]) {
    testWidgets(
      '$days-day long press and deferred drag target the exposed adjacent event',
      (tester) async {
        final h = await _mount(tester, days, allowDrag: true);
        await tester.flingFrom(
          const Offset(350, 450),
          const Offset(-150, 0),
          1500,
        );
        await tester.pump(const Duration(milliseconds: 50));
        final snapshot = h.coords!.dayWindow!;
        final date = snapshot.renderedDates.lastWhere((date) {
          final x = snapshot.xForDate(date);
          return x > 42 && x < 400;
        });
        final id = 'event-${date.difference(DateTime(2026, 10)).inDays + 1}';
        final rect = tester.getRect(find.byKey(ValueKey(id)));
        final point =
            rect.intersect(const Rect.fromLTWH(42, 0, 378, 850)).center;
        expect(h.key.currentState!.queryDateForGlobalX(point.dx), date);
        final press = await tester.startGesture(point);
        await tester.pump(const Duration(milliseconds: 600));
        expect(h.longPresses, hasLength(1));
        expect(
          (h.longPresses.single.appointments!.single as Appointment).id,
          id,
        );
        expect(
          h.dragStarts,
          isEmpty,
          reason: 'SF-7 keeps a stationary long press deferred',
        );
        await press.moveBy(const Offset(0, 60));
        await tester.pump();
        expect((h.dragStarts.single.appointment! as Appointment).id, id);
        await press.up();
        await tester.pumpAndSettle();
        expect(
          h.dragEnds.single.droppingTime,
          DateTime(date.year, date.month, date.day, 11),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'one spanning all-day event keeps its row across the block seam',
    (tester) async {
      final h = await _mount(tester, 3);
      h.data.appointments!.addAll([
        Appointment(
          id: 'span-b',
          isAllDay: true,
          startTime: DateTime(2026, 10, 20),
          endTime: DateTime(2026, 10, 22, 23),
        ),
        Appointment(
          id: 'span-a',
          isAllDay: true,
          startTime: DateTime(2026, 10, 21),
          endTime: DateTime(2026, 10, 23, 23),
        ),
      ]);
      h.data.notifyListeners(
        CalendarDataSourceAction.reset,
        h.data.appointments!,
      );
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(const Offset(300, 400));
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump();
      await drag.moveBy(Offset(-h.column * 1.8, 0));
      await tester.pumpAndSettle();
      final pieces =
          find
              .byKey(const ValueKey('span-a'))
              .evaluate()
              .map((e) {
                final box = e.findRenderObject()! as RenderBox;
                return (box.localToGlobal(Offset.zero) & box.size).intersect(
                  const Rect.fromLTWH(42, 0, 378, 850),
                );
              })
              .where((r) => !r.isEmpty)
              .toList();
      expect(pieces, hasLength(2));
      expect(pieces.first.top, closeTo(pieces.last.top, .1));
      await drag.cancel();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('exposed adjacent more button expands all blocks together', (
    tester,
  ) async {
    final h = await _mount(tester, 3);
    h.data.appointments!.addAll([
      for (var i = 0; i < 6; i++)
        Appointment(
          id: 'long-all-$i',
          isAllDay: true,
          startTime: DateTime(2026, 10),
          endTime: DateTime(2026, 12),
        ),
    ]);
    h.data.notifyListeners(
      CalendarDataSourceAction.reset,
      h.data.appointments!,
    );
    await tester.pumpAndSettle();
    await tester.flingFrom(const Offset(350, 450), const Offset(-150, 0), 1500);
    await tester.pump(const Duration(milliseconds: 80));
    final snapshot = h.coords!.dayWindow!;
    final lastX =
        snapshot.renderedDates
            .map(snapshot.xForDate)
            .where((x) => x > 42 && x < 420)
            .last;
    final before = h.coords!.viewportTopInBody;
    final point = Offset((lastX + 420) / 2, before - 10);
    final press = await tester.startGesture(point);
    await tester.pump(const Duration(milliseconds: 30));
    await press.up();
    await tester.pumpAndSettle();
    expect(h.coords!.viewportTopInBody, greaterThan(before + 40));
    final bottomRow = find.byKey(const ValueKey('long-all-5'));
    expect(bottomRow, findsWidgets);
    final visible =
        bottomRow
            .evaluate()
            .map((e) {
              final box = e.findRenderObject()! as RenderBox;
              return (box.localToGlobal(Offset.zero) & box.size).intersect(
                const Rect.fromLTWH(42, 0, 378, 850),
              );
            })
            .where((r) => !r.isEmpty)
            .toList();
    expect(visible, isNotEmpty);
    for (final rect in visible) {
      expect(rect.bottom, lessThanOrEqualTo(h.coords!.viewportTopInBody));
    }
  });

  testWidgets(
    'continuous zoom preserves the prepared focal time in every block',
    (tester) async {
      final h = await _mount(tester, 3);
      h.controller.forward!();
      await tester.pumpAndSettle();
      final before = h.coords!;
      final focalY = before.viewportTopInBody + 250;
      final time = h.key.currentState!.queryTimeForGlobalY(focalY)!;
      final target = (before.scrollOffset + 250) * 2 - 250;
      h.key.currentState!.setTimelineScrollOffset(
        target,
        allowOutOfRange: true,
        nextIntervalHeight: 120,
      );
      h.rebuild(() => h.intervalHeight = 120);
      await tester.pumpAndSettle();
      expect(h.coords!.scrollOffset, closeTo(target, .5));
      expect(h.key.currentState!.queryTimeForGlobalY(focalY), time);
      for (var i = 0; i < 3; i++) {
        final slot =
            h.key.currentState!.queryEmptySlotAt(
              Offset(42 + (i + .5) * h.column, focalY),
            )!;
        expect(slot.time.hour, time.hour);
        expect(slot.time.minute, time.minute);
      }
    },
  );

  testWidgets(
    'vertical takeover on a partial column scrolls every visible date',
    (tester) async {
      final h = await _mount(tester, 7);
      await tester.flingFrom(
        const Offset(350, 450),
        const Offset(-150, 0),
        1500,
      );
      await tester.pump(const Duration(milliseconds: 80));
      final scroll = h.coords!.scrollOffset;
      final press = await tester.startGesture(const Offset(410, 500));
      await tester.pump();
      await press.moveBy(const Offset(0, -20));
      await tester.pump();
      await press.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.coords!.scrollOffset, greaterThan(scroll + 40));
      _checkVisibleEvents(tester, h);
      await press.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'data notification between deferred press and move keeps the drag owner',
    (tester) async {
      final h = await _mount(tester, 3, allowDrag: true);
      final press = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('event-20'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final extra = Appointment(
        id: 'during-drag',
        startTime: DateTime(2026, 10, 22, 12),
        endTime: DateTime(2026, 10, 22, 13),
      );
      h.data.appointments!.add(extra);
      h.data.notifyListeners(CalendarDataSourceAction.add, [extra]);
      // No frame between cache invalidation and the next input event.
      await press.moveBy(const Offset(0, 60));
      await press.up();
      await tester.pumpAndSettle();
      expect((h.dragStarts.single.appointment! as Appointment).id, 'event-20');
      expect(h.dragEnds.single.droppingTime, DateTime(2026, 10, 20, 11));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unsupported single-day continuous policy preserves the legacy all-day viewport',
    (tester) async {
      tester.view.physicalSize = const Size(420, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = _Source();
      data.appointments!.add(
        Appointment(
          id: 'single-all-day',
          isAllDay: true,
          startTime: DateTime(2026, 10, 19),
          endTime: DateTime(2026, 10, 19),
        ),
      );
      Rect? pagedTimedRect;
      for (final policy in DayWindowNavigation.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: Scaffold(
              body: SfCalendar(
                key: ValueKey(policy),
                view: CalendarView.day,
                dayWindowNavigation: policy,
                initialDisplayDate: DateTime(2026, 10, 19, 9),
                headerHeight: 0,
                viewHeaderHeight: 0,
                showCurrentTimeIndicator: false,
                dataSource: data,
                appointmentBuilder:
                    (context, details) => ColoredBox(
                      key: ValueKey<String>(
                        (details.appointments.single as Appointment).id!
                            as String,
                      ),
                      color: Colors.blue,
                    ),
                timeSlotViewSettings: const TimeSlotViewSettings(
                  numberOfDaysInView: 1,
                  timeRulerSize: 42,
                  timeIntervalHeight: 60,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final timedRect = tester.getRect(
          find.byKey(const ValueKey('event-19')),
        );
        if (policy == DayWindowNavigation.paged) {
          pagedTimedRect = timedRect;
        } else {
          expect(timedRect, pagedTimedRect, reason: policy.name);
        }
        expect(
          find.byKey(const ValueKey('single-all-day')).hitTestable(),
          findsOneWidget,
          reason:
              'Unsupported continuous policy must keep the all-day row visible',
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  test(
    'default stays paged and date geometry crosses month/year boundaries',
    () {
      expect(SfCalendar().dayWindowNavigation, DayWindowNavigation.paged);
      final frame = DayWindowSnapshot(
        renderedDates: [DateTime(2026, 12, 30)],
        visibleDayCount: 3,
        columnWidth: 100,
        contentLeft: 42,
        horizontalOffset: -50,
        settledFirstDate: DateTime(2026, 12, 30),
        phase: DayWindowPhase.dragging,
        generation: 1,
        sequence: 1,
        isRTL: false,
      );
      expect(frame.xForDate(DateTime(2027)), 192);
      expect(
        () => frame.renderedDates.add(DateTime(2027)),
        throwsUnsupportedError,
      );
    },
  );
  testWidgets(
    'stationary edge drag updates its date as the window auto-navigates',
    (tester) async {
      final h = await _mount(tester, 3, allowDrag: true);
      final point = tester.getCenter(find.byKey(const ValueKey('event-20')));
      final press = await tester.startGesture(point);
      await tester.pump(const Duration(milliseconds: 600));
      await press.moveTo(Offset(419, point.dy));
      await tester.pump();
      final initial = h.dragUpdates.last.draggingTime;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(h.windows.last.first.isAfter(DateTime(2026, 10, 19)), isTrue);
      final last = h.dragUpdates.last.draggingTime;
      expect(last!.isAfter(initial!), isTrue);
      await press.up();
      await tester.pumpAndSettle();
      expect(h.dragEnds.single.droppingTime, last);
    },
  );
}

class _Source extends CalendarDataSource {
  _Source() {
    appointments = [
      for (var day = -10; day < 100; day++)
        Appointment(
          id: 'event-$day',
          startTime: DateTime(2026, 10, day, 10),
          endTime: DateTime(2026, 10, day, 11),
          subject: 'Event $day',
        ),
    ];
  }
}

class _Harness {
  _Harness(this.days);
  final int days;
  var key = GlobalKey<SfCalendarTimelineQueryApi>();
  final rasterKey = GlobalKey();
  final controller = CalendarController();
  final windows = <List<DateTime>>[];
  final data = _Source();
  final longPresses = <CalendarLongPressDetails>[];
  final dragStarts = <AppointmentDragStartDetails>[];
  final dragUpdates = <AppointmentDragUpdateDetails>[];
  final dragEnds = <AppointmentDragEndDetails>[];
  late StateSetter rebuild;
  ViewNavigationMode navigation = ViewNavigationMode.snap;
  DayWindowNavigation policy = DayWindowNavigation.continuous;
  CalendarView? view;
  Color background = Colors.white;
  bool rtl = false;
  DateTime? minDate, maxDate;
  double intervalHeight = 60;
  int firstDayOfWeek = 1;
  SfCalendarTimelineCoordinates? coords;
  double get column => 378 / days;
}

Future<_Harness> _mount(
  WidgetTester tester,
  int days, {
  bool rtl = false,
  bool bounded = false,
  bool allDay = false,
  bool captureCoordinates = true,
  bool allowDrag = false,
  DayWindowNavigation policy = DayWindowNavigation.continuous,
}) async {
  tester.view.physicalSize = const Size(420, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final h =
      _Harness(days)
        ..rtl = rtl
        ..policy = policy;
  if (bounded) {
    h.minDate = DateTime(2026, 10, 19);
    h.maxDate = DateTime(2026, 10, 19 + days + 2);
  }
  if (allDay) {
    h.data.appointments!.addAll([
      for (var i = 0; i < 6; i++)
        Appointment(
          id: 'all-$i',
          isAllDay: true,
          startTime: DateTime(2026, 10, 20),
          endTime: DateTime(2026, 10, 23),
          subject: 'All day $i',
        ),
    ]);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: Scaffold(
        body: RepaintBoundary(
          key: h.rasterKey,
          child: StatefulBuilder(
            builder: (context, rebuild) {
              h.rebuild = rebuild;
              return Directionality(
                textDirection: h.rtl ? TextDirection.rtl : TextDirection.ltr,
                child: SfCalendar(
                  key: h.key,
                  controller: h.controller,
                  dayWindowNavigation: h.policy,
                  viewNavigationMode: h.navigation,
                  minDate: h.minDate,
                  maxDate: h.maxDate,
                  backgroundColor: h.background,
                  view:
                      h.view ??
                      (days == 3 ? CalendarView.day : CalendarView.week),
                  firstDayOfWeek: h.firstDayOfWeek,
                  initialDisplayDate: DateTime(2026, 10, 19, 9),
                  headerHeight: 0,
                  viewHeaderHeight: 50,
                  showCurrentTimeIndicator: false,
                  cellEndPadding: 0,
                  preserveTimelineScaleOffset: true,
                  allDayPanelChronologicalSort: true,
                  dataSource: h.data,
                  appointmentBuilder:
                      (context, details) => ColoredBox(
                        key:
                            details.appointments.length == 1
                                ? ValueKey<String>(
                                  (details.appointments.single as Appointment)
                                          .id!
                                      as String,
                                )
                                : null,
                        color: Colors.blue,
                      ),
                  onViewChanged: (value) => h.windows.add(value.visibleDates),
                  onTimelineCoordinatesChanged:
                      captureCoordinates ? (value) => h.coords = value : null,
                  allowDragAndDrop: allowDrag,
                  deferAppointmentDragOnLongPress: true,
                  onLongPress: h.longPresses.add,
                  onDragStart: h.dragStarts.add,
                  onDragUpdate: h.dragUpdates.add,
                  dragAndDropSettings: const DragAndDropSettings(
                    autoNavigateDelay: Duration(seconds: 2),
                    allowScroll: false,
                  ),
                  onDragEnd: h.dragEnds.add,
                  timeSlotViewSettings: TimeSlotViewSettings(
                    numberOfDaysInView: days == 3 ? 3 : -1,
                    timeRulerSize: 42,
                    timeIntervalHeight: h.intervalHeight,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

void _checkVisibleEvents(WidgetTester tester, _Harness h) {
  var inspected = 0;
  final rectangles = <String>[];
  for (var day = 1; day < 70; day++) {
    final finder = find.byKey(ValueKey('event-$day'));
    for (final element in finder.evaluate()) {
      final box = element.findRenderObject()! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      rectangles.add('$day: $rect');
      final clipped = rect.intersect(
        Rect.fromLTWH(h.rtl ? 0 : 42, h.coords!.viewportTopInBody, 378, 800),
      );
      if (clipped.width < 3 || clipped.height < 3) {
        continue;
      }
      inspected++;
      final point = clipped.center;
      expect(
        h.key.currentState!.queryDateForGlobalX(point.dx),
        DateTime(2026, 10, day),
        reason: 'Hit date follows rendered event-$day at $point',
      );
      expect(
        h.key.currentState!.queryEmptySlotAt(point)?.date,
        DateTime(2026, 10, day),
      );
      final snapshot = h.coords!.dayWindow;
      expect(snapshot, isNotNull);
      expect(
        rect.left - snapshot!.xForDate(DateTime(2026, 10, day)),
        closeTo(0, 2),
        reason: 'Host snapshot must match painted event column',
      );
      expect(snapshot.renderedDates.length, h.days * 3);
    }
  }
  expect(
    inspected,
    greaterThanOrEqualTo(h.days),
    reason: rectangles.join('\n'),
  );
}
