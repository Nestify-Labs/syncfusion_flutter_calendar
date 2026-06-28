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

CalendarAppointment _appointment({
  required DateTime start,
  required DateTime end,
  bool isAllDay = false,
  bool isSpanned = false,
}) {
  return CalendarAppointment(
    startTime: start,
    endTime: end,
    isAllDay: isAllDay,
    isSpanned: isSpanned,
  );
}

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(_day.year, _day.month, _day.day, hour, minute);

void main() {
  group('SF-10 scheduleCurrentTimeIndicatorY', () {
    test('ongoing timed event keeps the line above it (issue #2031 repro)', () {
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

    test('equal-start ended event stays above the ongoing row boundary', () {
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appointment(start: _at(1), end: _at(6)),
        _appointment(start: _at(1), end: _at(2)),
        _appointment(start: _at(6, 30), end: _at(7)),
      ];

      expect(
        scheduleCurrentTimeIndicatorYForAppointments(
          appointments,
          _at(3, 59),
          agendaItemHeight: 70,
          agendaAllDayItemHeight: 50,
          isLargerScheduleUI: true,
          allDayFirst: true,
        ),
        80,
      );
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

    test(
      'spanned event continuing from a previous day is skipped like all-day',
      () {
        // A multi-day event whose start day is NOT today renders as a banner
        // ("Day N/M" / "Until …") and must not anchor the line.
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
      },
    );

    test('multi-day event starting today anchors the line on its first day '
        '(issue #2031 multi-day edge case)', () {
      // Repro: now 4:31, multi-day "abc" starts today 10 AM and ends 3 days
      // later. Its first-day segment shows "10 AM" and must anchor the line
      // ABOVE it (event not yet started), matching Google Calendar list view —
      // not below it (the pre-fix behavior put the line at the bottom).
      final List<AppointmentView> views = <AppointmentView>[
        _view(
          start: _at(0),
          end: _at(23, 59),
          isAllDay: true,
          top: 0,
          bottom: 50,
        ), // xxx: all-day banner
        _view(
          start: _at(10), // today 10 AM
          end: _day.add(const Duration(days: 3, hours: 10)), // +3d 10 AM
          isSpanned: true,
          top: 55,
          bottom: 125,
        ), // abc Day 1/4
      ];

      expect(scheduleCurrentTimeIndicatorY(views, _at(4, 31)), 55);
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

  group('SF-10 with SF-11 chronological layout (issue #2031 dataset C)', () {
    // Dataset C laid out in the SF-11 chronological order on Jun 10:
    // xyz (timed Jun 8 2AM -> Jun 10 2AM, ending-day "Ends 2 AM" banner) ->
    // aaa (all-day Jun 10-12) -> 123 (timed Jun 10 6AM -> Jun 12 6AM,
    // start-day segment) -> abc (timed Jun 10 10AM -> Jun 14 10AM,
    // start-day segment).
    final DateTime jun8 = DateTime(2026, 6, 8);
    final DateTime jun10 = DateTime(2026, 6, 10);

    List<AppointmentView> datasetC() => <AppointmentView>[
      _view(
        start: jun8.add(const Duration(hours: 2)),
        end: jun10.add(const Duration(hours: 2)),
        isSpanned: true,
        top: 0,
        bottom: 50,
      ), // xyz: "Ends 2 AM" banner row at the very top
      _view(
        start: jun10,
        end: jun10.add(const Duration(days: 2)),
        isAllDay: true,
        isSpanned: true,
        top: 55,
        bottom: 105,
      ), // aaa: all-day banner
      _view(
        start: jun10.add(const Duration(hours: 6)),
        end: jun10.add(const Duration(hours: 54)),
        isSpanned: true,
        top: 110,
        bottom: 180,
      ), // 123: start-day segment, shows "6 AM"
      _view(
        start: jun10.add(const Duration(hours: 10)),
        end: jun10.add(const Duration(hours: 106)),
        isSpanned: true,
        top: 185,
        bottom: 255,
      ), // abc: start-day segment, shows "10 AM"
    ];

    test('7:57 — line above the ongoing start-day segment "123", below the '
        'banner block (matches the Google reference screenshot)', () {
      expect(
        scheduleCurrentTimeIndicatorY(
          datasetC(),
          jun10.add(const Duration(hours: 7, minutes: 57)),
        ),
        110, // top of 123
      );
    });

    test('1:00 AM — the ongoing "Until 2 AM" ending-day row stays '
        'un-anchorable (banner): the line anchors on the first start-day '
        'timed segment instead of jumping above the top row '
        '(empirically verified against Google Calendar agenda 2026-06-10: '
        'with an ongoing "Until 11:40 PM" row at the top, Google draws the '
        'line below the banner block, above the first start-day segment)', () {
      expect(
        scheduleCurrentTimeIndicatorY(
          datasetC(),
          jun10.add(const Duration(hours: 1)),
        ),
        110, // top of 123 — NOT 0 (above xyz)
      );
    });

    test('day with only banners (all-day + non-start-day segments) -> line '
        'falls to the bottom of the last banner row', () {
      final List<AppointmentView> views = <AppointmentView>[
        _view(
          start: jun8.add(const Duration(hours: 2)),
          end: jun10.add(const Duration(hours: 2)),
          isSpanned: true,
          top: 0,
          bottom: 50,
        ), // xyz ending-day banner
        _view(
          start: jun10,
          end: jun10.add(const Duration(days: 2)),
          isAllDay: true,
          isSpanned: true,
          top: 55,
          bottom: 105,
        ), // aaa all-day banner
      ];

      expect(
        scheduleCurrentTimeIndicatorY(
          views,
          jun10.add(const Duration(hours: 1)),
        ),
        105, // bottom of the last banner
      );
    });
  });

  group('SF-14 scheduleCurrentTimeIndicatorYForAppointments', () {
    test('matches schedule row-height math for all-day and timed rows', () {
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appointment(start: _at(0), end: _at(23, 59), isAllDay: true),
        _appointment(start: _at(7), end: _at(8)),
        _appointment(start: _at(18), end: _at(19)),
      ];

      expect(
        scheduleCurrentTimeIndicatorYForAppointments(
          appointments,
          _at(7, 30),
          agendaItemHeight: 70,
          agendaAllDayItemHeight: 50,
          isLargerScheduleUI: false,
          allDayFirst: true,
        ),
        60, // 5px top padding + 50px all-day row + 5px gap
      );
    });

    test('web schedule uses regular item height for all-day rows', () {
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appointment(start: _at(0), end: _at(23, 59), isAllDay: true),
        _appointment(start: _at(7), end: _at(8)),
      ];

      expect(
        scheduleCurrentTimeIndicatorYForAppointments(
          appointments,
          _at(7, 30),
          agendaItemHeight: 70,
          agendaAllDayItemHeight: 50,
          isLargerScheduleUI: true,
          allDayFirst: true,
        ),
        80, // 5px top padding + 70px all-day row + 5px gap
      );
    });
  });
}
