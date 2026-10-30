// SF-22: bounded three-block day navigation, isolated from the paged path.
part of 'calendar_view.dart';

extension _ContinuousDayWindow on _CustomCalendarScrollViewState {
  bool _isContinuousDayWindow(CustomCalendarScrollView candidate) =>
      candidate.calendar.dayWindowNavigation ==
          DayWindowNavigation.continuous &&
      ((candidate.view == CalendarView.day &&
              candidate.calendar.timeSlotViewSettings.numberOfDaysInView ==
                  3) ||
          (candidate.view == CalendarView.week &&
              (candidate.calendar.timeSlotViewSettings.numberOfDaysInView ==
                      -1 ||
                  candidate.calendar.timeSlotViewSettings.numberOfDaysInView ==
                      7)));

  bool get _usesContinuousDayWindow => _isContinuousDayWindow(widget);

  DateTime _boundedDayWindowFirst(DateTime anchor, int visibleDatesCount) {
    final DateTime min = _dayDate(widget.minDate, 0);
    final DateTime end = _dayDate(
      widget.maxDate,
      1 - visibleDatesCount,
    );
    final DateTime max = end.isBefore(min) ? min : end;
    return anchor.isBefore(min) ? min : (anchor.isAfter(max) ? max : anchor);
  }

  void _finishDayWindowConfiguration(DateTime anchor) {
    _setDayWindowDates(
      _boundedDayWindowFirst(anchor, _currentViewVisibleDates.length),
    );
    _position = 0;
    _dayWindowTravel = _dayWindowBaseTravel = 0;
    final int generation = _dayWindowGeneration;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _dayWindowGeneration) {
        return;
      }
      _commitDayWindow();
    });
  }

  double get _dayWindowStride => math.max(
    1,
    widget.width -
        CalendarViewHelper.getTimeLabelWidth(
          widget.calendar.timeSlotViewSettings.timeRulerSize,
          widget.view,
        ),
  );
  double get _dayColumnWidth =>
      _dayWindowStride / _currentViewVisibleDates.length;
  double get _dayDirection => widget.isRTL ? -1 : 1;

  DayWindowSnapshot? get _dayWindowSnapshot {
    if (!_usesContinuousDayWindow) {
      return null;
    }
    final int count = _currentViewVisibleDates.length;
    return DayWindowSnapshot(
      renderedDates: <DateTime>[
        ...(widget.isRTL ? _nextViewVisibleDates : _previousViewVisibleDates),
        ..._currentViewVisibleDates,
        ...(widget.isRTL ? _previousViewVisibleDates : _nextViewVisibleDates),
      ],
      visibleDayCount: count,
      columnWidth: _dayColumnWidth,
      contentLeft: widget.isRTL ? 0 : widget.width - _dayWindowStride,
      horizontalOffset:
          _position +
          (widget.isRTL
              ? 2 * _dayWindowStride - _dayColumnWidth
              : -_dayWindowStride),
      settledFirstDate:
          _settledDayWindowFirst ?? _currentViewVisibleDates.first,
      phase: _dayWindowPhase,
      generation: _dayWindowGeneration,
      sequence: _dayWindowSequence,
      isRTL: widget.isRTL,
    );
  }

  void _publishDayWindowCoordinates() {
    _dayWindowSequence++;
    _currentViewKey.currentState?._pushTimelineCoordinates(true);
  }

  // Paint transforms and pointer queries choose the same visible block.
  _CalendarViewState? _dayWindowViewAt(double globalX) {
    final RenderBox body = context.findRenderObject()! as RenderBox;
    final double x = body.globalToLocal(Offset(globalX, 0)).dx;
    final double ruler = widget.width - _dayWindowStride;
    if (x < (widget.isRTL ? 0 : ruler) ||
        x >= (widget.isRTL ? _dayWindowStride : widget.width))
      return null;
    for (final GlobalKey<_CalendarViewState> key
        in <GlobalKey<_CalendarViewState>>[
          _previousViewKey,
          _currentViewKey,
          _nextViewKey,
        ]) {
      final _CalendarViewState? page = key.currentState;
      final RenderBox? box = page?.context.findRenderObject() as RenderBox?;
      if (page == null || box == null || !box.attached) {
        continue;
      }
      final double localX = box.globalToLocal(Offset(globalX, 0)).dx;
      if (localX >= (widget.isRTL ? 0 : ruler) &&
          localX < (widget.isRTL ? _dayWindowStride : widget.width))
        return page;
    }
    return null;
  }

  DateTime? _dayWindowDateAt(double globalX) {
    final _CalendarViewState? page = _dayWindowViewAt(globalX);
    if (page == null) {
      return null;
    }
    final RenderBox box = page.context.findRenderObject()! as RenderBox;
    final double ruler = widget.width - _dayWindowStride;
    final double x =
        box.globalToLocal(Offset(globalX, 0)).dx - (widget.isRTL ? 0 : ruler);
    int index = (x / _dayColumnWidth).floor();
    if (widget.isRTL) {
      index = page.widget.visibleDates.length - index - 1;
    }
    return page.widget.visibleDates[index];
  }

  DateTime? _dayWindowDragDate(double x, double y, double ruler) {
    final RenderBox body = context.findRenderObject()! as RenderBox;
    final double bodyX = (x + (widget.isRTL ? 0 : ruler)).clamp(
      widget.isRTL ? 0 : ruler,
      (widget.isRTL ? _dayWindowStride : widget.width) - .01,
    );
    final Offset global = body.localToGlobal(Offset(bodyX, 0));
    final _CalendarViewState? page = _dayWindowViewAt(global.dx);
    if (page == null) {
      return null;
    }
    final RenderBox box = page.context.findRenderObject()! as RenderBox;
    final double localX =
        box.globalToLocal(global).dx - (widget.isRTL ? 0 : ruler);
    return page._getDateFromPosition(localX, y, ruler);
  }

  SfCalendarEmptySlotQueryResult? _dayWindowSlotAt(Offset global) {
    final _CalendarViewState? page = _dayWindowViewAt(global.dx);
    if (page == null) {
      return null;
    }
    final RenderBox box = page.context.findRenderObject()! as RenderBox;
    final Offset local = box.globalToLocal(global);
    final double top = page._effectiveTimelineViewportTop;
    if (local.dy < top || local.dy >= widget.height) {
      return null;
    }
    final double ruler = widget.width - _dayWindowStride;
    final DateTime? time = page._getDateFromPosition(
      local.dx - (widget.isRTL ? 0 : ruler),
      local.dy - top,
      ruler,
    );
    if (time == null) {
      return null;
    }
    final CalendarDetails? details = page._getCalendarViewDetails(local);
    final RenderBox body = context.findRenderObject()! as RenderBox;
    return SfCalendarEmptySlotQueryResult(
      time: time,
      date: _dayDate(time, 0),
      localPosition: body.globalToLocal(global),
      isOnAppointment: details?.targetElement == CalendarElement.appointment,
    );
  }

  Widget _buildDayWindowRuler() => GestureDetector(
    onTapUp:
        (TapUpDetails details) =>
            _currentViewKey.currentState?._handleOnTapForDay(details),
    onVerticalDragUpdate: (DragUpdateDetails details) {
      final ScrollController? scroll =
          _currentViewKey.currentState?._scrollController;
      if (scroll == null || !scroll.hasClients) {
        return;
      }
      scroll.jumpTo(
        (scroll.offset - details.delta.dy).clamp(
          0,
          scroll.position.maxScrollExtent,
        ),
      );
    },
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _DayWindowRulerPainter(this),
        size: Size(widget.width, widget.height),
      ),
    ),
  );

  void _stopDayWindowMotion() {
    _dayWindowGeneration++;
    _dayWindowMotion?.stop();
    _dayWindowDragging = false;
    _dayWindowContactInterrupted = false;
    _dayWindowPhase = DayWindowPhase.idle;
  }

  void _beginDayWindowDrag() {
    _stopDayWindowMotion();
    _dayWindowDragging = true;
    _dayWindowPhase = DayWindowPhase.dragging;
    _settledDayWindowFirst ??= _currentViewVisibleDates.first;
    _dayWindowTravel = _position;
    _dayWindowBaseTravel = 0;
    _clearSelection();
    _publishDayWindowCoordinates();
  }

  DateTime _dayDate(DateTime date, int delta) =>
      DateTime(date.year, date.month, date.day + delta);

  // Natural dates, including DST transitions, are counted in a UTC date plane.
  int _dayDistance(DateTime a, DateTime b) =>
      DateTime.utc(
        b.year,
        b.month,
        b.day,
      ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  double _boundedDayTravel(double travel) {
    final DateTime first = _currentViewVisibleDates.first;
    final DateTime min = _dayDate(widget.minDate, 0);
    final DateTime lastStart = _dayDate(
      widget.maxDate,
      1 - _currentViewVisibleDates.length,
    );
    final DateTime max = lastStart.isBefore(min) ? min : lastStart;
    final double a =
        _dayWindowBaseTravel -
        _dayDistance(first, min) * _dayColumnWidth * _dayDirection;
    final double b =
        _dayWindowBaseTravel -
        _dayDistance(first, max) * _dayColumnWidth * _dayDirection;
    return travel.clamp(math.min(a, b), math.max(a, b));
  }

  void _setDayWindowDates(DateTime first) {
    final int count = _currentViewVisibleDates.length;
    final List<List<DateTime>> oldDates = <List<DateTime>>[
      _previousViewVisibleDates,
      _currentViewVisibleDates,
      _nextViewVisibleDates,
    ];
    List<DateTime> dates(int offset) {
      final DateTime start = _dayDate(first, offset);
      for (final List<DateTime> retained in oldDates) {
        if (retained.length == count && retained.first == start) {
          return retained;
        }
      }
      return List<DateTime>.generate(
        count,
        (int i) => _dayDate(start, i),
        growable: false,
      );
    }

    final List<List<DateTime>> nextDates = <List<DateTime>>[
      dates(widget.isRTL ? count : -count),
      dates(0),
      dates(widget.isRTL ? -count : count),
    ];
    // SF-22: move the mounted date blocks with their keys, recycling only the
    // departing block. Replacing all three dates discards two valid layouts.
    if (_children.isNotEmpty) {
      final List<_CalendarView> views = <_CalendarView>[
        _previousView,
        _currentView,
        _nextView,
      ];
      final List<GlobalKey<_CalendarViewState>> keys =
          <GlobalKey<_CalendarViewState>>[
            _previousViewKey,
            _currentViewKey,
            _nextViewKey,
          ];
      final List<int> order =
          nextDates
              .map(
                (List<DateTime> dates) => views.indexWhere(
                  (_CalendarView view) => identical(view.visibleDates, dates),
                ),
              )
              .toList();
      final List<int> unused = <int>[
        for (int i = 0; i < 3; i++)
          if (!order.contains(i)) i,
      ];
      for (int i = 0; i < 3; i++) {
        if (order[i] == -1) {
          order[i] = unused.removeAt(0);
        }
      }
      // SF-22: expansion belongs to the window, not to the date block that
      // happened to own it. Transfer its in-flight progress before key rotation.
      final _CalendarViewState? previous = _currentViewKey.currentState;
      final _CalendarViewState? current = keys[order[1]].currentState;
      if (previous != null &&
          current != null &&
          !identical(previous, current)) {
        final AnimationController? expansion =
            previous._expanderAnimationController;
        final AnimationController? incoming =
            current._expanderAnimationController;
        current._isExpanded = previous._isExpanded;
        if (expansion != null && incoming != null) {
          final bool animating = expansion.isAnimating;
          expansion.stop();
          if (incoming.value != expansion.value) {
            incoming.value = expansion.value;
          }
          if (animating) {
            if (current._isExpanded) {
              incoming.forward();
            } else {
              incoming.reverse();
            }
          }
        }
      }
      _previousView = views[order[0]];
      _currentView = views[order[1]];
      _nextView = views[order[2]];
      _previousViewKey = keys[order[0]];
      _currentViewKey = keys[order[1]];
      _nextViewKey = keys[order[2]];
      _children
        ..clear()
        ..addAll(<_CalendarView>[_previousView, _currentView, _nextView]);
    }
    _currentChildIndex = 1;
    _previousViewVisibleDates = nextDates[0];
    _visibleDates = _currentViewVisibleDates = nextDates[1];
    _nextViewVisibleDates = nextDates[2];
    // SF-22: the parent consumes the same prepared occurrences as this block.
    final List<CalendarAppointment> visibleAppointments =
        _dayWindowAppointments(_visibleDates).visible;
    widget.getCalendarState(_updateCalendarStateDetails);
    _updateCalendarStateDetails.currentViewVisibleDates = _visibleDates;
    _updateCalendarStateDetails.visibleAppointments = visibleAppointments;
    _updateCalendarStateDetails.transientDayWindow = true;
    widget.updateCalendarState(_updateCalendarStateDetails);
    _updateCalendarStateDetails.transientDayWindow = false;
  }

  void _applyDayWindowTravel(double value) {
    if (!mounted) {
      return;
    }
    final double oldPanelHeight = _dayWindowPanelHeight;
    _dayWindowTravel = _boundedDayTravel(value);
    final double relative = _dayWindowTravel - _dayWindowBaseTravel;
    // SF-22: retain all three mounted date blocks while travel remains inside
    // their prepared range. Replacing seven-day children at every crossed day
    // made a single gesture rebuild the appointment layouts several times.
    final int blocks =
        (-relative / _dayWindowStride * _dayDirection).truncate();
    if (blocks != 0) {
      final int days = blocks * _currentViewVisibleDates.length;
      _dayWindowBaseTravel -= blocks * _dayWindowStride * _dayDirection;
      _setDayWindowDates(_dayDate(_currentViewVisibleDates.first, days));
    }
    _position = _dayWindowTravel - _dayWindowBaseTravel;
    if (oldPanelHeight != _dayWindowPanelHeight) {
      _children.clear();
      _currentViewKey.currentState?._readPageCalendarState();
      _currentViewKey.currentState?._updateAllDayHeight(true);
    }
    _publishDayWindowCoordinates();
    _queueDayWindowDragRefresh();
    _rebuildDayWindow();
  }

  // Native edge navigation changes the date beneath a stationary drag ghost.
  // Read transforms after layout, with the same generation as this motion frame.
  void _queueDayWindowDragRefresh() {
    if (_dayWindowDragRefreshPending ||
        _dayWindowAppointmentPointer == null ||
        _dragDetails.value.appointmentView == null) {
      return;
    }
    _dayWindowDragRefreshPending = true;
    final int generation = _dayWindowGeneration;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _dayWindowDragRefreshPending = false;
      final Offset? pointer = _dayWindowAppointmentPointer;
      final _CalendarViewState? page = _currentViewKey.currentState;
      if (!mounted ||
          generation != _dayWindowGeneration ||
          pointer == null ||
          page == null ||
          _dragDetails.value.appointmentView == null ||
          _dragDifferenceOffset == null) {
        return;
      }
      final double header = CalendarViewHelper.getViewHeaderHeight(
        widget.calendar.viewHeaderHeight,
        widget.view,
      );
      final double ruler = widget.width - _dayWindowStride;
      _updateAppointmentDragUpdateCallback(
        false,
        header,
        ruler,
        page._effectiveAllDayHeight(header),
        pointer + _dragDifferenceOffset!,
        false,
        page._timeIntervalHeight,
        page,
        pointer,
        false,
        0,
      );
    });
  }

  void _commitDayWindow() {
    final double oldPanelHeight = _dayWindowPanelHeight;
    final int remaining =
        (-_position / _dayColumnWidth * _dayDirection).round();
    if (remaining != 0) {
      _setDayWindowDates(_dayDate(_currentViewVisibleDates.first, remaining));
    }
    _position = 0;
    if (oldPanelHeight != _dayWindowPanelHeight) {
      _children.clear();
      _currentViewKey.currentState?._readPageCalendarState();
      _currentViewKey.currentState?._updateAllDayHeight(true);
    }
    _dayWindowPhase = DayWindowPhase.idle;
    _settledDayWindowFirst = _currentViewVisibleDates.first;
    _publishDayWindowCoordinates();
    widget.getCalendarState(_updateCalendarStateDetails);
    _updateCalendarStateDetails.currentDate = _currentViewVisibleDates.first;
    _updateCalendarStateDetails.currentViewVisibleDates =
        _currentViewVisibleDates;
    _updateCalendarStateDetails.commitDayWindow = true;
    widget.updateCalendarState(_updateCalendarStateDetails);
    _updateCalendarStateDetails.commitDayWindow = false;
    _rebuildDayWindow();
  }

  void _navigateDayWindowToDate() {
    _stopDayWindowMotion();
    _position = 0;
    widget.getCalendarState(_updateCalendarStateDetails);
    _updateCalendarStateDetails.currentDate = widget.controller.displayDate;
    widget.updateCalendarState(_updateCalendarStateDetails);
    _updateVisibleDates(useDayWindowAnchor: true);
    _settledDayWindowFirst = _currentViewVisibleDates.first;
    _publishDayWindowCoordinates();
    _updateMoveToDate();
    _rebuildDayWindow();
  }

  void _navigateDayWindow(double delta) {
    _beginDayWindowDrag();
    _settleDayWindow(0, target: _position + delta);
  }

  void _settleDayWindow(
    double velocity, {
    bool immediate = false,
    double? target,
  }) {
    if (!_usesContinuousDayWindow || !mounted) {
      return;
    }
    _stopDayWindowMotion();
    final int generation = _dayWindowGeneration;
    // SF-22: ramp inertia from zero at the fling threshold. Applying the full
    // velocity at 300 px/s adds ~150 px in one step to a light swipe (#4242).
    final double speed = velocity.clamp(-8000.0, 8000.0);
    final double flingSpeed = speed.sign * math.max(0.0, speed.abs() - 300);
    _dayWindowPhase =
        flingSpeed != 0 ? DayWindowPhase.ballistic : DayWindowPhase.settling;
    _dayWindowTravel = _position;
    _dayWindowBaseTravel = 0;
    // Native scroll friction predicts distance; cap one fling at three windows.
    final double projection =
        flingSpeed == 0
            ? 0
            : FrictionSimulation(
              0.135,
              0,
              flingSpeed,
            ).finalX.clamp(-3 * _dayWindowStride, 3 * _dayWindowStride);
    final double destination = _boundedDayTravel(
      ((target ?? (_position + projection)) / _dayColumnWidth).round() *
          _dayColumnWidth,
    );
    if (immediate || (destination - _position).abs() < .01) {
      _applyDayWindowTravel(destination);
      _commitDayWindow();
      return;
    }
    _dayWindowMotion ??= AnimationController.unbounded(vsync: this)
      ..addListener(() => _applyDayWindowTravel(_dayWindowMotion!.value));
    _dayWindowMotion!
        .animateWith(
          ScrollSpringSimulation(
            SpringDescription.withDampingRatio(
              mass: 1,
              stiffness: 180,
              ratio: 1.05,
            ),
            _position,
            destination,
            flingSpeed,
            tolerance: const Tolerance(distance: .01, velocity: .1),
          ),
        )
        .whenCompleteOrCancel(() {
          if (!mounted || generation != _dayWindowGeneration) {
            return;
          }
          // Avoid floating-point values just below a day failing to settle.
          _applyDayWindowTravel(destination);
          _commitDayWindow();
        });
  }
}

// SF-22: reuse native ruler/header painters, never repaint a page's cached layers.
class _DayWindowRulerPainter extends CustomPainter {
  _DayWindowRulerPainter(this.owner)
    : super(
        repaint: Listenable.merge(<Listenable>[
          owner._timelineViewportTop,
          owner._dayWindowRulerRepaint,
        ]),
      );
  final _CustomCalendarScrollViewState owner;

  @override
  void paint(Canvas canvas, Size size) {
    final _CalendarViewState? page = owner._currentViewKey.currentState;
    if (page == null || page._scrollController?.hasClients != true) {
      return;
    }
    final CustomCalendarScrollView widget = owner.widget;
    final bool isRTL = widget.isRTL;
    final double ruler = widget.width - owner._dayWindowStride;
    if (ruler <= 0) {
      return;
    }
    final double left = isRTL ? widget.width - ruler : 0;
    final double actualViewHeaderHeight =
        CalendarViewHelper.getViewHeaderHeight(
          widget.calendar.viewHeaderHeight,
          widget.view,
        );
    final double top = owner._timelineViewportTop.value;
    final Paint background =
        Paint()
          ..color =
              widget.calendar.backgroundColor ??
              widget.calendarTheme.backgroundColor!;
    canvas.drawRect(Rect.fromLTWH(left, 0, ruler, size.height), background);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(left, 0, ruler, actualViewHeaderHeight));
    _ViewHeaderViewPainter(
      owner._currentViewVisibleDates,
      widget.view,
      widget.calendar.viewHeaderStyle,
      widget.calendar.timeSlotViewSettings,
      CalendarViewHelper.getTimeLabelWidth(
        widget.calendar.timeSlotViewSettings.timeRulerSize,
        widget.view,
      ),
      actualViewHeaderHeight,
      widget.calendar.monthViewSettings,
      isRTL,
      widget.locale,
      widget.calendarTheme,
      widget.themeData,
      widget.calendar.todayHighlightColor ??
          widget.calendarTheme.todayHighlightColor,
      widget.calendar.todayTextStyle,
      widget.calendar.cellBorderColor,
      widget.calendar.minDate,
      widget.calendar.maxDate,
      page._viewHeaderNotifier,
      widget.textScaleFactor,
      widget.calendar.showWeekNumber,
      widget.isMobilePlatform,
      widget.calendar.weekNumberStyle,
      widget.localizations,
    ).paint(canvas, Size(size.width, actualViewHeaderHeight));
    canvas.restore();
    if (top > actualViewHeaderHeight) {
      background.color =
          widget.calendar.timeSlotViewSettings.allDayPanelColor ??
          widget.calendarTheme.allDayPanelColor!;
      canvas.drawRect(
        Rect.fromLTWH(
          left,
          actualViewHeaderHeight,
          ruler,
          top - actualViewHeaderHeight,
        ),
        background,
      );
      if (page._updateCalendarStateDetails.allDayPanelHeight >
          _kAllDayLayoutHeight) {
        final TextPainter icon = TextPainter(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          textScaler: TextScaler.linear(widget.textScaleFactor),
          text: TextSpan(
            text: String.fromCharCode(
              page._isExpanded
                  ? Icons.expand_less.codePoint
                  : Icons.expand_more.codePoint,
            ),
            style: TextStyle(
              fontFamily: 'MaterialIcons',
              fontSize: kAllDayAppointmentHeight + 5,
              color: widget.calendarTheme.viewHeaderDayTextStyle!.color,
            ),
          ),
        )..layout(maxWidth: ruler);
        icon.paint(
          canvas,
          Offset(
            left + (ruler - icon.width) / 2,
            top -
                kAllDayAppointmentHeight +
                (kAllDayAppointmentHeight - icon.height) / 2,
          ),
        );
        icon.dispose();
      }
    }
    final double scroll = page._scrollController!.offset;
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(left, top, ruler, math.max(0, size.height - top)),
    );
    canvas.translate(left, top - scroll);
    final _TimeRulerView rulerPainter = _TimeRulerView(
      page._horizontalLinesCount!,
      page._timeIntervalHeight,
      widget.calendar.timeSlotViewSettings,
      widget.calendar.cellBorderColor,
      isRTL,
      widget.locale,
      widget.calendarTheme,
      false,
      owner._currentViewVisibleDates,
      widget.textScaleFactor,
    );
    final Size rulerSize = Size(
      ruler,
      page._horizontalLinesCount! * page._timeIntervalHeight,
    );
    final _TimeRulerView? previous = owner._dayWindowRulerDelegate;
    // SF-22: scrolling translates the same fixed labels. Keep one display list
    // until date/locale/theme/scale/geometry changes; release it with the owner.
    if (owner._dayWindowRulerPicture == null ||
        owner._dayWindowRulerSize != rulerSize ||
        previous == null ||
        previous.horizontalLinesCount != rulerPainter.horizontalLinesCount ||
        previous.timeIntervalHeight != rulerPainter.timeIntervalHeight ||
        rulerPainter.shouldRepaint(previous)) {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      rulerPainter.paint(Canvas(recorder), rulerSize);
      final ui.Picture picture = recorder.endRecording();
      owner._dayWindowRulerPicture?.dispose();
      owner._dayWindowRulerPicture = picture;
      owner._dayWindowRulerDelegate = rulerPainter;
      owner._dayWindowRulerSize = rulerSize;
    }
    rulerPainter._textPainter.dispose();
    canvas.drawPicture(owner._dayWindowRulerPicture!);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DayWindowRulerPainter oldDelegate) => true;
}
