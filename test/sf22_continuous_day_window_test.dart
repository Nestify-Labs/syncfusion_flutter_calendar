import 'dart:ui' as ui;
// SF-22: product-level day-window gestures, independent of private page state.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_engine/appointment_helper.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_layout/allday_appointment_layout.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_layout/appointment_layout.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/common/calendar_view_helper.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/views/calendar_view.dart';

void main() {
  // SF-22: hidden block rulers must not paint; the shared fixed ruler still does.
  for (final days in [3, 7]) {
    for (final rtl in [false, true]) {
      testWidgets('$days-day hidden rulers skip paint with RTL=$rtl', (
        tester,
      ) async {
        final h = await _mount(tester, days, rtl: rtl);
        List<_CountingRulerPainter> watch(String name) {
          final watched = <_CountingRulerPainter>[];
          for (final element
              in find.byType(CustomPaint, skipOffstage: false).evaluate()) {
            final render = element.renderObject! as RenderCustomPaint;
            if (render.painter.runtimeType.toString() != name)
              continue;
            final counter = _CountingRulerPainter(render.painter!);
            render.painter = counter;
            watched.add(counter);
          }
          expect(
            watched,
            isNotEmpty,
            reason: 'the paint probe must be attached',
          );
          return watched;
        }

        final hidden = watch('_TimeRulerView');
        final fixed = watch('_DayWindowRulerPainter');
        await tester.pump();
        expect(fixed.fold(0, (n, p) => n + p.paints), greaterThan(0));
        expect(hidden.fold(0, (n, p) => n + p.paints), 0);

        h.rebuild(() => h.policy = DayWindowNavigation.paged);
        await tester.pumpAndSettle();
        final paged = watch('_TimeRulerView');
        await tester.pump();
        expect(paged.fold(0, (n, p) => n + p.paints), greaterThan(0));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('fixed ruler reuses pixels and invalidates configuration', (
    tester,
  ) async {
    final h = await _mount(tester, 3);
    CustomPainter painter(String name) =>
        tester
            .widgetList<CustomPaint>(
              find.byType(CustomPaint, skipOffstage: false),
            )
            .map((widget) => widget.painter)
            .firstWhere((painter) => painter.runtimeType.toString() == name)!;
    ui.Picture fixedPicture() {
      final canvas = _RulerPictureCanvas();
      painter('_DayWindowRulerPainter').paint(canvas, const Size(420, 850));
      expect(
        canvas.pictures,
        hasLength(1),
        reason: 'the fixed time labels use one retained picture',
      );
      return canvas.pictures.single;
    }

    Future<void> matchesUncached(ui.Picture cached, int height) async {
      final recorder = ui.PictureRecorder();
      painter(
        '_TimeRulerView',
      ).paint(Canvas(recorder), Size(42, height.toDouble()));
      final native = recorder.endRecording();
      final pixels = await tester.runAsync(() async {
        Future<List<int>> rgba(ui.Picture picture) async {
          final image = await picture.toImage(42, height);
          final data = await image.toByteData();
          image.dispose();
          return data!.buffer.asUint8List();
        }

        return [await rgba(cached), await rgba(native)];
      });
      native.dispose();
      expect(
        pixels![0],
        pixels[1],
        reason: 'cached labels and borders match native pixels',
      );
    }

    var first = fixedPicture();
    expect(fixedPicture(), same(first));
    await matchesUncached(first, 1440);
    h.rebuild(() => h.intervalHeight = 80);
    await tester.pumpAndSettle();
    final resized = fixedPicture();
    expect(resized, isNot(same(first)));
    await matchesUncached(resized, 1920);
    first = resized;
    h.rebuild(() => h.rtl = true);
    await tester.pumpAndSettle();
    final rtl = fixedPicture();
    expect(rtl, isNot(same(first)));
    await matchesUncached(rtl, 1920);
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    await tester.pump();
    final fontsChanged = fixedPicture();
    expect(fontsChanged, isNot(same(rtl)));
    await matchesUncached(fontsChanged, 1920);
    h.rebuild(
      () =>
          h.rulerTextStyle = const TextStyle(
            color: Colors.purple,
            fontSize: 10,
          ),
    );
    await tester.pumpAndSettle();
    final styled = fixedPicture();
    expect(styled, isNot(same(fontsChanged)));
    await matchesUncached(styled, 1920);
    h.controller.displayDate = DateTime(2026, 10, 24, 9);
    await tester.pumpAndSettle();
    final dated = fixedPicture();
    expect(dated, isNot(same(styled)));
    await matchesUncached(dated, 1920);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  // SF-22: nearly identical light swipes must not jump several extra dates
  // when the release velocity crosses the inertia threshold (#4242).
  for (final days in [3, 7]) {
    for (final direction in [-1.0, 1.0]) {
      testWidgets(
        '$days-day light swipe has no inertia threshold cliff $direction',
        (tester) async {
          final h = await _mount(tester, days);
          final dates = <DateTime>[];
          final origin = DateTime(2026, 10, 19);
          for (final speed in [299.0, 301.0, 900.0, 1800.0]) {
            h.controller.displayDate = DateTime(2026, 10, 19, 9);
            await tester.pumpAndSettle();
            await tester.flingFrom(
              const Offset(210, 400),
              Offset(direction * 60, 0),
              speed,
            );
            await tester.pumpAndSettle();
            dates.add(h.coords!.dayWindow!.settledFirstDate);
            _checkVisibleEvents(tester, h);
          }
          expect(dates[1], dates.first);
          final travel = dates.map((date) => date.difference(origin).inDays);
          expect(travel.elementAt(2).abs(), greaterThan(travel.first.abs()));
          expect(travel.last.abs(), greaterThan(travel.elementAt(2).abs()));
          expect(travel.last * -direction, greaterThan(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  // SF-22: restoring a same-day timed anchor must retain its time component.
  for (final days in [3, 7]) {
    testWidgets('$days-day same-date displayDate restores time offset', (
      tester,
    ) async {
      final h = await _mount(tester, days, displayDate: DateTime(2026, 10, 19));
      expect(h.coords!.scrollOffset, closeTo(0, .5));
      h.controller.displayDate = DateTime(2026, 10, 19, 5, 55);
      await tester.pumpAndSettle();
      expect(h.coords!.dayWindow!.settledFirstDate, DateTime(2026, 10, 19));
      expect(h.coords!.scrollOffset, closeTo(355, .5));
    });
  }
  // SF-22: a delayed navigation scroll must not read a disposed page.
  for (final days in [3, 7]) {
    testWidgets('$days-day queued timed navigation survives disposal', (
      tester,
    ) async {
      final h = await _mount(tester, days);
      h.controller.displayDate = DateTime(2026, 10, 19, 5, 55);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
  // SF-22: repeated timed navigation must also retain legacy paging behavior.
  for (final days in [3, 7]) {
    for (final policy in DayWindowNavigation.values) {
      testWidgets(
        '$days-day $policy explicit timed navigation retains offset',
        (tester) async {
          final h = await _mount(
            tester,
            days,
            policy: policy,
            displayDate: DateTime(2026, 10, 19),
          );
          for (final target in [
            DateTime(2026, 10, 19, 5, 55),
            DateTime(2026, 11, 4, 8, 40),
            DateTime(2026, 11, 4, 2, 15),
            DateTime(2026, 11, 3, 6, 35),
          ]) {
            h.controller.displayDate = target;
            // Hosts rebuild after explicit navigation in the legacy paged path.
            h.rebuild(() {});
            await tester.pumpAndSettle();
            expect(h.controller.displayDate, target);
            expect(
              h.windows.last,
              contains(DateTime(target.year, target.month, target.day)),
            );
            expect(
              h.coords!.scrollOffset,
              closeTo(target.hour * 60 + target.minute, .5),
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
  // SF-22: one buffer expansion must preserve each block's independent projection.
  for (final (days, rtl) in [(3, false), (7, false), (3, true), (7, true)]) {
    testWidgets(
      '$days-day buffered recurrence projection is equivalent and shared RTL=$rtl',
      (tester) async {
        final h = await _mount(
          tester,
          days,
          rtl: rtl,
          timeZone: 'Eastern Standard Time',
          displayDate: DateTime(2026, 10, 31, 9),
        );
        h.data.appointments = [
          Appointment(
            id: 'recurring-span',
            startTime: DateTime(2026, 10, 1),
            endTime: DateTime(2026, 10, 5),
            isAllDay: true,
            recurrenceRule: 'FREQ=WEEKLY;BYDAY=TH;COUNT=12',
            recurrenceExceptionDates: [DateTime.utc(2026, 10, 22, 12)],
          ),
          Appointment(
            id: 'overnight',
            startTime: DateTime(2026, 10, 1, 23, 15),
            endTime: DateTime(2026, 10, 2, 1, 15),
            startTimeZone: 'Eastern Standard Time',
            endTimeZone: 'Eastern Standard Time',
            recurrenceRule: 'FREQ=DAILY;COUNT=60',
            recurrenceExceptionDates: [DateTime.utc(2026, 11, 1, 12)],
          ),
          Appointment(
            id: 'midnight',
            startTime: DateTime(2026, 10, 1, 22),
            endTime: DateTime(2026, 10, 2),
            startTimeZone: 'Eastern Standard Time',
            endTimeZone: 'Eastern Standard Time',
            recurrenceRule: 'FREQ=DAILY;UNTIL=20261104T000000Z',
          ),
          Appointment(
            id: 'zoned',
            startTime: DateTime(2026, 10, 1, 14),
            endTime: DateTime(2026, 10, 1, 15),
            startTimeZone: 'UTC',
            endTimeZone: 'UTC',
            recurrenceRule: 'FREQ=DAILY',
          ),
          Appointment(
            id: 'long-timed',
            startTime: DateTime(2026, 10, 28, 10),
            endTime: DateTime(2026, 10, 29, 12),
            recurrenceRule: 'FREQ=DAILY;COUNT=12',
          ),
        ];
        h.data.notifyListeners(
          CalendarDataSourceAction.reset,
          h.data.appointments!,
        );
        await tester.pumpAndSettle();

        List<Object?> signature(CalendarAppointment a) => [
          a.id,
          a.recurrenceId,
          a.subject,
          a.startTime,
          a.endTime,
          a.actualStartTime,
          a.actualEndTime,
          a.exactStartTime,
          a.exactEndTime,
          a.isAllDay,
          a.isSpanned,
          a.notes,
        ];
        void check({bool parentShared = false}) {
          final layouts =
              tester
                  .widgetList<AppointmentLayout>(find.byType(AppointmentLayout))
                  .toList();
          expect(layouts, hasLength(3));
          final seen = <(Object?, DateTime, DateTime), CalendarAppointment>{};
          var sharedCount = 0;
          for (final layout in layouts) {
            final expected = AppointmentHelper.getVisibleAppointments(
              layout.visibleDates.first,
              layout.visibleDates.last,
              AppointmentHelper.generateCalendarAppointments(
                h.data,
                h.timeZone,
              ),
              h.timeZone,
              false,
            );
            final actual = layout.visibleAppointments.value!;
            expect(
              actual.map(signature).toList(),
              expected.map(signature).toList(),
            );
            expect(
              actual.where(
                (a) =>
                    a.id == 'overnight' &&
                    a.exactStartTime.month == 11 &&
                    a.exactStartTime.day == 1,
              ),
              isEmpty,
              reason: 'The excluded overnight occurrence stays absent',
            );
            for (final a in actual) {
              final key = (a.id, a.actualStartTime, a.actualEndTime);
              final previous = seen[key];
              if (previous != null) {
                sharedCount++;
                expect(
                  identical(a, previous),
                  isTrue,
                  reason:
                      'The same buffered occurrence must not be expanded twice',
                );
              }
              seen[key] = a;
            }
          }
          expect(sharedCount, greaterThan(0));
          if (parentShared) {
            // SF-22: navigation hands the existing projection to the parent;
            // occurrence objects are shared, but mutable lists stay separate.
            final state = UpdateCalendarStateDetails();
            tester
                .widget<CustomCalendarScrollView>(
                  find.byType(CustomCalendarScrollView),
                )
                .getCalendarState(state);
            final current = layouts.singleWhere(
              (layout) =>
                  layout.visibleDates.first ==
                  state.currentViewVisibleDates.first,
            );
            final projected = current.visibleAppointments.value!;
            expect(projected, isNotEmpty);
            expect(
              state.visibleAppointments.map(signature).toList(),
              projected.map(signature).toList(),
            );
            expect(state.visibleAppointments, isNot(same(projected)));
            for (var i = 0; i < projected.length; i++) {
              expect(
                state.visibleAppointments[i],
                same(projected[i]),
                reason: 'Parent navigation must not expand recurrence again',
              );
            }
          }
        }

        check();
        (h.data.appointments!.first as Appointment).subject = 'Updated span';
        h.data.notifyListeners(
          CalendarDataSourceAction.reset,
          h.data.appointments!,
        );
        await tester.pumpAndSettle();
        check();
        h.controller.forward!();
        await tester.pumpAndSettle();
        check(parentShared: true);
        final drag = await tester.startGesture(const Offset(300, 400));
        await drag.moveBy(const Offset(-20, 0));
        await tester.pump();
        await drag.moveBy(Offset(-h.column * .8, 0));
        await tester.pump(const Duration(milliseconds: 500));
        await drag.up();
        await tester.pumpAndSettle();
        check(parentShared: true);
        h.controller.backward!();
        await tester.pumpAndSettle();
        check(parentShared: true);
        expect(tester.takeException(), isNull);
      },
    );
  }

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

  // SF-22: movement alone must not rebuild unchanged adjacent layouts.
  for (final days in [3, 7]) {
    for (final direction in [-1, 1]) {
      testWidgets('$days-day adjacent layouts survive held travel $direction', (
        tester,
      ) async {
        final h = await _mount(tester, days);
        List<AppointmentLayout> layouts() =>
            tester
                .widgetList<AppointmentLayout>(find.byType(AppointmentLayout))
                .toList();
        final before = layouts();
        expect(before, hasLength(3));
        final drag = await tester.startGesture(const Offset(210, 400));
        await drag.moveBy(Offset(direction * 20, 0));
        await tester.pump();
        await drag.moveBy(Offset(direction * h.column * .6, 0));
        await tester.pump(const Duration(milliseconds: 300));
        final after = layouts();
        for (var i = 0; i < before.length; i++) {
          expect(
            identical(after[i], before[i]),
            isTrue,
            reason: 'Unchanged block $i must retain its appointment layout',
          );
        }
        _checkVisibleEvents(tester, h);
        await drag.cancel();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  // SF-22: crossing one block must only build the newly exposed dates.
  for (final days in [3, 7]) {
    for (final rtl in [false, true]) {
      for (final direction in [-1, 1]) {
        testWidgets(
          '$days-day boundary retains overlapping blocks $rtl $direction',
          (tester) async {
            final h = await _mount(tester, days, rtl: rtl);
            Map<DateTime, AppointmentLayout> layouts() => {
              for (final layout in tester.widgetList<AppointmentLayout>(
                find.byType(AppointmentLayout),
              ))
                layout.visibleDates.first: layout,
            };
            final before = layouts();
            final initialBuilds = h.appointmentBuilds;
            final offset = h.coords!.scrollOffset;
            final commits = h.windows.length;
            final drag = await tester.startGesture(const Offset(210, 400));
            await drag.moveBy(Offset(direction * 20, 0));
            await tester.pump();
            await drag.moveBy(Offset(direction * h.column * (days + .2), 0));
            await tester.pump(const Duration(milliseconds: 300));
            final after = layouts();
            expect(after, hasLength(3));
            final retained = after.keys.where(before.containsKey).toList();
            expect(retained, hasLength(2));
            for (final date in retained) {
              expect(
                identical(before[date], after[date]),
                isTrue,
                reason: 'Unchanged dates $date must keep their layout',
              );
            }
            expect(
              h.appointmentBuilds - initialBuilds,
              days,
              reason: 'Only the new block invokes appointmentBuilder',
            );
            expect(h.windows.length, commits);
            expect(h.coords!.scrollOffset, closeTo(offset, .5));
            _checkVisibleEvents(tester, h);
            await drag.cancel();
            await tester.pumpAndSettle();
            _checkVisibleEvents(tester, h);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  // SF-22: data notifications must not discard unrelated buffered layouts.
  for (final days in [3, 7]) {
    testWidgets('$days-day data delta retains unaffected blocks', (
      tester,
    ) async {
      final h = await _mount(tester, days);
      h.data.appointments!.add(
        Appointment(
          id: 'retained-recurring',
          startTime: DateTime(2026, 9, 1, 14),
          endTime: DateTime(2026, 9, 1, 15),
          recurrenceRule: 'FREQ=DAILY',
        ),
      );
      h.data.notifyListeners(
        CalendarDataSourceAction.reset,
        h.data.appointments!,
      );
      await tester.pumpAndSettle();
      Map<DateTime, AppointmentLayout> layouts() => {
        for (final layout in tester.widgetList<AppointmentLayout>(
          find.byType(AppointmentLayout),
        ))
          layout.visibleDates.first: layout,
      };
      var before = layouts();
      final dates = before.keys.toList()..sort();
      final changedDate = dates.last;
      final extra = Appointment(
        id: 'buffer-delta',
        startTime: changedDate.add(const Duration(hours: 12)),
        endTime: changedDate.add(const Duration(hours: 13)),
      );
      for (final action in [
        CalendarDataSourceAction.add,
        CalendarDataSourceAction.remove,
      ]) {
        final initialBuilds = h.appointmentBuilds;
        if (action == CalendarDataSourceAction.add) {
          h.data.appointments!.add(extra);
        } else {
          h.data.appointments!.remove(extra);
        }
        h.data.notifyListeners(action, [extra]);
        await tester.pumpAndSettle();
        expect(
          h.appointmentBuilds - initialBuilds,
          days * 2 + (action == CalendarDataSourceAction.add ? 1 : 0),
          reason: 'Only the affected block invokes appointmentBuilder',
        );
        final after = layouts();
        expect(after.keys, unorderedEquals(before.keys));
        final affected = after[changedDate]!;
        final oldOccurrences =
            before[changedDate]!.visibleAppointments.value!
                .where((a) => a.id == 'retained-recurring')
                .toList();
        final occurrences =
            affected.visibleAppointments.value!
                .where((a) => a.id == 'retained-recurring')
                .toList();
        expect(occurrences, hasLength(days));
        for (var i = 0; i < days; i++) {
          expect(identical(occurrences[i], oldOccurrences[i]), isTrue);
        }
        expect(
          affected.visibleAppointments.value!.any((a) => a.id == extra.id),
          action == CalendarDataSourceAction.add,
        );
        expect(identical(affected, before[changedDate]), isFalse);
        for (final date in dates.where((date) => date != changedDate)) {
          expect(
            identical(after[date], before[date]),
            isTrue,
            reason: '$action must retain unaffected date block $date',
          );
        }
        before = after;
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('value-equal remove/add still rebuilds the notified event', (
    tester,
  ) async {
    final h = await _mount(tester, 3);
    final event = h.data.appointments!.cast<Appointment>().firstWhere(
      (a) => a.id == 'event-20',
    );
    final original = tester.widget(find.byKey(const ValueKey('event-20')));
    // Hosts use this pair to refresh external builder state without changing
    // Appointment values (for example a linked item's completion marker).
    h.data.appointments!.remove(event);
    h.data.notifyListeners(CalendarDataSourceAction.remove, [event]);
    h.data.appointments!.add(event);
    h.data.notifyListeners(CalendarDataSourceAction.add, [event]);
    await tester.pumpAndSettle();
    final refreshed = tester.widget(find.byKey(const ValueKey('event-20')));
    expect(identical(original, refreshed), isFalse);
    final beforeReset =
        tester
            .widgetList<AppointmentLayout>(find.byType(AppointmentLayout))
            .toList();
    h.data.notifyListeners(
      CalendarDataSourceAction.reset,
      h.data.appointments!,
    );
    await tester.pumpAndSettle();
    final afterReset =
        tester
            .widgetList<AppointmentLayout>(find.byType(AppointmentLayout))
            .toList();
    for (var i = 0; i < 3; i++) {
      expect(identical(beforeReset[i], afterReset[i]), isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-day data delta updates shared lanes at constant height', (
    tester,
  ) async {
    final h = await _mount(tester, 3);
    final blocker = Appointment(
      id: 'blocking',
      isAllDay: true,
      startTime: DateTime(2026, 10, 16),
      endTime: DateTime(2026, 10, 16, 23),
    );
    h.data.appointments!.addAll([
      blocker,
      Appointment(
        id: 'spanning',
        isAllDay: true,
        startTime: DateTime(2026, 10, 16, 1),
        endTime: DateTime(2026, 10, 22, 23),
      ),
      for (var i = 0; i < 4; i++)
        Appointment(
          id: 'rows-$i',
          isAllDay: true,
          startTime: DateTime(2026, 10, 20),
          endTime: DateTime(2026, 10, 20, 23),
        ),
    ]);
    h.data.notifyListeners(
      CalendarDataSourceAction.reset,
      h.data.appointments!,
    );
    await tester.pumpAndSettle();
    List<double> tops() =>
        tester
            .elementList(find.byKey(const ValueKey('spanning')))
            .map(
              (e) =>
                  (e.findRenderObject()! as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy,
            )
            .toList();
    final before = tops();
    expect(before, hasLength(3));
    final viewport = h.coords!.viewportTopInBody;
    h.data.appointments!.remove(blocker);
    h.data.notifyListeners(CalendarDataSourceAction.remove, [blocker]);
    await tester.pumpAndSettle();
    final after = tops();
    expect(after, hasLength(3));
    expect(h.coords!.viewportTopInBody, viewport);
    for (var i = 0; i < 3; i++) {
      expect(after[i], lessThan(before[i]));
    }
    h.data.appointments!.add(blocker);
    h.data.notifyListeners(CalendarDataSourceAction.add, [blocker]);
    await tester.pumpAndSettle();
    expect(tops(), before);
    expect(h.coords!.viewportTopInBody, viewport);
    expect(tester.takeException(), isNull);
  });

  // SF-22: recurrence objects already covering retained dates stay reusable.
  for (final days in [3, 7]) {
    testWidgets('$days-day recurring blocks survive boundary and reverse', (
      tester,
    ) async {
      final h = await _mount(tester, days);
      h.data.appointments = [
        Appointment(
          id: 'daily',
          startTime: DateTime(2026, 9, 1, 10),
          endTime: DateTime(2026, 9, 1, 11),
          recurrenceRule: 'FREQ=DAILY',
        ),
      ];
      h.data.notifyListeners(
        CalendarDataSourceAction.reset,
        h.data.appointments!,
      );
      await tester.pumpAndSettle();
      Map<DateTime, AppointmentLayout> layouts() => {
        for (final layout in tester.widgetList<AppointmentLayout>(
          find.byType(AppointmentLayout),
        ))
          layout.visibleDates.first: layout,
      };
      var before = layouts();
      final drag = await tester.startGesture(const Offset(210, 400));
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump();
      for (final direction in [-1, 1]) {
        final builds = h.appointmentBuilds;
        await drag.moveBy(Offset(direction * h.column * (days + .2), 0));
        await tester.pump(const Duration(milliseconds: 300));
        final after = layouts();
        final retained = after.keys.where(before.containsKey).toList();
        expect(retained, hasLength(2));
        for (final date in retained) {
          expect(
            identical(before[date], after[date]),
            isTrue,
            reason: 'Unchanged recurrence instances must keep $date mounted',
          );
        }
        expect(h.appointmentBuilds - builds, days);
        for (final layout in after.values) {
          expect(
            layout.visibleAppointments.value!.map((a) => a.actualStartTime),
            layout.visibleDates.map(
              (d) => DateTime(d.year, d.month, d.day, 10),
            ),
          );
        }
        before = after;
      }
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final days in [3, 7]) {
    testWidgets('$days-day partial settlement retains expanded occurrences', (
      tester,
    ) async {
      final h = await _mount(tester, days);
      h.data.appointments = [
        Appointment(
          id: 'daily',
          startTime: DateTime(2026, 9, 1, 10),
          endTime: DateTime(2026, 9, 1, 11),
          recurrenceRule: 'FREQ=DAILY',
        ),
      ];
      h.data.notifyListeners(
        CalendarDataSourceAction.reset,
        h.data.appointments!,
      );
      await tester.pumpAndSettle();
      Map<DateTime, CalendarAppointment> occurrences() => {
        for (final layout in tester.widgetList<AppointmentLayout>(
          find.byType(AppointmentLayout),
        ))
          for (final a in layout.visibleAppointments.value!)
            a.actualStartTime: a,
      };
      final before = occurrences();
      final drag = await tester.startGesture(const Offset(300, 400));
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump();
      await drag.moveBy(Offset(-h.column * .8, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await drag.up();
      await tester.pumpAndSettle();
      expect(h.windows.last.first, DateTime(2026, 10, 20));
      final after = occurrences();
      expect(after.length, days * 3);
      final retained = after.keys.where(before.containsKey).toList();
      expect(retained.length, days * 3 - 1);
      for (final date in retained) {
        expect(
          identical(after[date], before[date]),
          isTrue,
          reason: 'Already expanded occurrence $date must be reused',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  // SF-22: retain steady-state layouts without suppressing timezone readiness.
  for (final days in [3, 7]) {
    testWidgets('$days-day timezone readiness refreshes all retained blocks', (
      tester,
    ) async {
      final h = await _mount(tester, days);
      final loaded = timeZoneLoaded;
      addTearDown(() => timeZoneLoaded = loaded);
      List<AppointmentLayout> layouts() =>
          tester
              .widgetList<AppointmentLayout>(find.byType(AppointmentLayout))
              .toList();
      final before = layouts();
      final drag = await tester.startGesture(const Offset(210, 400));
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump();
      timeZoneLoaded = !loaded;
      await drag.moveBy(Offset(-h.column * .1, 0));
      await tester.pump();
      final changed = layouts();
      expect(changed, hasLength(3));
      for (var i = 0; i < before.length; i++) {
        expect(identical(changed[i], before[i]), isFalse);
      }
      timeZoneLoaded = loaded;
      await drag.moveBy(Offset(-h.column * .1, 0));
      await tester.pump();
      final ready = layouts();
      for (var i = 0; i < changed.length; i++) {
        expect(identical(ready[i], changed[i]), isFalse);
      }
      _checkVisibleEvents(tester, h);
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final days in [3, 7]) {
    testWidgets(
      '$days-day held drag reuses date blocks until a full block boundary',
      (tester) async {
        final h = await _mount(tester, days);
        final initialBuilds = h.appointmentBuilds;
        final drag = await tester.startGesture(const Offset(350, 400));
        await drag.moveBy(const Offset(-20, 0));
        await tester.pump();
        final insideBlockDistance = h.column * (days - .2);
        await drag.moveBy(Offset(-insideBlockDistance, 0));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          h.appointmentBuilds,
          initialBuilds,
          reason: 'A partial block shift must translate retained date children',
        );
        _checkVisibleEvents(tester, h);

        await drag.moveBy(Offset(-h.column * .4, 0));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          h.appointmentBuilds,
          greaterThan(initialBuilds),
          reason: 'Crossing a full block must mount the next retained block',
        );
        _checkVisibleEvents(tester, h);
        await drag.cancel();
        await tester.pumpAndSettle();
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
    // SF-22: host arrows set displayDate directly after free day browsing.
    testWidgets('$days-day host date arrows retain the browsed first day', (
      tester,
    ) async {
      final h = await _mount(tester, days);
      final drag = await tester.startGesture(const Offset(300, 400));
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump();
      await drag.moveBy(Offset(-h.column * .8, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await drag.up();
      await tester.pumpAndSettle();
      final browsed = DateTime(2026, 10, 20);
      expect(h.windows.last.first, browsed);
      for (final target in [DateTime(2026, 10, 20 + days), browsed]) {
        h.controller.displayDate = target.add(
          const Duration(hours: 5, minutes: 55),
        );
        await tester.pumpAndSettle();
        expect(h.coords!.dayWindow!.settledFirstDate, target);
        expect(h.windows.last.first, target);
        expect(h.coords!.scrollOffset, closeTo(355, .5));
        _checkVisibleEvents(tester, h);
      }
    });
    // SF-22: an explicit last-date target must keep the whole window in range.
    testWidgets('$days-day explicit date navigation clamps the whole window', (
      tester,
    ) async {
      final h = await _mount(tester, days, bounded: true);
      h.controller.displayDate = h.maxDate;
      await tester.pumpAndSettle();
      expect(h.windows.last.last, h.maxDate);
      expect(h.coords!.dayWindow!.settledFirstDate, DateTime(2026, 10, 22));
      h.controller.displayDate = h.minDate;
      await tester.pumpAndSettle();
      expect(h.windows.last.first, h.minDate);
      expect(tester.takeException(), isNull);
      _checkVisibleEvents(tester, h);
    });
    // SF-22: host arrows derive their next target from the public displayDate.
    for (final bounded in [false, true]) {
      testWidgets(
        '$days-day host arrows reverse at ${bounded ? "custom" : "year"} limits',
        (tester) async {
          final h = await _mount(tester, days, bounded: bounded);
          if (bounded) {
            // Leave room for a full inward step at either custom boundary.
            h.rebuild(() => h.maxDate = DateTime(2026, 11, 30));
            await tester.pumpAndSettle();
          }
          final calendar = tester.widget<SfCalendar>(find.byType(SfCalendar));
          DateTime timed(DateTime date, [int delta = 0]) => DateTime(
            date.year,
            date.month,
            date.day + delta,
            5,
            55,
            13,
            24,
            35,
          );
          final lastFirst = DateTime(
            calendar.maxDate.year,
            calendar.maxDate.month,
            calendar.maxDate.day + 1 - days,
          );
          for (final edge in [lastFirst, calendar.minDate]) {
            final outward = edge == lastFirst ? days : -days;
            h.controller.displayDate = timed(edge);
            await tester.pumpAndSettle();
            for (final delta in [outward, -outward, outward]) {
              h.controller.displayDate = timed(
                h.controller.displayDate!,
                delta,
              );
              await tester.pumpAndSettle();
              final expected = delta == outward ? edge : timed(edge, -outward);
              expect(
                h.windows.last.first,
                DateTime(expected.year, expected.month, expected.day),
              );
              expect(h.controller.displayDate, timed(expected));
              expect(h.coords!.scrollOffset, closeTo(355, .5));
              expect(tester.takeException(), isNull);
            }
          }
        },
      );
    }
    // SF-22: real default calendar limits include full-window edge navigation.
    testWidgets('$days-day default year limits retain legal windows', (
      tester,
    ) async {
      final h = await _mount(tester, days);
      final calendar = tester.widget<SfCalendar>(find.byType(SfCalendar));
      expect(calendar.minDate, DateTime(1));
      expect(calendar.maxDate, DateTime(9999, 12, 31));
      h.controller.displayDate = calendar.maxDate;
      await tester.pumpAndSettle();
      final lastFirst = DateTime(9999, 12, 32 - days);
      expect(h.windows.last.first, lastFirst);
      expect(h.windows.last.last, calendar.maxDate);
      h.controller.forward!();
      await tester.pumpAndSettle();
      expect(h.coords!.dayWindow!.settledFirstDate, lastFirst);
      h.controller.backward!();
      await tester.pumpAndSettle();
      expect(h.windows.last.first, DateTime(9999, 12, 32 - days * 2));
      h.controller.forward!();
      await tester.pumpAndSettle();
      expect(h.windows.last.last, calendar.maxDate);
      h.controller.displayDate = calendar.minDate;
      await tester.pumpAndSettle();
      expect(h.windows.last.first, calendar.minDate);
      h.controller.backward!();
      await tester.pumpAndSettle();
      expect(h.coords!.dayWindow!.settledFirstDate, calendar.minDate);
      h.controller.forward!();
      await tester.pumpAndSettle();
      expect(h.windows.last.first, DateTime(1, 1, 1 + days));
      h.controller.backward!();
      await tester.pumpAndSettle();
      expect(h.windows.last.first, calendar.minDate);
      expect(tester.takeException(), isNull);
    });
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
        h.controller.forward!();
        await tester.pumpAndSettle();
        final drag = await tester.startGesture(const Offset(300, 400));
        await drag.moveBy(const Offset(-20, 0));
        await tester.pump();
        await drag.moveBy(Offset(-h.column * .8, 0));
        await tester.pump(const Duration(milliseconds: 500));
        await drag.up();
        await tester.pumpAndSettle();
        final browsed = DateTime(2026, 10, 20 + days);
        expect(h.windows.last.first, browsed);
        h.rebuild(() {
          h.key = GlobalKey<SfCalendarTimelineQueryApi>();
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(h.coords!.dayWindow!.settledFirstDate, browsed);
        expect(h.windows.last.first, browsed);
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

  testWidgets('retained all-day lanes refresh at constant panel height', (
    tester,
  ) async {
    final h = await _mount(tester, 3);
    h.data.appointments!.addAll([
      Appointment(
        id: 'departing',
        isAllDay: true,
        startTime: DateTime(2026, 10, 16),
        endTime: DateTime(2026, 10, 16, 23),
      ),
      Appointment(
        id: 'retained-span',
        isAllDay: true,
        startTime: DateTime(2026, 10, 16, 1),
        endTime: DateTime(2026, 10, 22, 23),
      ),
      for (var i = 0; i < 3; i++)
        Appointment(
          id: 'old-rows-$i',
          isAllDay: true,
          startTime: DateTime(2026, 10, 20),
          endTime: DateTime(2026, 10, 20, 23),
        ),
      for (var i = 0; i < 4; i++)
        Appointment(
          id: 'new-rows-$i',
          isAllDay: true,
          startTime: DateTime(2026, 10, 23),
          endTime: DateTime(2026, 10, 23, 23),
        ),
    ]);
    h.data.notifyListeners(
      CalendarDataSourceAction.reset,
      h.data.appointments!,
    );
    await tester.pumpAndSettle();
    final top = h.coords!.viewportTopInBody;
    final drag = await tester.startGesture(const Offset(210, 400));
    await drag.moveBy(const Offset(-20, 0));
    await tester.pump();
    await drag.moveBy(Offset(-h.column * 3.2, 0));
    await tester.pump(const Duration(milliseconds: 300));
    final spanTops =
        tester
            .elementList(find.byKey(const ValueKey('retained-span')))
            .map(
              (e) =>
                  (e.findRenderObject()! as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy,
            )
            .toList();
    final firstRow =
        tester.getTopLeft(find.byKey(const ValueKey('new-rows-0'))).dy;
    expect(h.coords!.viewportTopInBody, top);
    expect(spanTops, isNotEmpty);
    for (final y in spanTops) {
      expect(
        y,
        closeTo(firstRow, .1),
        reason: 'The departed blocker frees row zero on both retained blocks',
      );
    }
    await drag.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final days in [3, 7]) {
    for (final rtl in [false, true]) {
      testWidgets('$days-day expanded panel survives block rotation $rtl', (
        tester,
      ) async {
        final h = await _mount(tester, days, rtl: rtl);
        h.data.appointments!.addAll([
          for (var i = 0; i < 6; i++)
            Appointment(
              id: 'wide-$i',
              isAllDay: true,
              startTime: DateTime(2026, 9),
              endTime: DateTime(2026, 12),
            ),
        ]);
        h.data.notifyListeners(
          CalendarDataSourceAction.reset,
          h.data.appointments!,
        );
        await tester.pumpAndSettle();
        final collapsed = h.coords!.viewportTopInBody;
        await tester.tapAt(Offset(rtl ? 400 : 20, collapsed - 10));
        await tester.pumpAndSettle();
        final expanded = h.coords!.viewportTopInBody;
        expect(expanded, greaterThan(collapsed + 40));
        final drag = await tester.startGesture(const Offset(210, 500));
        await drag.moveBy(const Offset(-20, 0));
        await tester.pump();
        for (final direction in [-1, 1]) {
          await drag.moveBy(Offset(direction * h.column * (days + .2), 0));
          await tester.pump(const Duration(milliseconds: 300));
          expect(h.coords!.viewportTopInBody, closeTo(expanded, .1));
          _checkVisibleEvents(tester, h);
        }
        await drag.cancel();
        await tester.pumpAndSettle();
        expect(h.coords!.viewportTopInBody, closeTo(expanded, .1));
        await tester.tapAt(Offset(rtl ? 400 : 20, expanded - 10));
        await tester.pumpAndSettle();
        expect(h.coords!.viewportTopInBody, closeTo(collapsed, .1));
        expect(tester.takeException(), isNull);
      });
    }
  }

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
  String? timeZone;
  Color background = Colors.white;
  bool rtl = false;
  DateTime? minDate, maxDate;
  double intervalHeight = 60;
  TextStyle? rulerTextStyle;
  int firstDayOfWeek = 1;
  SfCalendarTimelineCoordinates? coords;
  int appointmentBuilds = 0;
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
  String? timeZone,
  DateTime? displayDate,
  DayWindowNavigation policy = DayWindowNavigation.continuous,
}) async {
  tester.view.physicalSize = const Size(420, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final h =
      _Harness(days)
        ..timeZone = timeZone
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
                  initialDisplayDate: displayDate ?? DateTime(2026, 10, 19, 9),
                  headerHeight: 0,
                  viewHeaderHeight: 50,
                  showCurrentTimeIndicator: false,
                  cellEndPadding: 0,
                  preserveTimelineScaleOffset: true,
                  allDayPanelChronologicalSort: true,
                  dataSource: h.data,
                  timeZone: h.timeZone,
                  appointmentBuilder: (context, details) {
                    h.appointmentBuilds++;
                    return ColoredBox(
                      key:
                          details.appointments.length == 1
                              ? ValueKey<String>(
                                (details.appointments.single as Appointment).id!
                                    as String,
                              )
                              : null,
                      color: Colors.blue,
                    );
                  },
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
                    timeTextStyle: h.rulerTextStyle,
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

// SF-22: record picture reuse without reproducing the ruler's rendering logic.
class _RulerPictureCanvas extends Fake implements Canvas {
  final pictures = <ui.Picture>[];
  @override
  void drawPicture(ui.Picture picture) => pictures.add(picture);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// SF-22: count actual render-pipeline paints while retaining the native painter.
class _CountingRulerPainter extends CustomPainter {
  _CountingRulerPainter(this.delegate);
  final CustomPainter delegate;
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    delegate.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
