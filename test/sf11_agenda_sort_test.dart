// [SF-11] Nestify patch unit tests — pure-logic coverage for the shared
// agenda/schedule per-day ordering (`AppointmentHelper.sortAgendaAppointments`).
//
// Regression anchors:
// - Nestify issue #2029 — in the schedule (list) view a multi-day timed
//   appointment's first day must rank BELOW single-day all-day appointments
//   when `allDayFirst` is enabled (its start time is after their midnight
//   anchor).
// - Nestify issue #2031 edge cases C/D — ordering is chronological by the
//   ORIGINAL start instant (Google Calendar list-view rule): an appointment
//   that started on an earlier day ranks above today's all-day appointments;
//   one that started later the same day ranks below them. Day-relative
//   rendering ("Ends X" / banner) never influences the order.
//
// #2031 SCOPE (read before changing the tiebreak): #2031 only governs all-day
// vs spanned-event placement. The `longer span first` (end desc) tiebreak is
// asserted ONLY for equal-instant all-day / spanned pairs (the `allday-spanned`
// > `allday` case in 'full order with allDayFirst'). The end-order of two
// SINGLE-DAY TIMED events sharing a start instant is NOT pinned by #2031 and is
// ordered end ASC by #2227 (earlier-ending first; see the '#2227' test below).

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
      // "a": single-day all-day on Jun 9 (midnight anchor precedes 7AM).
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appt(
          'cd',
          start: _day.add(const Duration(hours: 7)),
          end: _day.add(const Duration(hours: 31)),
          isSpanned: true,
        ),
        _appt('a', start: _day, end: _day, isAllDay: true),
      ];

      AppointmentHelper.sortAgendaAppointments(appointments, allDayFirst: true);

      expect(_subjects(appointments), <String>['a', 'cd']);
    });

    test(
      'allDayFirst=false reproduces upstream order (spanned above all-day)',
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
      },
    );

    test('full order with allDayFirst: chronological by original start; '
        'all-day anchors midnight; longer span first on equal instants', () {
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
        _appt(
          'allday-spanned',
          start: _day,
          end: _day.add(const Duration(days: 2)),
          isAllDay: true,
          isSpanned: true,
        ),
      ];

      AppointmentHelper.sortAgendaAppointments(appointments, allDayFirst: true);

      // Chronological: midnight all-day pair (longer span first) -> 6AM
      // timed -> 7AM spanned timed (spanned-ness no longer jumps the queue)
      // -> 9AM timed.
      // NOTE (#2031 scope): the `allday-spanned` > `allday` pair below is the
      // SOLE assertion of the `longer span first` tiebreak, and it binds only
      // all-day / spanned pairs at an equal instant. Two single-day timed
      // events sharing a start instant are ordered end ASC by #2227 (see the
      // '#2227' test); do not generalize this all-day expectation to timed pairs.
      expect(_subjects(appointments), <String>[
        'allday-spanned',
        'allday',
        'timed-6am',
        'spanned-7am',
        'timed-9am',
      ]);
    });

    test('currentTimeBoundary keeps ended timed rows above ongoing rows', () {
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appt(
          'read',
          start: _day.add(const Duration(hours: 1)),
          end: _day.add(const Duration(hours: 6)),
        ),
        _appt(
          'movie',
          start: _day.add(const Duration(hours: 1)),
          end: _day.add(const Duration(hours: 2)),
        ),
        _appt(
          'wake',
          start: _day.add(const Duration(hours: 6, minutes: 30)),
          end: _day.add(const Duration(hours: 7)),
        ),
        _appt('allday', start: _day, end: _day, isAllDay: true),
      ];

      AppointmentHelper.sortAgendaAppointments(
        appointments,
        allDayFirst: true,
        currentTimeBoundary: _day.add(const Duration(hours: 3, minutes: 59)),
      );

      expect(_subjects(appointments), <String>[
        'allday',
        'movie',
        'read',
        'wake',
      ]);
    });

    test('issue #2031 C.1: ending-day spanned timed ranks above all-day '
        'when it started on an earlier day', () {
      final DateTime nextDay = _day.add(const Duration(days: 1));
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        // "bbb" all-day Jun 10-12 (midnight anchor on Jun 10).
        _appt(
          'bbb',
          start: nextDay,
          end: nextDay.add(const Duration(days: 2)),
          isAllDay: true,
          isSpanned: true,
        ),
        // "cd" timed Jun 9 7AM -> Jun 10 7AM, seen on its ending day Jun 10:
        // its ORIGINAL start (Jun 9 7AM) precedes bbb's Jun 10 midnight.
        _appt(
          'cd',
          start: _day.add(const Duration(hours: 7)),
          end: nextDay.add(const Duration(hours: 7)),
          isSpanned: true,
        ),
      ];

      AppointmentHelper.sortAgendaAppointments(appointments, allDayFirst: true);

      expect(_subjects(appointments), <String>['cd', 'bbb']);
    });

    test('issue #2031 dataset C, Jun 10: earlier-started spanned timed -> '
        'all-day -> later same-day spanned starts in time order', () {
      // Screenshot dataset: xyz timed Jun 8 2AM -> Jun 10 2AM; aaa all-day
      // Jun 10-12; 123 timed Jun 10 6AM -> Jun 12 6AM; abc timed
      // Jun 10 10AM -> Jun 14 10AM. Expected (Google): xyz, aaa, 123, abc.
      final DateTime jun8 = DateTime(2026, 6, 8);
      final DateTime jun10 = DateTime(2026, 6, 10);
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appt(
          'aaa',
          start: jun10,
          end: jun10.add(const Duration(days: 2)),
          isAllDay: true,
          isSpanned: true,
        ),
        _appt(
          '123',
          start: jun10.add(const Duration(hours: 6)),
          end: jun10.add(const Duration(hours: 54)),
          isSpanned: true,
        ),
        _appt(
          'abc',
          start: jun10.add(const Duration(hours: 10)),
          end: jun10.add(const Duration(hours: 106)),
          isSpanned: true,
        ),
        _appt(
          'xyz',
          start: jun8.add(const Duration(hours: 2)),
          end: jun10.add(const Duration(hours: 2)),
          isSpanned: true,
        ),
      ];

      AppointmentHelper.sortAgendaAppointments(appointments, allDayFirst: true);

      expect(_subjects(appointments), <String>['xyz', 'aaa', '123', 'abc']);
    });

    test('issue #2031 dataset C, Jun 12: an "Until X" ending day does NOT '
        'always rank first — chronological start order decides', () {
      // On Jun 12: aaa (all-day, anchored Jun 10 midnight) precedes 123
      // (timed, started Jun 10 6AM, ending Jun 12 6AM) — matches the Google
      // reference screenshot: aaa -> 123 "Until 6am" -> abc.
      final DateTime jun10 = DateTime(2026, 6, 10);
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appt(
          '123',
          start: jun10.add(const Duration(hours: 6)),
          end: jun10.add(const Duration(hours: 54)),
          isSpanned: true,
        ),
        _appt(
          'abc',
          start: jun10.add(const Duration(hours: 10)),
          end: jun10.add(const Duration(hours: 106)),
          isSpanned: true,
        ),
        _appt(
          'aaa',
          start: jun10,
          end: jun10.add(const Duration(days: 2)),
          isAllDay: true,
          isSpanned: true,
        ),
      ];

      AppointmentHelper.sortAgendaAppointments(appointments, allDayFirst: true);

      expect(_subjects(appointments), <String>['aaa', '123', 'abc']);
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

      AppointmentHelper.sortAgendaAppointments(appointments, allDayFirst: true);

      expect(_subjects(appointments), <String>[
        'allday-1',
        'allday-2',
        'timed-1',
        'timed-2',
      ]);
    });

    test('ties keep input order beyond 32 items (no insertion-sort '
        'dependence)', () {
      // 40 identical-key appointments: Dart switches List.sort to an
      // unstable dual-pivot quicksort above 32 elements — the explicit
      // original-index tiebreak must keep input order anyway.
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        for (int i = 0; i < 40; i++)
          _appt(
            'timed-$i',
            start: _day.add(const Duration(hours: 9)),
            end: _day.add(const Duration(hours: 10)),
          ),
      ];

      AppointmentHelper.sortAgendaAppointments(appointments, allDayFirst: true);

      expect(_subjects(appointments), <String>[
        for (int i = 0; i < 40; i++) 'timed-$i',
      ]);
    });

    test('issue #2227: equal-start single-day timed events order by end '
        'ASC (earlier-ending first)', () {
      // dacheng's aa/bb/dd case: bb (8AM-10PM) and dd (8AM-8PM) share an 8AM
      // start instant; dd finishes first so it ranks ABOVE bb. #2031 only pins
      // longer-span-first for all-day / spanned banner pairs ('full order with
      // allDayFirst'); single-day timed pairs flip to end ASC here.
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appt(
          'bb',
          start: _day.add(const Duration(hours: 8)),
          end: _day.add(const Duration(hours: 22)),
        ),
        _appt(
          'dd',
          start: _day.add(const Duration(hours: 8)),
          end: _day.add(const Duration(hours: 20)),
        ),
      ];

      AppointmentHelper.sortAgendaAppointments(appointments, allDayFirst: true);

      expect(_subjects(appointments), <String>['dd', 'bb']);
    });

    test('issue #2227: end ASC does not disturb all-day longer-span-first '
        'at the same instant', () {
      // Regression guard for the #2031 boundary: all-day banner pairs keep
      // longer-span-first even though single-day timed pairs flipped to ASC.
      final List<CalendarAppointment> appointments = <CalendarAppointment>[
        _appt(
          'allday-short',
          start: _day,
          end: _day.add(const Duration(days: 1)),
          isAllDay: true,
        ),
        _appt(
          'allday-long',
          start: _day,
          end: _day.add(const Duration(days: 3)),
          isAllDay: true,
          isSpanned: true,
        ),
      ];

      AppointmentHelper.sortAgendaAppointments(appointments, allDayFirst: true);

      expect(_subjects(appointments), <String>['allday-long', 'allday-short']);
    });
  });
}
