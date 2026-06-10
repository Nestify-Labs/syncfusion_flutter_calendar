// [SF-11] Nestify patch unit tests — pure-logic coverage for the shared
// agenda/schedule per-day ordering (`AppointmentHelper.sortAgendaAppointments`).
//
// Regression anchor: Nestify issue #2029 — in the schedule (list) view a
// multi-day timed appointment's first day must rank BELOW single-day all-day
// appointments when `allDayFirst` is enabled. Upstream applies `isSpanned`
// as the final (highest priority) sort key, which placed the spanned timed
// appointment above the all-day one.

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/appointment_engine/appointment_helper.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/common/calendar_view_helper.dart';

/// 2026-06-09 is a Tuesday — mirrors the repro screenshots in issue #2029.
final DateTime _day = DateTime(2026, 6, 9);

CalendarAppointment _appt(
  String subject, {
  required DateTime start,
  required DateTime end,
  bool isAllDay = false,
  bool isSpanned = false,
}) {
  return CalendarAppointment(
    subject: subject,
    startTime: start,
    endTime: end,
    isAllDay: isAllDay,
    isSpanned: isSpanned,
  );
}

List<String> _subjects(List<CalendarAppointment> appointments) =>
    appointments.map((CalendarAppointment a) => a.subject).toList();

void main() {
  group('SF-11 sortAgendaAppointments', () {
    test('issue #2029 repro: all-day ranks above spanned timed first day '
        'when allDayFirst is true', () {
      // "cd": timed multi-day, Jun 9 7AM -> Jun 10 7AM (spanned).
      // "a": single-day all-day on Jun 9.
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appt(
          'cd',
          start: _day.add(const Duration(hours: 7)),
          end: _day.add(const Duration(hours: 31)),
          isSpanned: true,
        ),
        _appt('a', start: _day, end: _day, isAllDay: true),
      ];

      AppointmentHelper.sortAgendaAppointments(
        appointments,
        allDayFirst: true,
      );

      expect(_subjects(appointments), <String>['a', 'cd']);
    });

    test('allDayFirst=false reproduces upstream order (spanned above all-day)',
        () {
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appt('a', start: _day, end: _day, isAllDay: true),
        _appt(
          'cd',
          start: _day.add(const Duration(hours: 7)),
          end: _day.add(const Duration(hours: 31)),
          isSpanned: true,
        ),
      ];

      AppointmentHelper.sortAgendaAppointments(
        appointments,
        allDayFirst: false,
      );

      expect(_subjects(appointments), <String>['cd', 'a']);
    });

    test('full order with allDayFirst: all-day -> spanned timed -> timed by '
        'start time', () {
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appt(
          'timed-9am',
          start: _day.add(const Duration(hours: 9)),
          end: _day.add(const Duration(hours: 10)),
        ),
        _appt(
          'spanned-7am',
          start: _day.add(const Duration(hours: 7)),
          end: _day.add(const Duration(hours: 31)),
          isSpanned: true,
        ),
        _appt(
          'timed-6am',
          start: _day.add(const Duration(hours: 6)),
          end: _day.add(const Duration(hours: 7)),
        ),
        _appt('allday', start: _day, end: _day, isAllDay: true),
        // Multi-day all-day (e.g. "bbb" spanning Jun 10-12 in the issue
        // screenshots, seen on its continuation day).
        _appt(
          'allday-spanned',
          start: _day,
          end: _day.add(const Duration(days: 2)),
          isAllDay: true,
          isSpanned: true,
        ),
      ];

      AppointmentHelper.sortAgendaAppointments(
        appointments,
        allDayFirst: true,
      );

      expect(_subjects(appointments), <String>[
        'allday-spanned',
        'allday',
        'spanned-7am',
        'timed-6am',
        'timed-9am',
      ]);
    });

    test('continuation day: all-day spanned still ranks above timed spanned '
        '(matches pre-patch screenshot order on Jun 10)', () {
      final DateTime nextDay = _day.add(const Duration(days: 1));
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        // "cd" ending 7AM on Jun 10.
        _appt(
          'cd',
          start: _day.add(const Duration(hours: 7)),
          end: nextDay.add(const Duration(hours: 7)),
          isSpanned: true,
        ),
        // "bbb" all-day Jun 10-12.
        _appt(
          'bbb',
          start: nextDay,
          end: nextDay.add(const Duration(days: 2)),
          isAllDay: true,
          isSpanned: true,
        ),
      ];

      AppointmentHelper.sortAgendaAppointments(
        appointments,
        allDayFirst: true,
      );

      expect(_subjects(appointments), <String>['bbb', 'cd']);
    });

    test('ties keep input order (stable for small day lists)', () {
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appt('allday-1', start: _day, end: _day, isAllDay: true),
        _appt('allday-2', start: _day, end: _day, isAllDay: true),
        _appt(
          'timed-1',
          start: _day.add(const Duration(hours: 9)),
          end: _day.add(const Duration(hours: 10)),
        ),
        _appt(
          'timed-2',
          start: _day.add(const Duration(hours: 9)),
          end: _day.add(const Duration(hours: 10)),
        ),
      ];

      AppointmentHelper.sortAgendaAppointments(
        appointments,
        allDayFirst: true,
      );

      expect(_subjects(appointments), <String>[
        'allday-1',
        'allday-2',
        'timed-1',
        'timed-2',
      ]);
    });
  });
}
