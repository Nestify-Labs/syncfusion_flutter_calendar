// SF-22: standalone preview for native acceptance; no account or backend access.
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

void main() => runApp(const DayWindowSpike());

/// Run from the isolated Flutter wrapper documented in PATCHES.md.
class DayWindowSpike extends StatelessWidget {
  const DayWindowSpike({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Calendar continuous-window preview',
    theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
    home: const _Preview(),
  );
}

class _Preview extends StatefulWidget {
  const _Preview();

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final CalendarController _controller = CalendarController();
  final ValueNotifier<SfCalendarTimelineCoordinates?> _coordinates =
      ValueNotifier(null);
  final DateTime _anchor = DateUtils.dateOnly(DateTime.now());
  late final _PreviewSource _source = _PreviewSource(_anchor);
  int _days = 3;
  double _hourHeight = 70;
  List<DateTime> _settled = const [];

  @override
  void dispose() {
    _controller.dispose();
    _coordinates.dispose();
    super.dispose();
  }

  String _date(DateTime date) => '${date.month}/${date.day}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calendar 连续滑动预览')),
    body: SafeArea(
      child: Column(
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 3, label: Text('三天')),
                  ButtonSegment(value: 7, label: Text('七天')),
                ],
                selected: {_days},
                onSelectionChanged:
                    (value) => setState(() {
                      _days = value.single;
                      _controller.view =
                          _days == 3 ? CalendarView.day : CalendarView.week;
                    }),
              ),
              IconButton(
                tooltip: '上一窗口',
                onPressed: () => _controller.backward?.call(),
                icon: const Icon(Icons.chevron_left),
              ),
              TextButton(
                onPressed: () => _controller.displayDate = _anchor,
                child: const Text('今天'),
              ),
              IconButton(
                tooltip: '下一窗口',
                onPressed: () => _controller.forward?.call(),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Text(
            _settled.isEmpty
                ? '加载日期…'
                : '停稳窗口：${_date(_settled.first)}–${_date(_settled.last)}',
          ),
          Expanded(
            child: SfCalendar(
              controller: _controller,
              view: _days == 3 ? CalendarView.day : CalendarView.week,
              dayWindowNavigation: DayWindowNavigation.continuous,
              initialDisplayDate: _anchor.add(const Duration(hours: 9)),
              firstDayOfWeek: _anchor.weekday,
              headerHeight: 0,
              dataSource: _source,
              allowDragAndDrop: true,
              deferAppointmentDragOnLongPress: true,
              allDayPanelChronologicalSort: true,
              timeSlotViewSettings: TimeSlotViewSettings(
                numberOfDaysInView: _days == 3 ? 3 : -1,
                timeRulerSize: 48,
                timeIntervalHeight: _hourHeight,
              ),
              onViewChanged: (details) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _settled = details.visibleDates);
                  }
                });
              },
              onTimelineCoordinatesChanged:
                  (value) => _coordinates.value = value,
              onTap: (details) {
                final appointments = details.appointments;
                if (appointments == null || appointments.isEmpty) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text((appointments.first as Appointment).subject),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              const Text('时段高度'),
              Expanded(
                child: Slider(
                  value: _hourHeight,
                  min: 50,
                  max: 130,
                  onChanged: (value) => setState(() => _hourHeight = value),
                ),
              ),
              TextButton(
                onPressed:
                    () => _source.addAt(
                      _settled.isEmpty ? _anchor : _settled.last,
                    ),
                child: const Text('添加全天事件'),
              ),
            ],
          ),
          ValueListenableBuilder<SfCalendarTimelineCoordinates?>(
            valueListenable: _coordinates,
            builder:
                (_, value, _) => Text(
                  '预览数据 · ${value?.dayWindow?.phase.name ?? "idle"}'
                  ' · 缓冲 ${value?.dayWindow?.renderedDates.length ?? 0} 天',
                ),
          ),
        ],
      ),
    ),
  );
}

class _PreviewSource extends CalendarDataSource {
  _PreviewSource(DateTime anchor) {
    appointments = <Appointment>[
      for (int day = -90; day <= 90; day++)
        for (int event = 0; event < 3; event++)
          Appointment(
            id: '$day-$event',
            startTime: DateTime(
              anchor.year,
              anchor.month,
              anchor.day + day,
              9 + event * 3,
            ),
            endTime: DateTime(
              anchor.year,
              anchor.month,
              anchor.day + day,
              10 + event * 3,
            ),
            subject: _subject(anchor, day, event),
            color: [Colors.blue, Colors.teal, Colors.deepOrange][event],
          ),
      for (int row = 0; row < 5; row++)
        Appointment(
          id: 'all-$row',
          isAllDay: true,
          startTime: DateTime(anchor.year, anchor.month, anchor.day + 1),
          endTime: DateTime(anchor.year, anchor.month, anchor.day + 4, 23),
          subject: '跨日事件 ${row + 1}',
          color: Colors.indigo,
        ),
    ];
  }

  static String _subject(DateTime anchor, int day, int event) {
    final date = DateTime(anchor.year, anchor.month, anchor.day + day);
    return '${date.month}/${date.day} · 事件 ${event + 1}';
  }

  void addAt(DateTime date) {
    final appointment = Appointment(
      id: 'added-${appointments!.length}',
      isAllDay: true,
      startTime: date,
      endTime: DateTime(date.year, date.month, date.day, 23),
      subject: '新增全天事件',
      color: Colors.purple,
    );
    appointments!.add(appointment);
    notifyListeners(CalendarDataSourceAction.add, [appointment]);
  }
}
