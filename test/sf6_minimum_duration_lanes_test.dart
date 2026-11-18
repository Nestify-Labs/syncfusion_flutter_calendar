// SF-6 (#4538): lane expansion must honor the same minimum duration as the
// allocator, including an instant overlapping an overnight fragment at midnight.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class _Source extends CalendarDataSource<Appointment> {
  _Source(List<Appointment> source) {
    appointments = source;
  }
}

void main() {
  for (final mode in AppointmentOverlapMode.values) {
    for (final days in [1, 3]) {
      for (final minimum in <Duration?>[
        null,
        const Duration(minutes: 1),
        const Duration(minutes: 30),
      ]) {
        for (final reversed in [false, true]) {
          testWidgets('SF-6 midnight lanes and taps mode=$mode days=$days '
              'minimum=$minimum reversed=$reversed', (tester) async {
            final day = DateTime(2030, 1, 15);
            final shortEnd =
                minimum == null ? day.add(const Duration(minutes: 1)) : day;
            final source = [
              Appointment(
                id: 'cross',
                subject: 'Cross',
                startTime: day.subtract(const Duration(minutes: 30)),
                endTime: day.add(const Duration(minutes: 30)),
              ),
              Appointment(
                id: 'short',
                subject: 'Short',
                startTime: day,
                endTime: shortEnd,
              ),
              Appointment(
                id: 'next',
                subject: 'Next',
                startTime: day.add(const Duration(minutes: 30)),
                endTime: day.add(const Duration(hours: 1)),
              ),
            ];
            final bounds = <String, Rect>{};
            final opened = <String>[];
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: SfCalendar(
                    initialDisplayDate: day,
                    appointmentOverlapMode: mode,
                    dataSource: _Source(
                      reversed ? source.reversed.toList() : source,
                    ),
                    timeSlotViewSettings: TimeSlotViewSettings(
                      numberOfDaysInView: days,
                      timeIntervalHeight: 120,
                      minimumAppointmentDuration: minimum,
                    ),
                    appointmentBuilder: (context, details) {
                      final item = details.appointments.single as Appointment;
                      bounds[item.id! as String] = details.bounds;
                      return ColoredBox(
                        key: ValueKey<String>(item.id! as String),
                        color: Colors.green,
                      );
                    },
                    onTap: (details) {
                      if (details.targetElement ==
                          CalendarElement.appointment) {
                        opened.add(
                          (details.appointments!.single as Appointment).id!
                              as String,
                        );
                      }
                    },
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final cross = bounds['cross']!;
            final short = bounds['short']!;
            expect(cross.overlaps(short), isFalse);
            expect(cross.width, greaterThan(0));
            expect(short.width, closeTo(cross.width, 0.01));
            expect(bounds['next']!.width, greaterThan(short.width * 1.9));
            for (final id in ['short', 'cross']) {
              await tester.tap(find.byKey(ValueKey(id)));
              await tester.pump();
              expect(opened.last, id);
            }
            expect(source[1].startTime, day);
            expect(source[1].endTime, shortEnd);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }
    }
  }
}
