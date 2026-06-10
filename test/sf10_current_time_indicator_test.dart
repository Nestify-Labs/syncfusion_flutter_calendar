// [SF-10] Nestify patch unit tests — pure-logic coverage for the schedule
// (agenda/list) view current-time indicator Y-position decision
// (`scheduleCurrentTimeIndicatorY`). Paint-level coverage (color gating,
// selectedDate == today) stays in the host repo's manual verification since
// it requires a full SfCalendar widget tree.
//
// Regression anchor: Nestify issue #2031 — the line must treat an ongoing
// timed event (start <= now < end) as "current" (line above it), not as
// "past" (line below it). Google Calendar list view is the reference.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_layout/agenda_view_layout.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/common/calendar_view_helper.dart';

/// 2026-06-09 is a Tuesday — mirrors the repro screenshots in issue #2031.
final DateTime _day = DateTime(2026, 6, 9);

AppointmentView _view({
  required DateTime start,
  required DateTime end,
  bool isAllDay = false,
  bool isSpanned = false,
  required double top,
  required double bottom,
}) {
  return AppointmentView()
    ..appointment = CalendarAppointment(
      startTime: start,
      endTime: end,
      isAllDay: isAllDay,
      isSpanned: isSpanned,
    )
    ..appointmentRect = RRect.fromLTRBR(
      0,
      top,
      300,
      bottom,
      const Radius.circular(4),
    );
}

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(_day.year, _day.month, _day.day, hour, minute);

void main() {
  group('SF-10 scheduleCurrentTimeIndicatorY', () {
    test('ongoing timed event keeps the line above it (issue #2031 repro)',
        () {
      // 7:48 — "ccc" (7–8 AM) has started but not ended. The line must sit
      // at ccc's top edge, not below it.
      final List<AppointmentView> views = <AppointmentView>[
        _view(start: _at(6), end: _at(7), top: 0, bottom: 70), // e: ended
        _view(start: _at(7), end: _at(8), top: 75, bottom: 145), // ccc: ongoing
        _view(start: _at(18), end: _at(19), top: 150, bottom: 220), // ddd
      ];

      expect(
        scheduleCurrentTimeIndicatorY(views, _at(7, 48)),
        75, // top of ccc
      );
    });

    test('line sits above the first not-yet-started event', () {
      final List<AppointmentView> views = <AppointmentView>[
        _view(start: _at(6), end: _at(7), top: 0, bottom: 70),
        _view(start: _at(18), end: _at(19), top: 75, bottom: 145),
      ];

      expect(scheduleCurrentTimeIndicatorY(views, _at(9)), 75);
    });

    test('all timed events ended -> line below the last event', () {
      final List<AppointmentView> views = <AppointmentView>[
        _view(start: _at(6), end: _at(7), top: 0, bottom: 70),
        _view(start: _at(7), end: _at(8), top: 75, bottom: 145),
      ];

      expect(scheduleCurrentTimeIndicatorY(views, _at(20)), 145);
    });

    test('all-day events never anchor the line above them', () {
      // Google reference: at 7:48 the line is below the all-day row and
      // above the ongoing 7–8 AM event.
      final List<AppointmentView> views = <AppointmentView>[
        _view(
          start: _at(0),
          end: _at(23, 59),
          isAllDay: true,
          top: 0,
          bottom: 50,
        ),
        _view(start: _at(7), end: _at(8), top: 55, bottom: 125),
      ];

      expect(scheduleCurrentTimeIndicatorY(views, _at(7, 48)), 55);
    });

    test('spanned (multi-day) events are skipped like all-day', () {
      final List<AppointmentView> views = <AppointmentView>[
        _view(
          start: _day.subtract(const Duration(hours: 1)), // yesterday 23:00
          end: _at(1),
          top: 0,
          bottom: 50,
        ),
        _view(start: _at(7), end: _at(8), top: 55, bottom: 125),
      ];

      expect(scheduleCurrentTimeIndicatorY(views, _at(7, 48)), 55);
    });

    test('only all-day events -> line below the last one', () {
      final List<AppointmentView> views = <AppointmentView>[
        _view(
          start: _at(0),
          end: _at(23, 59),
          isAllDay: true,
          top: 0,
          bottom: 50,
        ),
      ];

      expect(scheduleCurrentTimeIndicatorY(views, _at(7, 48)), 50);
    });

    test('empty collection -> no line', () {
      expect(scheduleCurrentTimeIndicatorY(<AppointmentView>[], _at(8)), null);
    });

    test('views without appointment or rect are ignored', () {
      final List<AppointmentView> views = <AppointmentView>[
        AppointmentView(), // appointment == null
        _view(start: _at(7), end: _at(8), top: 55, bottom: 125),
      ];

      expect(scheduleCurrentTimeIndicatorY(views, _at(7, 48)), 55);
    });
  });
}
