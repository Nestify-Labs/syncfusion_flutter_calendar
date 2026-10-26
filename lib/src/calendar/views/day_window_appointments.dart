// SF-22: independent, bounded all-day layout for each continuous date block.
part of 'calendar_view.dart';

class _DayWindowAppointments {
  _DayWindowAppointments(
    List<DateTime> dates,
    List<CalendarAppointment> appointments,
    SfCalendar calendar, {
    _DayWindowAppointments? sharedLayout,
    List<CalendarAppointment>? expandedAppointments,
  }) {
    // SF-22: the shared buffer already expanded recurrence and split overnight
    // events. Re-project those instances without repeating either operation.
    if (expandedAppointments != null) {
      visible = expandedAppointments;
    } else if (sharedLayout == null) {
      visible = AppointmentHelper.getVisibleAppointments(
        dates.first,
        dates.last,
        appointments,
        calendar.timeZone,
        false,
      );
    } else {
      final DateTime start = AppointmentHelper.convertToStartTime(dates.first);
      final DateTime end = AppointmentHelper.convertToEndTime(dates.last);
      visible =
          sharedLayout.visible.where((CalendarAppointment appointment) {
            return AppointmentHelper.isAppointmentWithinVisibleDateRange(
              appointment,
              start,
              end,
            );
          }).toList();
    }
    for (final CalendarAppointment appointment in visible) {
      if (!appointment.isAllDay &&
          AppointmentHelper.getDifference(
                appointment.actualStartTime,
                appointment.actualEndTime,
              ).inDays ==
              0)
        continue;
      final int start = DateTimeHelper.getIndex(
        dates,
        appointment.actualStartTime,
      );
      final int end =
          DateTimeHelper.getIndex(dates, appointment.actualEndTime) + 1;
      if (start == -1 && end == 0) {
        continue;
      }
      views.add(
        AppointmentView()
          ..appointment = appointment
          ..canReuse = false
          ..startIndex = start
          ..endIndex = end,
      );
    }
    if (calendar.allDayPanelChronologicalSort) {
      AppointmentHelper.sortAllDayPanelChronologically(views);
    } else {
      // Preserve the native panel's duration/start-index ordering.
      views.sort(
        (AppointmentView a, AppointmentView b) =>
            AppointmentHelper.getDifference(
                      b.appointment!.startTime,
                      b.appointment!.endTime,
                    ) >
                    AppointmentHelper.getDifference(
                      a.appointment!.startTime,
                      a.appointment!.endTime,
                    )
                ? 1
                : 0,
      );
      views.sort(
        (AppointmentView a, AppointmentView b) =>
            a.startIndex.compareTo(b.startIndex),
      );
    }
    if (sharedLayout != null) {
      for (final AppointmentView view in views) {
        final CalendarAppointment appointment = view.appointment!;
        final AppointmentView lane = sharedLayout.views.firstWhere((
          AppointmentView candidate,
        ) {
          final CalendarAppointment other = candidate.appointment!;
          return (identical(appointment.data, other.data) ||
                  (appointment.id != null && appointment.id == other.id)) &&
              appointment.actualStartTime == other.actualStartTime &&
              appointment.actualEndTime == other.actualEndTime;
        });
        view.position = lane.position;
        view.maxPositions = lane.maxPositions;
      }
      return;
    }
    for (int day = 0; day < dates.length; day++) {
      final List<AppointmentView> overlap =
          views
              .where(
                (AppointmentView v) =>
                    v.startIndex <= day && v.endIndex >= day + 1,
              )
              .toList();
      for (final AppointmentView view in overlap) {
        if (view.position != -1) {
          continue;
        }
        view.position = 0;
        while (overlap.any(
          (AppointmentView other) =>
              !identical(view, other) && other.position == view.position,
        )) {
          view.position++;
        }
      }
      final int rows = overlap.fold(
        0,
        (int value, AppointmentView v) => math.max(value, v.position + 1),
      );
      for (final AppointmentView view in overlap) {
        if (view.maxPositions == -1) {
          view.maxPositions = rows;
        }
      }
    }
  }
  // SF-22: a new neighbor can change all-day lanes without changing events.
  bool hasSameLayout(_DayWindowAppointments other) {
    if (!CalendarViewHelper.isCollectionEqual(visible, other.visible) ||
        views.length != other.views.length)
      return false;
    for (int i = 0; i < views.length; i++) {
      final AppointmentView a = views[i], b = other.views[i];
      if (!identical(a.appointment, b.appointment) ||
          a.startIndex != b.startIndex ||
          a.endIndex != b.endIndex ||
          a.position != b.position ||
          a.maxPositions != b.maxPositions) {
        return false;
      }
    }
    return true;
  }

  late final List<CalendarAppointment> visible;
  final List<AppointmentView> views = <AppointmentView>[];
}

extension _DayWindowData on _CustomCalendarScrollViewState {
  _DayWindowAppointments _dayWindowAppointments(
    List<DateTime> dates, {
    List<dynamic>? changedData,
  }) {
    widget.getCalendarState(_updateCalendarStateDetails);
    final List<CalendarAppointment> appointments =
        _updateCalendarStateDetails.appointments;
    if (!identical(appointments, _dayWindowAppointmentSource)) {
      _dayWindowAppointmentSource = appointments;
      _dayWindowAppointmentCache.clear();
    }
    final List<List<DateTime>> blocks = <List<DateTime>>[
      _previousViewVisibleDates,
      _currentViewVisibleDates,
      _nextViewVisibleDates,
    ]..sort((List<DateTime> a, List<DateTime> b) => a.first.compareTo(b.first));
    if (changedData != null ||
        blocks.any(
          (List<DateTime> block) =>
              !_dayWindowAppointmentCache.containsKey(block.first),
        )) {
      final _DayWindowAppointments shared = _DayWindowAppointments(
        blocks.expand((List<DateTime> block) => block).toList(),
        appointments,
        widget.calendar,
        expandedAppointments: _expandDayWindowEdges(
          blocks,
          appointments,
          changedData: changedData,
        ),
      );
      _dayWindowAppointmentCache.removeWhere(
        (DateTime date, _) =>
            !blocks.any((List<DateTime> block) => block.first == date),
      );
      for (final List<DateTime> block in blocks) {
        final _DayWindowAppointments next = _DayWindowAppointments(
          block,
          appointments,
          widget.calendar,
          sharedLayout: shared,
        );
        final _DayWindowAppointments? previous =
            _dayWindowAppointmentCache[block.first];
        if (previous == null || !previous.hasSameLayout(next)) {
          _dayWindowAppointmentCache[block.first] = next;
        }
      }
    }
    // A departing child can request its old dates during the same rebuild.
    // Do not retain that projection in the bounded current-buffer cache.
    return _dayWindowAppointmentCache[dates.first] ??
        _DayWindowAppointments(dates, appointments, widget.calendar);
  }

  // SF-22: retain occurrence instances over the intersection of the buffers,
  // expanding only entering natural dates (also when settling by a single day).
  List<CalendarAppointment> _expandDayWindowEdges(
    List<List<DateTime>> blocks,
    List<CalendarAppointment> appointments, {
    List<dynamic>? changedData,
  }) {
    final DateTime start = blocks.first.first;
    final DateTime end = blocks.last.last;
    List<CalendarAppointment> expand(DateTime first, DateTime last) =>
        AppointmentHelper.getVisibleAppointments(
          first,
          last,
          appointments,
          widget.calendar.timeZone,
          false,
        );
    if (_dayWindowAppointmentCache.isEmpty) {
      return expand(start, end);
    }
    final List<DateTime> oldStarts =
        _dayWindowAppointmentCache.keys.toList()..sort();
    final DateTime oldStart = oldStarts.first;
    final DateTime oldEnd = _dayDate(oldStarts.last, blocks.first.length - 1);
    if (end.isBefore(oldStart) || start.isAfter(oldEnd))
      return expand(start, end);

    // Keep source ordering, including equal public IDs belonging to different
    // data objects. Duplicate source objects use the native expansion path.
    final Map<
      dynamic,
      Map<(DateTime, DateTime, DateTime, DateTime), CalendarAppointment>
    >
    bySource =
        Map<
          dynamic,
          Map<(DateTime, DateTime, DateTime, DateTime), CalendarAppointment>
        >.identity();
    for (final CalendarAppointment appointment in appointments) {
      if (bySource.containsKey(appointment.data)) {
        return expand(start, end);
      }
      bySource[appointment.data] =
          <(DateTime, DateTime, DateTime, DateTime), CalendarAppointment>{};
    }
    final DateTime from = AppointmentHelper.convertToStartTime(start);
    final DateTime to = AppointmentHelper.convertToEndTime(end);
    void collect(Iterable<CalendarAppointment> instances) {
      for (final CalendarAppointment appointment in instances) {
        if (!AppointmentHelper.isAppointmentWithinVisibleDateRange(
          appointment,
          from,
          to,
        )) {
          continue;
        }
        bySource[appointment.data]?.putIfAbsent((
          appointment.actualStartTime,
          appointment.actualEndTime,
          appointment.exactStartTime,
          appointment.exactEndTime,
        ), () => appointment);
      }
    }

    // SF-22: add/remove notifications refresh their sources only. A notified
    // object may have changed in place, so never retain its old occurrences.
    final Set<dynamic> changed =
        Set<dynamic>.identity()..addAll(changedData ?? const <dynamic>[]);
    for (final _DayWindowAppointments retained
        in _dayWindowAppointmentCache.values) {
      collect(
        retained.visible.where(
          (CalendarAppointment a) => !changed.contains(a.data),
        ),
      );
    }
    if (changed.isNotEmpty) {
      collect(
        AppointmentHelper.getVisibleAppointments(
          start,
          end,
          appointments
              .where((CalendarAppointment a) => changed.contains(a.data))
              .toList(),
          widget.calendar.timeZone,
          false,
        ),
      );
    }
    if (start.isBefore(oldStart))
      collect(expand(start, _dayDate(oldStart, -1)));
    if (end.isAfter(oldEnd)) {
      collect(expand(_dayDate(oldEnd, 1), end));
    }
    final List<CalendarAppointment> result = <CalendarAppointment>[];
    for (final CalendarAppointment source in appointments) {
      final List<CalendarAppointment> instances =
          bySource[source.data]!.values.toList()..sort((
            CalendarAppointment a,
            CalendarAppointment b,
          ) {
            final int occurrence = a.exactStartTime.compareTo(b.exactStartTime);
            return occurrence != 0
                ? occurrence
                : a.actualStartTime.compareTo(b.actualStartTime);
          });
      result.addAll(instances);
    }
    return result;
  }

  double get _dayWindowPanelHeight {
    int rows = 0;
    for (final List<DateTime> dates in <List<DateTime>>[
      _previousViewVisibleDates,
      _currentViewVisibleDates,
      _nextViewVisibleDates,
    ]) {
      final _DayWindowAppointments model = _dayWindowAppointments(dates);
      for (final AppointmentView view in model.views) {
        final int start = math.max(0, view.startIndex);
        final int end = math.min(dates.length, view.endIndex);
        for (int i = start; i < end; i++) {
          final double x = _dayWindowSnapshot!.xForDate(dates[i]);
          final double left =
              widget.isRTL ? 0 : widget.width - _dayWindowStride;
          if (x + _dayColumnWidth > left + .01 &&
              x < left + _dayWindowStride - .01) {
            rows = math.max(rows, view.position + 1);
            break;
          }
        }
      }
    }
    return rows * kAllDayAppointmentHeight;
  }

  void _syncDayWindowVertical(_CalendarViewState source) {
    if (_dayWindowSyncingVertical ||
        source._scrollController?.hasClients != true)
      return;
    _dayWindowSyncingVertical = true;
    try {
      final double pixels = source._scrollController!.offset;
      for (final GlobalKey<_CalendarViewState> key
          in <GlobalKey<_CalendarViewState>>[
            _previousViewKey,
            _currentViewKey,
            _nextViewKey,
          ]) {
        final ScrollController? scroll = key.currentState?._scrollController;
        if (scroll == null ||
            !scroll.hasClients ||
            identical(scroll, source._scrollController))
          continue;
        final double target = pixels.clamp(0, scroll.position.maxScrollExtent);
        if ((scroll.offset - target).abs() > .01) {
          scroll.jumpTo(target);
        }
      }
      _currentViewKey.currentState?._pushTimelineCoordinates(true);
    } finally {
      _dayWindowSyncingVertical = false;
    }
  }
}
