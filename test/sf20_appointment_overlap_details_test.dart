// SF-20 Nestify patch regression coverage for appointmentBuilder overlap
// metadata. The builder must observe the same occurrence-level collision
// result that the day-view lane allocator used.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

final DateTime _masterDay = DateTime(2026, 6, 9);
final DateTime _occurrenceDay = DateTime(2026, 6, 16);

DateTime _on(DateTime day, int hour, [int minute = 0]) =>
    DateTime(day.year, day.month, day.day, hour, minute);

class _AppointmentDataSource extends CalendarDataSource<Appointment> {
  _AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}

void main() {
  testWidgets(
    'SF-20 appointmentBuilder reports recurring occurrence overlap from '
    'the finalized day layout',
    (WidgetTester tester) async {
      final Map<String, bool> overlapBySubject = <String, bool>{};
      final List<Appointment> source = <Appointment>[
        Appointment(
          startTime: _on(_masterDay, 9),
          endTime: _on(_masterDay, 10),
          subject: 'weekly sync',
          recurrenceRule: 'FREQ=WEEKLY;BYDAY=TU;INTERVAL=1;COUNT=2',
        ),
        Appointment(
          startTime: _on(_occurrenceDay, 9, 30),
          endTime: _on(_occurrenceDay, 10, 30),
          subject: 'one-off',
        ),
        Appointment(
          startTime: _on(_occurrenceDay, 12),
          endTime: _on(_occurrenceDay, 13),
          subject: 'separate',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 800,
            height: 800,
            child: SfCalendar(
              initialDisplayDate: _occurrenceDay,
              dataSource: _AppointmentDataSource(source),
              appointmentBuilder: (
                BuildContext context,
                CalendarAppointmentDetails details,
              ) {
                final Appointment appointment =
                    details.appointments.single as Appointment;
                overlapBySubject[appointment.subject] = details.isOverlapping;
                return const ColoredBox(color: Colors.lightBlue);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(overlapBySubject, <String, bool>{
        'weekly sync': true,
        'one-off': true,
        'separate': false,
      });
    },
  );
}
