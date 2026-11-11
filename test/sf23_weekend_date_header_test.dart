import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

void main() {
  testWidgets(
    'Schedule paints weekend header colors and clears them on toggle',
    (tester) async {
      final today = DateTime.now();
      final saturday = DateTime(
        today.year,
        today.month,
        today.day +
            (DateTime.saturday - today.weekday) % DateTime.daysPerWeek +
            7,
      );
      final boundaryKey = GlobalKey();
      final data =
          _AppointmentDataSource()
            ..appointments = [
              Appointment(
                startTime: saturday.add(const Duration(hours: 10)),
                endTime: saturday.add(const Duration(hours: 11)),
                subject: 'Saturday event',
                color: Colors.blue,
              ),
            ];

      Future<Set<int>> render(DayHeaderSettings settings) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                key: boundaryKey,
                child: SfCalendar(
                  view: CalendarView.schedule,
                  initialDisplayDate: saturday,
                  dataSource: data,
                  appointmentBuilder:
                      (context, details) => Text(
                        (details.appointments.single as Appointment).subject,
                      ),
                  scheduleViewSettings: ScheduleViewSettings(
                    dayHeaderSettings: settings,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Saturday event'), findsOneWidget);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final colors = await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final pixels = (await image.toByteData())!;
            final colors = <int>{};
            for (var y = 0; y < image.height; y++) {
              for (var x = 0; x < 50; x++) {
                colors.add(pixels.getUint32((y * image.width + x) * 4));
              }
            }
            return colors;
          } finally {
            image.dispose();
          }
        });
        return colors!;
      }

      const dayColor = Color(0xFFFA1372);
      const dateColor = Color(0xFF13845B);
      const expectedColors = [0xFA1372FF, 0x13845BFF];
      final standard = await render(const DayHeaderSettings());
      expect(standard.intersection(expectedColors.toSet()), isEmpty);
      final shaded = await render(
        const DayHeaderSettings(
          weekendDayTextColor: dayColor,
          weekendDateTextColor: dateColor,
        ),
      );
      expect(shaded, containsAll(expectedColors));
      final restored = await render(const DayHeaderSettings());
      expect(restored, standard);
    },
  );
}

class _AppointmentDataSource extends CalendarDataSource<Appointment> {}
