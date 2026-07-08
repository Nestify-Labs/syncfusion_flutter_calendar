import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:syncfusion_flutter_core/core.dart';
import 'package:syncfusion_flutter_core/localizations.dart';
import 'package:syncfusion_flutter_core/theme.dart';

import '../appointment_engine/appointment_helper.dart';
import '../appointment_engine/month_appointment_helper.dart';
import '../common/calendar_view_helper.dart';
import '../common/date_time_engine.dart';
import '../common/enums.dart';
import '../common/event_args.dart';
import '../resource_view/calendar_resource.dart';
import '../settings/time_slot_view_settings.dart';
import '../sfcalendar.dart';

/// Used to holds the appointment views in calendar widgets.
class AppointmentLayout extends StatefulWidget {
  /// Constructor to create the appointment layout that holds the appointment
  /// views in calendar widget.
  const AppointmentLayout(
    this.calendar,
    this.view,
    this.visibleDates,
    this.visibleAppointments,
    this.timeIntervalHeight,
    this.calendarTheme,
    this.themeData,
    this.isRTL,
    this.appointmentHoverPosition,
    this.resourceCollection,
    this.resourceItemHeight,
    this.textScaleFactor,
    this.isMobilePlatform,
    this.width,
    this.height,
    this.localizations,
    this.updateCalendarState, {
    Key? key,
  }) : super(key: key);

  /// Holds the calendar instance used the get the properties of calendar.
  final SfCalendar calendar;

  /// Defines the current calendar view of the calendar widget.
  final CalendarView view;

  /// Holds the visible dates of the appointments view.
  final List<DateTime> visibleDates;

  /// Defines the time interval height of calendar and it used on day, week,
  /// workweek and timeline calendar views.
  final double timeIntervalHeight;

  /// Used to get the calendar state details.
  final UpdateCalendarState updateCalendarState;

  /// Defines the direction of the calendar widget is RTL or not.
  final bool isRTL;

  /// Holds the theme data of the calendar widget.
  final SfCalendarThemeData calendarTheme;

  /// Holds the framework theme data values.
  final ThemeData themeData;

  /// Used to hold the appointment layout hovering position.
  final ValueNotifier<Offset?> appointmentHoverPosition;

  /// Holds the resource details of the calendar widget.
  final List<CalendarResource>? resourceCollection;

  /// Defines the resource item height of the calendar widget.
  final double? resourceItemHeight;

  /// Defines the scale factor of the calendar widget.
  final double textScaleFactor;

  /// Defines the current platform is mobile platform or not.
  final bool isMobilePlatform;

  /// Defines the width of the appointment layout widget.
  final double width;

  /// Defines the height of the appointment layout widget.
  final double height;

  /// Holds the localization data of the calendar widget.
  final SfLocalizations localizations;

  /// Holds the visible appointment collection of the calendar widget.
  final ValueNotifier<List<CalendarAppointment>?> visibleAppointments;

  /// Return the appointment view based on x and y position.
  AppointmentView? getAppointmentViewOnPoint(double x, double y) {
    // ignore: avoid_as
    final GlobalKey appointmentLayoutKey = key! as GlobalKey;
    final _AppointmentLayoutState state =
        // ignore: avoid_as
        appointmentLayoutKey.currentState! as _AppointmentLayoutState;
    return state._getAppointmentViewOnPoint(x, y);
  }

  /// Returns the visible appointment view collection.
  List<AppointmentView> getAppointmentViewCollection() {
    // ignore: avoid_as
    final GlobalKey appointmentLayoutKey = key! as GlobalKey;
    final _AppointmentLayoutState state =
        // ignore: avoid_as
        appointmentLayoutKey.currentState! as _AppointmentLayoutState;
    return state._appointmentCollection;
  }

  @override
  // ignore: library_private_types_in_public_api
  _AppointmentLayoutState createState() => _AppointmentLayoutState();
}

class _AppointmentLayoutState extends State<AppointmentLayout> {
  /// It holds the appointment views for the visible appointments.
  final List<AppointmentView> _appointmentCollection = <AppointmentView>[];

  /// It holds the appointment list based on its visible index value.
  Map<int, List<AppointmentView>> _indexAppointments =
      <int, List<AppointmentView>>{};

  /// It holds the more appointment index appointment counts based on its index.
  Map<int, RRect> _monthAppointmentCountViews = <int, RRect>{};

  /// It holds the children of the widget, it holds empty when
  /// appointment builder is null.
  final List<Widget> _children = <Widget>[];

  final UpdateCalendarStateDetails _updateCalendarStateDetails =
      UpdateCalendarStateDetails();
  TextPainter _textPainter = TextPainter();
  late double _weekNumberPanelWidth;

  @override
  void initState() {
    widget.updateCalendarState(_updateCalendarStateDetails);
    _weekNumberPanelWidth = CalendarViewHelper.getWeekNumberPanelWidth(
      widget.calendar.showWeekNumber,
      widget.width,
      widget.isMobilePlatform,
    );

    _updateAppointmentDetails();
    widget.visibleAppointments.addListener(_updateVisibleAppointment);
    super.initState();
  }

  @override
  void didUpdateWidget(AppointmentLayout oldWidget) {
    bool isAppointmentDetailsUpdated = false;
    if (widget.visibleDates != oldWidget.visibleDates ||
        widget.timeIntervalHeight != oldWidget.timeIntervalHeight ||
        widget.calendar != oldWidget.calendar ||
        widget.width != oldWidget.width ||
        widget.height != oldWidget.height ||
        (CalendarViewHelper.isTimelineView(widget.view) &&
            (widget.resourceCollection != oldWidget.resourceCollection ||
                widget.resourceItemHeight != oldWidget.resourceItemHeight))) {
      _weekNumberPanelWidth = CalendarViewHelper.getWeekNumberPanelWidth(
        widget.calendar.showWeekNumber,
        widget.width,
        widget.isMobilePlatform,
      );
      isAppointmentDetailsUpdated = true;
      _updateAppointmentDetails();
    }

    if (widget.visibleAppointments != oldWidget.visibleAppointments) {
      oldWidget.visibleAppointments.removeListener(_updateVisibleAppointment);
      widget.visibleAppointments.addListener(_updateVisibleAppointment);
      if (!CalendarViewHelper.isCollectionEqual(
            widget.visibleAppointments.value,
            oldWidget.visibleAppointments.value,
          ) &&
          !isAppointmentDetailsUpdated) {
        _updateAppointmentDetails();
      }
    }

    if (widget.calendar.showWeekNumber != oldWidget.calendar.showWeekNumber &&
        widget.view == CalendarView.month) {
      _weekNumberPanelWidth = CalendarViewHelper.getWeekNumberPanelWidth(
        widget.calendar.showWeekNumber,
        widget.width,
        widget.isMobilePlatform,
      );

      _updateAppointmentDetails();
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.visibleAppointments.removeListener(_updateVisibleAppointment);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// Create the widgets when appointment builder is not null.
    if (_children.isEmpty && widget.calendar.appointmentBuilder != null) {
      final DateTime initialVisibleDate = widget.visibleDates[0];
      for (int i = 0; i < _appointmentCollection.length; i++) {
        final AppointmentView appointmentView = _appointmentCollection[i];

        /// Check the appointment view have appointment, if not then the
        /// appointment view is not valid or it will be used for reusing view.
        if (appointmentView.appointment == null ||
            appointmentView.appointmentRect == null) {
          continue;
        }

        final DateTime appStartTime = DateTime(
          appointmentView.appointment!.actualStartTime.year,
          appointmentView.appointment!.actualStartTime.month,
          appointmentView.appointment!.actualStartTime.day,
        );
        final DateTime date =
            appointmentView.startIndex != -1
                ? widget.visibleDates[appointmentView.startIndex]
                : appStartTime.isBefore(initialVisibleDate)
                ? initialVisibleDate
                : appStartTime;

        final Widget child = widget.calendar.appointmentBuilder!(
          context,
          CalendarAppointmentDetails(
            date,
            List<dynamic>.unmodifiable(<dynamic>[
              CalendarViewHelper.getAppointmentDetail(
                appointmentView.appointment!,
                widget.calendar.dataSource,
              ),
            ]),
            Rect.fromLTWH(
              appointmentView.appointmentRect!.left,
              appointmentView.appointmentRect!.top,
              appointmentView.appointmentRect!.width,
              appointmentView.appointmentRect!.height,
            ),
          ),
        );

        _children.add(RepaintBoundary(child: child));
      }

      if (_monthAppointmentCountViews.isNotEmpty) {
        final List<int> keys = _monthAppointmentCountViews.keys.toList();

        /// Get the more appointment index(more appointment index map holds more
        /// appointment needed cell index and it bound)
        for (int i = 0; i < keys.length; i++) {
          final int index = keys[i];
          final int maximumDisplayCount =
              widget.calendar.monthViewSettings.appointmentDisplayCount;
          final List<CalendarAppointment> moreAppointments =
              <CalendarAppointment>[];
          final List<AppointmentView> moreAppointmentViews =
              _indexAppointments[index]!;

          /// Get the appointments of the more appointment cell index from more
          /// appointment views.
          for (int j = 0; j < moreAppointmentViews.length; j++) {
            final AppointmentView currentAppointment = moreAppointmentViews[j];
            final CalendarAppointment? appointment =
                currentAppointment.appointment;

            /// In month appointment mode, when there are more appointments than
            /// appointmentDisplayCount, the last slot is reserved for the
            /// "more" region. So this callback should receive only hidden
            /// appointments (position >= appointmentDisplayCount) and not the
            /// already visible appointment slots.
            if (currentAppointment.position < maximumDisplayCount) {
              continue;
            }

            /// For spanned appointments the same AppointmentView is registered
            /// in every day index it covers (e.g. Apr 19, 20, 21 all reference
            /// the same view). Only collect hidden appointments that START at
            /// the current index so the builder is invoked once at the span's
            /// first day (Apr 19) and skipped for continuation days (Apr 20, 21).
            if (currentAppointment.startIndex != index) {
              continue;
            }

            if (appointment == null ||
                moreAppointments.any(
                  (CalendarAppointment existingAppointment) =>
                      identical(existingAppointment, appointment),
                )) {
              continue;
            }

            moreAppointments.add(appointment);
          }

          /// If no hidden appointments start at this index (all are span
          /// continuations from an earlier day, e.g. Apr 20 and Apr 21 are
          /// continuations of a span starting Apr 19), skip the builder call
          /// entirely so those continuation days produce no extra widgets.
          if (moreAppointments.isEmpty) {
            continue;
          }

          /// For hidden spanned appointments, find the furthest end index
          /// among all hidden appointments that start at this index so the
          /// builder receives a span-wide rect instead of a 1-cell rect.
          int maxEndIndex = index;
          for (int j = 0; j < moreAppointmentViews.length; j++) {
            final AppointmentView appointmentView = moreAppointmentViews[j];
            if (appointmentView.appointment != null &&
                appointmentView.position >= maximumDisplayCount &&
                appointmentView.startIndex == index &&
                appointmentView.endIndex > maxEndIndex) {
              maxEndIndex = appointmentView.endIndex;
            }
          }

          final RRect moreRegionRect = _monthAppointmentCountViews[index]!;

          /// When the hidden appointments span multiple days within the same
          /// week row, expand the bounds to cover the full span width so the
          /// builder widget matches a normal spanning appointment layout.
          Rect moreAppointmentBounds = Rect.fromLTWH(
            moreRegionRect.left,
            moreRegionRect.top,
            moreRegionRect.width,
            moreRegionRect.height,
          );
          if (maxEndIndex > index) {
            final double cellWidth =
                (widget.width - _weekNumberPanelWidth) / DateTime.daysPerWeek;
            final double cellEndPadding = CalendarViewHelper.getCellEndPadding(
              widget.calendar.cellEndPadding,
              widget.isMobilePlatform,
            );
            final double spanWidth =
                (maxEndIndex - index + 1) * cellWidth - cellEndPadding;

            /// In RTL mode the cells are laid out right-to-left, so the left
            /// edge of the span must be shifted left by the extra cells.
            final double spanLeft =
                widget.isRTL
                    ? moreRegionRect.left - (maxEndIndex - index) * cellWidth
                    : moreRegionRect.left;
            moreAppointmentBounds = Rect.fromLTWH(
              spanLeft,
              moreRegionRect.top,
              spanWidth > 0 ? spanWidth : 0,
              moreRegionRect.height,
            );

            /// Also update the stored rect so the render object's
            /// performLayout and paint use the span-wide rect to correctly
            /// constrain and position the builder child widget on screen.
            _monthAppointmentCountViews[index] = RRect.fromRectAndRadius(
              moreAppointmentBounds,
              Radius.zero,
            );
          }

          final DateTime date = widget.visibleDates[index];
          final Widget child = widget.calendar.appointmentBuilder!(
            context,
            CalendarAppointmentDetails(
              date,
              List<dynamic>.unmodifiable(
                CalendarViewHelper.getCustomAppointments(
                  moreAppointments,
                  widget.calendar.dataSource,
                ),
              ),
              moreAppointmentBounds,
              isMoreAppointmentRegion: true,
            ),
          );

          /// Throw exception when builder return widget is null.
          _children.add(RepaintBoundary(child: child));
        }
      }
    }

    return _AppointmentRenderWidget(
      widget.calendar,
      widget.view,
      widget.visibleDates,
      widget.visibleAppointments.value,
      widget.timeIntervalHeight,
      widget.calendarTheme,
      widget.themeData,
      widget.isRTL,
      widget.appointmentHoverPosition,
      widget.resourceCollection,
      widget.resourceItemHeight,
      widget.textScaleFactor,
      widget.isMobilePlatform,
      widget.width,
      widget.height,
      widget.localizations,
      _appointmentCollection,
      _indexAppointments,
      _monthAppointmentCountViews,
      _weekNumberPanelWidth,
      widgets: _children,
    );
  }

  AppointmentView? _getAppointmentViewOnPoint(double x, double y) {
    if (_appointmentCollection.isEmpty) {
      return null;
    }

    // SF-15 (Nestify): cascade 模式下取视觉顶层（反向命中），laneFill 模式保持
    // 前向命中以字节级复刻 SF-6——遍历方向与去重逻辑收敛到 [CascadeLayout.hitTest]。
    AppointmentView? selectedAppointmentView = CascadeLayout.hitTest(
      widget.calendar.appointmentOverlapMode,
      _appointmentCollection,
      x,
      y,
    );

    if (selectedAppointmentView == null &&
        widget.view == CalendarView.month &&
        widget.calendar.monthViewSettings.appointmentDisplayMode ==
            MonthAppointmentDisplayMode.appointment) {
      final List<int> keys = _monthAppointmentCountViews.keys.toList();
      for (int i = 0; i < keys.length; i++) {
        // ignore: unnecessary_nullable_for_final_variable_declarations
        final RRect? rect = _monthAppointmentCountViews[keys[i]];

        if (rect != null &&
            rect.left <= x &&
            rect.right >= x &&
            rect.top <= y &&
            rect.bottom >= y) {
          selectedAppointmentView = AppointmentView()..appointmentRect = rect;
          break;
        }
      }
    }

    return selectedAppointmentView;
  }

  void _updateVisibleAppointment() {
    widget.updateCalendarState(_updateCalendarStateDetails);
    if (!mounted) {
      return;
    }

    setState(() {
      _updateAppointmentDetails();
    });
  }

  /// Remove the appointments before the calendar time slot start date and
  /// after the calendar time slot  end date.
  List<CalendarAppointment> _getValidAppointments(
    List<CalendarAppointment> visibleAppointments,
  ) {
    if (visibleAppointments.isEmpty ||
        widget.view == CalendarView.month ||
        widget.view == CalendarView.timelineMonth) {
      return visibleAppointments;
    }

    final List<CalendarAppointment> appointments = <CalendarAppointment>[];
    final int viewStartHour =
        widget.calendar.timeSlotViewSettings.startHour.toInt();
    final int viewStartMinutes =
        (viewStartHour * 60) +
        ((widget.calendar.timeSlotViewSettings.startHour - viewStartHour) * 60)
            .toInt();
    final int viewEndHour =
        widget.calendar.timeSlotViewSettings.endHour.toInt();
    final int viewEndMinutes =
        (viewEndHour * 60) +
        ((widget.calendar.timeSlotViewSettings.endHour - viewEndHour) * 60)
            .toInt();

    for (int i = 0; i < visibleAppointments.length; i++) {
      final CalendarAppointment appointment = visibleAppointments[i];

      /// Skip the span appointment because span appointment will placed
      /// in between the valid hours(between time slot start and end hour).
      if (!isSameDate(appointment.actualEndTime, appointment.actualStartTime)) {
        /// Check the span appointment is start after time slot end hour and
        /// end before time slot start hour then skip the rendering.
        if (isSameDate(
          appointment.actualEndTime,
          appointment.actualStartTime.add(const Duration(days: 1)),
        )) {
          final int appointmentStartMinutes =
              (appointment.actualStartTime.hour * 60) +
              appointment.actualStartTime.minute;
          final int appointmentEndMinutes =
              (appointment.actualEndTime.hour * 60) +
              appointment.actualEndTime.minute;
          if (appointmentStartMinutes >= viewEndMinutes &&
              appointmentEndMinutes <= viewStartMinutes) {
            continue;
          }
        }

        appointments.add(appointment);
        continue;
      }
      final int appointmentStartMinutes =
          (appointment.actualStartTime.hour * 60) +
          appointment.actualStartTime.minute;
      final int appointmentEndMinutes =
          (appointment.actualEndTime.hour * 60) +
          appointment.actualEndTime.minute;

      /// Check the appointment before time slot start hour then skip the
      /// appointment rendering.
      if (appointmentStartMinutes < viewStartMinutes &&
          appointmentEndMinutes <= viewStartMinutes) {
        continue;
      }

      /// Check the appointment after time slot end hour then skip the
      /// appointment rendering.
      if (appointmentStartMinutes >= viewEndMinutes &&
          appointmentEndMinutes > viewEndMinutes) {
        continue;
      }

      appointments.add(appointment);
    }

    return appointments;
  }

  void _updateAppointmentDetails() {
    _monthAppointmentCountViews = <int, RRect>{};
    _indexAppointments = <int, List<AppointmentView>>{};
    widget.updateCalendarState(_updateCalendarStateDetails);
    AppointmentHelper.resetAppointmentView(_appointmentCollection);
    _children.clear();
    if (widget.visibleDates !=
        _updateCalendarStateDetails.currentViewVisibleDates) {
      return;
    }

    final List<CalendarAppointment> visibleAppointments = _getValidAppointments(
      widget.visibleAppointments.value!,
    );
    switch (widget.view) {
      case CalendarView.month:
        {
          _updateMonthAppointmentDetails(visibleAppointments);
        }
        break;
      case CalendarView.day:
      case CalendarView.week:
      case CalendarView.workWeek:
        {
          _updateDayAppointmentDetails(visibleAppointments);
        }
        break;
      case CalendarView.timelineDay:
      case CalendarView.timelineWeek:
      case CalendarView.timelineWorkWeek:
        {
          _updateTimelineAppointmentDetails(visibleAppointments);
        }
        break;
      case CalendarView.timelineMonth:
        {
          _updateTimelineMonthAppointmentDetails(visibleAppointments);
        }
        break;
      case CalendarView.schedule:
        return;
    }
  }

  void _updateMonthAppointmentDetails(
    List<CalendarAppointment> visibleAppointments,
  ) {
    final double cellWidth =
        (widget.width - _weekNumberPanelWidth) / DateTime.daysPerWeek;
    final double cellHeight =
        widget.height / widget.calendar.monthViewSettings.numberOfWeeksInView;
    if (widget.calendar.monthViewSettings.appointmentDisplayMode !=
        MonthAppointmentDisplayMode.appointment) {
      return;
    }

    double xPosition =
        widget.isRTL
            ? widget.width - cellWidth - _weekNumberPanelWidth
            : _weekNumberPanelWidth;
    double yPosition = 0;
    final int count = widget.visibleDates.length;
    DateTime visibleStartDate = AppointmentHelper.convertToStartTime(
      widget.visibleDates[0],
    );
    DateTime visibleEndDate = AppointmentHelper.convertToEndTime(
      widget.visibleDates[count - 1],
    );
    int visibleStartIndex = 0;
    int visibleEndIndex = count - 1;
    final bool showTrailingLeadingDates =
        CalendarViewHelper.isLeadingAndTrailingDatesVisible(
          widget.calendar.monthViewSettings.numberOfWeeksInView,
          widget.calendar.monthViewSettings.showTrailingAndLeadingDates,
        );
    if (!showTrailingLeadingDates) {
      final DateTime currentMonthDate = widget.visibleDates[count ~/ 2];
      visibleStartDate = AppointmentHelper.convertToStartTime(
        AppointmentHelper.getMonthStartDate(currentMonthDate),
      );
      visibleEndDate = AppointmentHelper.convertToEndTime(
        AppointmentHelper.getMonthEndDate(currentMonthDate),
      );
      visibleStartIndex = DateTimeHelper.getIndex(
        widget.visibleDates,
        visibleStartDate,
      );
      visibleEndIndex = DateTimeHelper.getIndex(
        widget.visibleDates,
        visibleEndDate,
      );
    }

    MonthAppointmentHelper.updateAppointmentDetails(
      visibleAppointments,
      _appointmentCollection,
      widget.visibleDates,
      _indexAppointments,
      visibleStartIndex,
      visibleEndIndex,
    );
    final TextStyle style = widget.calendarTheme.todayTextStyle!;
    final TextSpan dateText = TextSpan(
      text: DateTime.now().day.toString(),
      style: style,
    );
    _textPainter = _updateTextPainter(
      dateText,
      _textPainter,
      widget.isRTL,
      widget.textScaleFactor,
    );

    /// cell padding and start position calculated by month date cell
    /// rendering padding and size.
    /// Cell padding value includes month cell text top padding(5) and circle
    /// top(4) and bottom(4) padding
    const double cellPadding = 13;

    /// Today circle radius as circle radius added after the text height.
    const double todayCircleRadius = 5;
    final double startPosition =
        cellPadding + _textPainter.preferredLineHeight + todayCircleRadius;
    final int maximumDisplayCount =
        widget.calendar.monthViewSettings.appointmentDisplayCount;
    final double appointmentHeight =
        (cellHeight - startPosition) / maximumDisplayCount;
    // right side padding used to add padding on appointment view right side
    // in month view
    final double cellEndPadding = CalendarViewHelper.getCellEndPadding(
      widget.calendar.cellEndPadding,
      widget.isMobilePlatform,
    );
    for (int i = 0; i < _appointmentCollection.length; i++) {
      final AppointmentView appointmentView = _appointmentCollection[i];
      if (appointmentView.canReuse || appointmentView.appointment == null) {
        continue;
      }

      if (appointmentView.position < maximumDisplayCount ||
          (appointmentView.position == maximumDisplayCount &&
              appointmentView.maxPositions == maximumDisplayCount)) {
        final double appointmentWidth =
            (appointmentView.endIndex - appointmentView.startIndex + 1) *
            cellWidth;

        if (widget.isRTL) {
          xPosition =
              (6 - (appointmentView.startIndex % DateTime.daysPerWeek)) *
              cellWidth;
          xPosition -= appointmentWidth - cellWidth;
        } else {
          xPosition =
              ((appointmentView.startIndex % DateTime.daysPerWeek) *
                  cellWidth) +
              _weekNumberPanelWidth;
        }

        yPosition =
            (appointmentView.startIndex ~/ DateTime.daysPerWeek) * cellHeight;
        if (appointmentView.position <= maximumDisplayCount) {
          yPosition =
              yPosition +
              startPosition +
              (appointmentHeight * (appointmentView.position - 1));
        } else {
          yPosition =
              yPosition +
              startPosition +
              (appointmentHeight * (maximumDisplayCount - 1));
        }

        final Radius cornerRadius = Radius.circular(
          (appointmentHeight * 0.1) > 2 ? 2 : (appointmentHeight * 0.1),
        );
        final RRect rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            widget.isRTL ? xPosition + cellEndPadding : xPosition,
            yPosition,
            appointmentWidth - cellEndPadding > 0
                ? appointmentWidth - cellEndPadding
                : 0,
            appointmentHeight > 1 ? appointmentHeight - 1 : 0,
          ),
          cornerRadius,
        );

        appointmentView.appointmentRect = rect;
      }
    }

    final List<int> keys = _indexAppointments.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      final int index = keys[i];
      final int maxPosition =
          _indexAppointments[index]!
              .reduce(
                (AppointmentView currentAppView, AppointmentView nextAppView) =>
                    currentAppView.maxPositions > nextAppView.maxPositions
                        ? currentAppView
                        : nextAppView,
              )
              .maxPositions;
      if (maxPosition <= maximumDisplayCount) {
        continue;
      }
      if (widget.isRTL) {
        xPosition = (6 - (index % DateTime.daysPerWeek)) * cellWidth;
      } else {
        xPosition =
            ((index % DateTime.daysPerWeek) * cellWidth) +
            _weekNumberPanelWidth;
      }

      yPosition =
          ((index ~/ DateTime.daysPerWeek) * cellHeight) +
          cellHeight -
          appointmentHeight;

      final RRect moreRegionRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          widget.isRTL ? xPosition + cellEndPadding : xPosition,
          yPosition,
          cellWidth - cellEndPadding > 0 ? cellWidth - cellEndPadding : 0,
          appointmentHeight - 1,
        ),
        Radius.zero,
      );

      _monthAppointmentCountViews[index] = moreRegionRect;
    }
  }

  void _updateDayAppointmentDetails(
    List<CalendarAppointment> visibleAppointments,
  ) {
    final double timeLabelWidth = CalendarViewHelper.getTimeLabelWidth(
      widget.calendar.timeSlotViewSettings.timeRulerSize,
      widget.view,
    );
    final double width = widget.width - timeLabelWidth;
    AppointmentHelper.setAppointmentPositionAndMaxPosition(
      _appointmentCollection,
      widget.calendar,
      widget.view,
      visibleAppointments,
      false,
    );
    final int count = widget.visibleDates.length;
    final double cellWidth = width / count;
    final double cellHeight = widget.timeIntervalHeight;
    double xPosition = timeLabelWidth;
    final double cellEndPadding = CalendarViewHelper.getCellEndPadding(
      widget.calendar.cellEndPadding,
      widget.isMobilePlatform,
    );

    final int timeInterval = CalendarViewHelper.getTimeInterval(
      widget.calendar.timeSlotViewSettings,
    );
    final int viewStartHour =
        widget.calendar.timeSlotViewSettings.startHour.toInt();
    final double viewStartMinutes =
        (widget.calendar.timeSlotViewSettings.startHour - viewStartHour) * 60;

    // SF-15 (Nestify): precompute the cascade horizontal boxes once per layout
    // pass. In laneFill mode this returns an empty map immediately, so the loop
    // below falls through to the byte-identical SF-6 lane path with no overhead.
    final Map<AppointmentView, CascadeBox> cascadeBoxes = _buildCascadeBoxes(
      count,
    );

    for (int i = 0; i < _appointmentCollection.length; i++) {
      final AppointmentView appointmentView = _appointmentCollection[i];
      if (appointmentView.canReuse || appointmentView.appointment == null) {
        continue;
      }

      final CalendarAppointment appointment = appointmentView.appointment!;
      int column = -1;

      for (int j = 0; j < count; j++) {
        final DateTime date = widget.visibleDates[j];
        if (isSameDate(date, appointment.actualStartTime)) {
          column = widget.isRTL ? count - 1 - j : j;
          break;
        }
      }

      if (column == -1 ||
          appointment.isSpanned ||
          AppointmentHelper.getDifference(
                appointment.startTime,
                appointment.endTime,
              ).inDays >
              0 ||
          appointment.isAllDay) {
        continue;
      }

      final int totalHours = appointment.actualStartTime.hour - viewStartHour;
      final double mins = appointment.actualStartTime.minute - viewStartMinutes;
      final int totalMins = ((totalHours * 60) + mins).toInt();

      // SF-6 (Nestify): lane 扩展。当 maxPositions <= 1 时跳过扫描，
      // 数学回落到上游 (cellWidth - cellEndPadding) / maxPositions 与
      // column * cellWidth + position * unitWidth 表达式，byte-identical。
      // maxPositions > 1 时按自身时间段实际占用的相邻 lane 收紧/扩展。
      final double unitWidth =
          (cellWidth - cellEndPadding) / appointmentView.maxPositions;
      final CascadeBox? cascadeBox = cascadeBoxes[appointmentView];
      late final double appointmentWidth;
      if (cascadeBox != null) {
        // SF-15 (Nestify) cascade branch: a single regular rect per
        // appointment, with its width and x-offset taken from CascadeLayout's
        // z-batch overlay geometry. Mutually exclusive with SF-6 lane
        // extension, so it deliberately skips _computeDayAppointmentLaneExtent.
        final double content = cellWidth - cellEndPadding;
        double width = cascadeBox.widthFraction * content;
        // OQ-3 (SF-15): readability floor, tuned on-device in T6. Never widens
        // past the day-column content, and stays inactive for the §0.3 baseline
        // whose widths are far above the floor.
        if (content > CascadeLayout.kCascadeMinReadableWidth &&
            width < CascadeLayout.kCascadeMinReadableWidth) {
          width = CascadeLayout.kCascadeMinReadableWidth;
        }
        appointmentWidth = width;
        if (widget.isRTL) {
          final double mirroredLeft =
              1 - cascadeBox.leftFraction - cascadeBox.widthFraction;
          xPosition =
              column * cellWidth + (mirroredLeft * content) + cellEndPadding;
        } else {
          xPosition =
              column * cellWidth +
              (cascadeBox.leftFraction * content) +
              timeLabelWidth;
        }
      } else {
        int leftLane = appointmentView.position;
        int rightLane = appointmentView.position;
        if (appointmentView.maxPositions > 1) {
          final List<int> extent = _computeDayAppointmentLaneExtent(
            appointmentView,
            appointment,
          );
          leftLane = extent[0];
          rightLane = extent[1];
        }
        final int laneSpan = rightLane - leftLane + 1;
        appointmentWidth = laneSpan * unitWidth;
        if (widget.isRTL) {
          xPosition =
              column * cellWidth +
              ((appointmentView.maxPositions - 1 - rightLane) * unitWidth) +
              cellEndPadding;
        } else {
          xPosition =
              column * cellWidth + (leftLane * unitWidth) + timeLabelWidth;
        }
      }

      Duration difference = AppointmentHelper.getDifference(
        appointment.actualStartTime,
        appointment.actualEndTime,
      );
      final double minuteHeight = cellHeight / timeInterval;
      double yPosition = totalMins * minuteHeight;
      double height = difference.inMinutes * minuteHeight;
      if (widget.calendar.timeSlotViewSettings.minimumAppointmentDuration !=
              null &&
          widget
                  .calendar
                  .timeSlotViewSettings
                  .minimumAppointmentDuration!
                  .inMinutes >
              0) {
        if (difference <
                widget
                    .calendar
                    .timeSlotViewSettings
                    .minimumAppointmentDuration! &&
            difference.inMinutes * minuteHeight <
                widget.calendar.timeSlotViewSettings.timeIntervalHeight) {
          difference =
              widget.calendar.timeSlotViewSettings.minimumAppointmentDuration!;
          height = difference.inMinutes * minuteHeight;
          //// Check the minimum appointment duration height does not greater than time interval height.
          if (height >
              widget.calendar.timeSlotViewSettings.timeIntervalHeight) {
            height = widget.calendar.timeSlotViewSettings.timeIntervalHeight;
          }
        }
      }

      if (yPosition + height <= 0) {
        /// Skip the appointment rendering while the whole appointment placed
        /// before calendar start time.(Eg., appointment start and end date as
        /// 4 AM to 6 AM and the calendar start time is 8 AM then skip the
        /// rendering).
        continue;
      } else if (yPosition > widget.height) {
        /// Skip the appointment rendering while the whole appointment placed
        /// after calendar end time.(Eg., appointment start and end date as
        /// 8 PM to 9 PM and the calendar end time is 6 PM then skip the
        /// rendering).
        continue;
      }

      if (yPosition < 0 && yPosition + height > widget.height) {
        /// Change the start position and height when appointment start time
        /// before the calendar start time and appointment end time after the
        /// calendar end time.(Eg., appointment start and end date as 6 AM to
        /// 9 PM and the calendar start time is 8 AM and end time is 6 PM then
        /// calculate the new size from 8 AM to 6 MM, if we does not calculate
        /// the new size then the appointment text drawn on hidden place).
        height = widget.height;
        yPosition = 0;
      } else if (yPosition + height > widget.height) {
        /// Change the height when appointment end time greater than calendar
        /// time slot end time(Eg., calendar end time is 4 PM and appointment
        /// end time is 6 PM then it takes more space and it hides span icon
        /// when the appointment is spanned)
        height = widget.height - yPosition;
      } else if (yPosition < 0) {
        /// Change the start position and height when appointment start time
        /// before the calendar start time and appointment end time after the
        /// calendar start time.(Eg., appointment start and end date as
        /// 6 AM to 9 AM and the calendar start time is 8 AM then calculate the
        /// new size from 8 AM to 9 AM, if we does not calculate the new size
        /// then the appointment text drawn on hidden place).
        height += yPosition;
        yPosition = 0;
      }

      final Radius cornerRadius = Radius.circular(
        (height * 0.1) > 2 ? 2 : (height * 0.1),
      );
      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          xPosition,
          yPosition,
          appointmentWidth > 1 ? appointmentWidth - 1 : 0,
          height > 1 ? height - 1 : 0,
        ),
        cornerRadius,
      );
      appointmentView.appointmentRect = rect;
    }
  }

  /// SF-15 (Nestify): collect the eligible timed day/week/workWeek appointment
  /// views and resolve their cascade horizontal boxes via [CascadeLayout].
  ///
  /// Returns an empty (cheap, unscanned) map unless the calendar opted into
  /// [AppointmentOverlapMode.cascade]; the laneFill path then stays
  /// byte-identical to SF-6.
  Map<AppointmentView, CascadeBox> _buildCascadeBoxes(int count) {
    if (widget.calendar.appointmentOverlapMode !=
        AppointmentOverlapMode.cascade) {
      return const <AppointmentView, CascadeBox>{};
    }

    final List<AppointmentView> views = <AppointmentView>[];
    final List<CascadeItem> items = <CascadeItem>[];
    for (int i = 0; i < _appointmentCollection.length; i++) {
      final AppointmentView view = _appointmentCollection[i];
      if (view.canReuse || view.appointment == null) {
        continue;
      }
      final CalendarAppointment appointment = view.appointment!;
      // Column scan mirrors the main render loop; kept inline (instead of
      // shared) so the SF-6 fallback path can stay byte-identical.
      int column = -1;
      for (int j = 0; j < count; j++) {
        final DateTime date = widget.visibleDates[j];
        if (isSameDate(date, appointment.actualStartTime)) {
          column = widget.isRTL ? count - 1 - j : j;
          break;
        }
      }
      if (!CascadeLayout.isEligibleTimedAppointment(appointment, column)) {
        continue;
      }
      views.add(view);
      items.add(
        CascadeItem(
          start: appointment.actualStartTime,
          end: appointment.actualEndTime,
          position: view.position,
          maxPositions: view.maxPositions,
        ),
      );
    }

    final List<CascadeBox?> boxes = CascadeLayout.resolve(
      widget.calendar.appointmentOverlapMode,
      items,
    );
    final Map<AppointmentView, CascadeBox> result =
        <AppointmentView, CascadeBox>{};
    for (int i = 0; i < views.length; i++) {
      final CascadeBox? box = boxes[i];
      if (box != null) {
        result[views[i]] = box;
      }
    }
    return result;
  }

  /// SF-6 (Nestify): 计算 day/week/workWeek 布局下 [view] 的有效 lane 区间
  /// `[pLeft, pRight]`，允许 rect 吸收相邻 lane 中无时间重叠的空闲区域。
  ///
  /// 严格重叠语义同 `AppointmentHelper._isIntersectingAppointmentInDayView`
  /// 的前三个分支（start-inside / end-inside / fully-spanning）；此处不需要
  /// `isTimelineMonth` / `isSameTimeSlot` 分支：`_updateDayAppointmentDetails`
  /// 入口已过滤掉 timeline / all-day / spanned appointment。
  List<int> _computeDayAppointmentLaneExtent(
    AppointmentView view,
    CalendarAppointment appointment,
  ) {
    final DateTime aStart = appointment.actualStartTime;
    final DateTime aEnd = appointment.actualEndTime;
    final int basePosition = view.position;
    final int maxPositions = view.maxPositions;

    final Set<int> blockedLanes = <int>{};
    for (int k = 0; k < _appointmentCollection.length; k++) {
      final AppointmentView other = _appointmentCollection[k];
      if (identical(other, view) ||
          other.canReuse ||
          other.appointment == null ||
          other.position < 0) {
        continue;
      }
      final CalendarAppointment otherApp = other.appointment!;
      if (!isSameDate(otherApp.actualStartTime, aStart)) {
        continue;
      }
      if (!_overlapsStrictForLaneExtent(
        aStart,
        aEnd,
        otherApp.actualStartTime,
        otherApp.actualEndTime,
      )) {
        continue;
      }
      blockedLanes.add(other.position);
    }

    int pLeft = basePosition;
    while (pLeft > 0 && !blockedLanes.contains(pLeft - 1)) {
      pLeft--;
    }
    int pRight = basePosition;
    while (pRight < maxPositions - 1 && !blockedLanes.contains(pRight + 1)) {
      pRight++;
    }
    return <int>[pLeft, pRight];
  }

  /// SF-6 (Nestify): 时间重叠判定（标准半开区间 [start, end) overlap）。
  ///
  /// 覆盖范围**必须**至少与 `AppointmentHelper._isIntersectingAppointmentInDayView`
  /// 一致——后者除前三个 strict 分支外还含 `isSameTimeSlot` 边界检查，会把
  /// 「相同 start 或 end 的精确边界对」也算作 intersecting 并分到不同 lane。
  ///
  /// 早期版本只镜像三个 strict 分支，漏掉相同 start/end 情形：导致 V 误判
  /// 邻 lane 的 O 不与之重叠 → 扩展到 O 占用的 lane，引发视图重叠（issue #1699
  /// regression）。标准公式 `aStart < bEnd && bStart < aEnd` 一次性覆盖：
  /// 相同 start、相同 end、包含、被包含、相互错开；back-to-back（A.end == B.start）
  /// 仍判为不重叠，与 Syncfusion 期望一致。
  bool _overlapsStrictForLaneExtent(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  void _updateTimelineMonthAppointmentDetails(
    List<CalendarAppointment> visibleAppointments,
  ) {
    final bool isResourceEnabled = CalendarViewHelper.isResourceEnabled(
      widget.calendar.dataSource,
      widget.view,
    );

    /// Filters the appointment for each resource from the visible appointment
    /// collection, and assign appointment views for all the collections.
    if (isResourceEnabled) {
      for (int i = 0; i < widget.calendar.dataSource!.resources!.length; i++) {
        final CalendarResource resource =
            widget.calendar.dataSource!.resources![i];

        /// Filters the appointment for each resource from the visible
        /// appointment collection.
        final List<CalendarAppointment> appointmentForEachResource =
            visibleAppointments
                .where(
                  (CalendarAppointment app) =>
                      app.resourceIds != null &&
                      app.resourceIds!.isNotEmpty &&
                      app.resourceIds!.contains(resource.id),
                )
                .toList();
        AppointmentHelper.setAppointmentPositionAndMaxPosition(
          _appointmentCollection,
          widget.calendar,
          widget.view,
          appointmentForEachResource,
          false,
          i,
        );
      }
    } else {
      AppointmentHelper.setAppointmentPositionAndMaxPosition(
        _appointmentCollection,
        widget.calendar,
        widget.view,
        visibleAppointments,
        false,
      );
    }

    final int visibleDatesLength = widget.visibleDates.length;
    final double viewWidth = widget.width / visibleDatesLength;
    final double cellWidth = widget.timeIntervalHeight;
    double xPosition = 0;
    double yPosition = 0;
    final double cellEndPadding = CalendarViewHelper.getCellEndPadding(
      widget.calendar.cellEndPadding,
      widget.isMobilePlatform,
    );
    final double slotHeight =
        isResourceEnabled ? widget.resourceItemHeight! : widget.height;
    final double timelineAppointmentHeight = _getTimelineAppointmentHeight(
      widget.calendar.timeSlotViewSettings,
      widget.view,
    );
    for (int i = 0; i < _appointmentCollection.length; i++) {
      final AppointmentView appointmentView = _appointmentCollection[i];
      if (appointmentView.canReuse || appointmentView.appointment == null) {
        continue;
      }

      final CalendarAppointment appointment = appointmentView.appointment!;
      int column = -1;

      final DateTime startTime = appointment.actualStartTime;
      int index = DateTimeHelper.getVisibleDateIndex(
        widget.visibleDates,
        startTime,
      );
      if (index == -1 && startTime.isBefore(widget.visibleDates[0])) {
        index = 0;
      }

      column = widget.isRTL ? visibleDatesLength - 1 - index : index;

      /// For timeline day, week and work week view each column represents a
      /// time slots for timeline month each column represent a day, and as
      /// rendering wise the column here represents the day hence the `-1`
      /// added in the above calculation not required for timeline month view,
      /// hence to rectify this we have added +1.
      if (widget.isRTL) {
        column += 1;
      }

      double appointmentHeight = timelineAppointmentHeight;
      if (appointmentHeight * appointmentView.maxPositions > slotHeight) {
        appointmentHeight = slotHeight / appointmentView.maxPositions;
      }

      xPosition = column * viewWidth;
      yPosition = appointmentHeight * appointmentView.position;
      if (isResourceEnabled &&
          appointment.resourceIds != null &&
          appointment.resourceIds!.isNotEmpty) {
        /// To render the appointment on specific resource slot, we have got the
        /// appointment's resource index  and calculated y position based on
        /// this.
        yPosition += appointmentView.resourceIndex * widget.resourceItemHeight!;
      }

      final DateTime endTime = appointment.actualEndTime;
      final Duration difference = AppointmentHelper.getDifference(
        startTime,
        endTime,
      );

      /// The width for the appointment UI, calculated based on the date
      /// difference between the start and end time of the appointment.
      double width = (difference.inDays + 1) * cellWidth;

      /// Handles multi-span appointments that fall within the same month.
      /// If the end date includes any partial time periods beyond full days,
      /// the remaining time is calculated and used to extend the appointment
      /// rendering into the next day by adding an additional width for an appointment.
      /// Example Case:
      /// Start: 2025-01-01 02:00
      /// End:   2025-01-04 01:00
      /// Total Duration: 71 hours
      /// - Remaining Time: 71 hours % 24 = 23 hours.
      /// - The remaining time beyond full days includes hours, minutes, and seconds.
      /// - Adds an extra width for partial durations to ensure the appointment renders correctly.
      final DateTime exactStartTime = appointment.exactStartTime;
      final DateTime exactEndTime = appointment.exactEndTime;
      final bool isSameHour = exactStartTime.hour == exactEndTime.hour;
      final bool isMultiDaySpanWithinSameMonth =
          exactStartTime.year == exactEndTime.year &&
          exactStartTime.month == exactEndTime.month &&
          (exactStartTime.hour > exactEndTime.hour ||
              (isSameHour && exactStartTime.minute > exactEndTime.minute) ||
              (isSameHour &&
                  exactStartTime.minute == exactEndTime.minute &&
                  exactStartTime.second > exactEndTime.second)) &&
          difference.inSeconds % (24 * 60 * 60) > 0;

      /// For span appointment less than 23 hours the difference will fall
      /// as 0 hence to render the appointment on the next day, added one
      /// the width for next day.
      final bool isSingleDaySpan =
          difference.inDays == 0 && endTime.day != startTime.day;

      if (isSingleDaySpan || isMultiDaySpanWithinSameMonth) {
        width += cellWidth;
      }

      width = width - cellEndPadding;
      final Radius cornerRadius = Radius.circular(
        (appointmentHeight * 0.1) > 2 ? 2 : (appointmentHeight * 0.1),
      );
      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          widget.isRTL ? xPosition - width : xPosition,
          yPosition,
          width > 0 ? width : 0,
          appointmentHeight > 1 ? appointmentHeight - 1 : 0,
        ),
        cornerRadius,
      );
      appointmentView.appointmentRect = rect;
    }
  }

  void _updateTimelineAppointmentDetails(
    List<CalendarAppointment> visibleAppointments,
  ) {
    final bool isResourceEnabled = CalendarViewHelper.isResourceEnabled(
      widget.calendar.dataSource,
      widget.view,
    );

    /// Filters the appointment for each resource from the visible appointment
    /// collection, and assign appointment views for all the collections.
    if (isResourceEnabled) {
      for (int i = 0; i < widget.calendar.dataSource!.resources!.length; i++) {
        final CalendarResource resource =
            widget.calendar.dataSource!.resources![i];

        /// Filters the appointment for each resource from the visible
        /// appointment collection.
        final List<CalendarAppointment> appointmentForEachResource =
            visibleAppointments
                .where(
                  (CalendarAppointment app) =>
                      app.resourceIds != null &&
                      app.resourceIds!.isNotEmpty &&
                      app.resourceIds!.contains(resource.id),
                )
                .toList();
        AppointmentHelper.setAppointmentPositionAndMaxPosition(
          _appointmentCollection,
          widget.calendar,
          widget.view,
          appointmentForEachResource,
          false,
          i,
        );
      }
    } else {
      AppointmentHelper.setAppointmentPositionAndMaxPosition(
        _appointmentCollection,
        widget.calendar,
        widget.view,
        visibleAppointments,
        false,
      );
    }

    final int count = widget.visibleDates.length;
    final double viewWidth = widget.width / count;
    final double cellWidth = widget.timeIntervalHeight;
    double xPosition = 0;
    double yPosition = 0;
    final int timeInterval = CalendarViewHelper.getTimeInterval(
      widget.calendar.timeSlotViewSettings,
    );
    final double cellEndPadding = CalendarViewHelper.getCellEndPadding(
      widget.calendar.cellEndPadding,
      widget.isMobilePlatform,
    );
    final int viewStartHour =
        widget.calendar.timeSlotViewSettings.startHour.toInt();
    final double viewStartMinutes =
        (widget.calendar.timeSlotViewSettings.startHour - viewStartHour) * 60;
    final double timelineAppointmentHeight = _getTimelineAppointmentHeight(
      widget.calendar.timeSlotViewSettings,
      widget.view,
    );
    final double slotHeight =
        isResourceEnabled
            ? widget.resourceItemHeight! - cellEndPadding
            : widget.height - cellEndPadding;
    for (int i = 0; i < _appointmentCollection.length; i++) {
      final AppointmentView appointmentView = _appointmentCollection[i];
      if (appointmentView.canReuse || appointmentView.appointment == null) {
        continue;
      }

      final CalendarAppointment appointment = appointmentView.appointment!;
      int column = -1;

      DateTime startTime = appointment.actualStartTime;
      for (int j = 0; j < count; j++) {
        final DateTime date = widget.visibleDates[j];
        if (isSameDate(date, startTime)) {
          column = j;
          break;
        } else if (startTime.isBefore(date)) {
          column = j;
          startTime = DateTime(date.year, date.month, date.day);
          break;
        }
      }

      if (column == -1 &&
          appointment.actualStartTime.isBefore(widget.visibleDates[0])) {
        column = 0;
      }

      DateTime endTime = appointment.actualEndTime;
      int endColumn = -1;
      for (int j = 0; j < count; j++) {
        DateTime date = widget.visibleDates[j];
        if (isSameDate(date, endTime)) {
          endColumn = j;
          break;
        } else if (endTime.isBefore(date)) {
          endColumn = j - 1;
          if (endColumn != -1) {
            date = widget.visibleDates[endColumn];
            endTime = DateTime(date.year, date.month, date.day, 23, 59, 59);
          }
          break;
        }
      }

      final DateTime visibleEndDate = widget.visibleDates[count - 1];
      if (endColumn == -1 &&
          appointment.actualEndTime.isAfter(visibleEndDate)) {
        endColumn = count - 1;

        /// Assign the end date time value to visible end date and time value
        /// when the appointment end date value after the visible end date
        /// value.
        endTime = DateTime(
          visibleEndDate.year,
          visibleEndDate.month,
          visibleEndDate.day,
          23,
          59,
          59,
        );
      }

      if (column == -1 || endColumn == -1) {
        continue;
      }

      int totalMinutes =
          (((startTime.hour - viewStartHour) * 60) +
                  (startTime.minute - viewStartMinutes))
              .toInt();

      final double minuteHeight = cellWidth / timeInterval;

      double appointmentHeight = timelineAppointmentHeight;
      if (appointmentHeight * appointmentView.maxPositions > slotHeight) {
        appointmentHeight = slotHeight / appointmentView.maxPositions;
      }

      xPosition = column * viewWidth;
      double timePosition = totalMinutes * minuteHeight;
      if (timePosition < 0) {
        timePosition = 0;
      } else if (timePosition > viewWidth) {
        timePosition = viewWidth;
      }

      xPosition += timePosition;
      yPosition = appointmentHeight * appointmentView.position;
      if (isResourceEnabled &&
          appointment.resourceIds != null &&
          appointment.resourceIds!.isNotEmpty) {
        /// To render the appointment on specific resource slot, we have got the
        /// appointment's resource index  and calculated y position based on
        /// this.
        yPosition += appointmentView.resourceIndex * widget.resourceItemHeight!;
      }

      totalMinutes =
          (((endTime.hour - viewStartHour) * 60) +
                  (endTime.minute - viewStartMinutes))
              .toInt();
      double endXPosition = endColumn * viewWidth;
      timePosition = totalMinutes * minuteHeight;
      if (timePosition < 0) {
        timePosition = 0;
      } else if (timePosition > viewWidth) {
        timePosition = viewWidth;
      }

      endXPosition += timePosition;
      double width = endXPosition - xPosition;
      xPosition = widget.isRTL ? widget.width - xPosition : xPosition;

      if (widget.calendar.timeSlotViewSettings.minimumAppointmentDuration !=
              null &&
          widget.calendar.timeSlotViewSettings.minimumAppointmentDuration! >
              AppointmentHelper.getDifference(
                appointment.actualStartTime,
                appointment.actualEndTime,
              )) {
        final double minWidth =
            AppointmentHelper.getAppointmentHeightFromDuration(
              widget.calendar.timeSlotViewSettings.minimumAppointmentDuration,
              widget.calendar,
              widget.timeIntervalHeight,
            );
        width = width > minWidth ? width : minWidth;
      }

      final Radius cornerRadius = Radius.circular(
        (appointmentHeight * 0.1) > 2 ? 2 : (appointmentHeight * 0.1),
      );
      width = width > 1 ? width - 1 : 0;
      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          widget.isRTL ? xPosition - width : xPosition,
          yPosition,
          width,
          appointmentHeight > 1 ? appointmentHeight - 1 : 0,
        ),
        cornerRadius,
      );
      appointmentView.appointmentRect = rect;
    }
  }

  /// Returns the  timeline appointment height based on the settings value.
  double _getTimelineAppointmentHeight(
    TimeSlotViewSettings settings,
    CalendarView view,
  ) {
    if (settings.timelineAppointmentHeight != -1) {
      return settings.timelineAppointmentHeight;
    }

    if (view == CalendarView.timelineMonth) {
      return 25;
    }

    return 60;
  }
}

class _AppointmentRenderWidget extends MultiChildRenderObjectWidget {
  const _AppointmentRenderWidget(
    this.calendar,
    this.view,
    this.visibleDates,
    this.visibleAppointments,
    this.timeIntervalHeight,
    this.calendarTheme,
    this.themeData,
    this.isRTL,
    this.appointmentHoverPosition,
    this.resourceCollection,
    this.resourceItemHeight,
    this.textScaleFactor,
    this.isMobilePlatform,
    this.width,
    this.height,
    this.localizations,
    this.appointmentCollection,
    this.indexAppointments,
    this.monthAppointmentCountViews,
    this.weekNumberPanelWidth, {
    List<Widget> widgets = const <Widget>[],
  }) : super(children: widgets);

  final SfCalendar calendar;
  final double weekNumberPanelWidth;
  final CalendarView view;
  final List<DateTime> visibleDates;
  final double timeIntervalHeight;
  final bool isRTL;
  final SfCalendarThemeData calendarTheme;
  final ThemeData themeData;
  final ValueNotifier<Offset?> appointmentHoverPosition;
  final List<CalendarResource>? resourceCollection;
  final double? resourceItemHeight;
  final double textScaleFactor;
  final bool isMobilePlatform;
  final double width;
  final double height;
  final SfLocalizations localizations;
  final List<CalendarAppointment>? visibleAppointments;
  final List<AppointmentView> appointmentCollection;
  final Map<int, List<AppointmentView>> indexAppointments;
  final Map<int, RRect> monthAppointmentCountViews;

  @override
  _AppointmentRenderObject createRenderObject(BuildContext context) {
    return _AppointmentRenderObject(
      calendar,
      view,
      visibleDates,
      visibleAppointments,
      timeIntervalHeight,
      calendarTheme,
      themeData,
      isRTL,
      appointmentHoverPosition,
      resourceCollection,
      resourceItemHeight,
      textScaleFactor,
      isMobilePlatform,
      width,
      height,
      localizations,
      appointmentCollection,
      indexAppointments,
      monthAppointmentCountViews,
      weekNumberPanelWidth,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _AppointmentRenderObject renderObject,
  ) {
    renderObject
      ..calendar = calendar
      ..view = view
      ..visibleDates = visibleDates
      ..visibleAppointments = visibleAppointments
      ..timeIntervalHeight = timeIntervalHeight
      ..calendarTheme = calendarTheme
      ..themeData = themeData
      ..isRTL = isRTL
      ..appointmentHoverPosition = appointmentHoverPosition
      ..resourceCollection = resourceCollection
      ..resourceItemHeight = resourceItemHeight
      ..textScaleFactor = textScaleFactor
      ..isMobilePlatform = isMobilePlatform
      ..width = width
      ..height = height
      ..localizations = localizations
      ..appointmentCollection = appointmentCollection
      ..indexAppointments = indexAppointments
      ..monthAppointmentCountViews = monthAppointmentCountViews
      ..weekNumberPanelWidth = weekNumberPanelWidth;
  }
}

class _AppointmentRenderObject extends CustomCalendarRenderObject {
  _AppointmentRenderObject(
    this._calendar,
    this._view,
    this._visibleDates,
    this._visibleAppointments,
    this._timeIntervalHeight,
    this._calendarTheme,
    this._themeData,
    this._isRTL,
    this._appointmentHoverPosition,
    this._resourceCollection,
    this._resourceItemHeight,
    this._textScaleFactor,
    this.isMobilePlatform,
    this._width,
    this._height,
    this._localizations,
    this.appointmentCollection,
    this.indexAppointments,
    this.monthAppointmentCountViews,
    this._weekNumberPanelWidth,
  );

  List<CalendarAppointment>? _visibleAppointments;

  List<CalendarAppointment>? get visibleAppointments => _visibleAppointments;

  set visibleAppointments(List<CalendarAppointment>? value) {
    if (CalendarViewHelper.isCollectionEqual(_visibleAppointments, value)) {
      return;
    }

    _visibleAppointments = value;
    if (childCount == 0) {
      markNeedsPaint();
    } else {
      markNeedsLayout();
    }
  }

  ValueNotifier<Offset?> _appointmentHoverPosition;

  ValueNotifier<Offset?> get appointmentHoverPosition =>
      _appointmentHoverPosition;

  set appointmentHoverPosition(ValueNotifier<Offset?> value) {
    if (_appointmentHoverPosition == value) {
      return;
    }

    _appointmentHoverPosition.removeListener(markNeedsPaint);
    _appointmentHoverPosition = value;
    _appointmentHoverPosition.addListener(markNeedsPaint);
  }

  double _weekNumberPanelWidth;

  double get weekNumberPanelWidth => _weekNumberPanelWidth;

  set weekNumberPanelWidth(double value) {
    if (_weekNumberPanelWidth == value) {
      return;
    }

    _weekNumberPanelWidth = value;
    if (childCount == 0) {
      markNeedsPaint();
    } else {
      markNeedsLayout();
    }
  }

  double _timeIntervalHeight;

  double get timeIntervalHeight => _timeIntervalHeight;

  set timeIntervalHeight(double value) {
    if (_timeIntervalHeight == value) {
      return;
    }

    _timeIntervalHeight = value;
    markNeedsLayout();
  }

  double _width;

  double get width => _width;

  set width(double value) {
    if (_width == value) {
      return;
    }

    _width = value;
    markNeedsLayout();
  }

  double _height;

  double get height => _height;

  set height(double value) {
    if (_height == value) {
      return;
    }

    _height = value;
    markNeedsLayout();
  }

  SfLocalizations _localizations;

  SfLocalizations get localizations => _localizations;

  set localizations(SfLocalizations value) {
    if (_localizations == value) {
      return;
    }

    _localizations = value;
    if (childCount != 0) {
      return;
    }

    markNeedsPaint();
  }

  double _textScaleFactor;

  double get textScaleFactor => _textScaleFactor;

  set textScaleFactor(double value) {
    if (_textScaleFactor == value) {
      return;
    }

    _textScaleFactor = value;
    markNeedsPaint();
  }

  SfCalendarThemeData _calendarTheme;

  SfCalendarThemeData get calendarTheme => _calendarTheme;

  set calendarTheme(SfCalendarThemeData value) {
    if (_calendarTheme == value) {
      return;
    }

    _calendarTheme = value;
    if (childCount != 0) {
      return;
    }

    markNeedsPaint();
  }

  ThemeData _themeData;

  ThemeData get themeData => _themeData;

  set themeData(ThemeData value) {
    if (_themeData == value) {
      return;
    }

    _themeData = value;
  }

  List<DateTime> _visibleDates;

  List<DateTime> get visibleDates => _visibleDates;

  set visibleDates(List<DateTime> value) {
    if (_visibleDates == value) {
      return;
    }

    _visibleDates = value;
    if (childCount == 0) {
      markNeedsPaint();
    } else {
      markNeedsLayout();
    }
  }

  bool _isRTL;

  bool get isRTL => _isRTL;

  set isRTL(bool value) {
    if (_isRTL == value) {
      return;
    }

    _isRTL = value;
    markNeedsPaint();
  }

  double? _resourceItemHeight;

  double? get resourceItemHeight => _resourceItemHeight;

  set resourceItemHeight(double? value) {
    if (_resourceItemHeight == value) {
      return;
    }

    _resourceItemHeight = value;
    markNeedsLayout();
  }

  List<CalendarResource>? _resourceCollection;

  List<CalendarResource>? get resourceCollection => _resourceCollection;

  set resourceCollection(List<CalendarResource>? value) {
    if (_resourceCollection == value) {
      return;
    }

    _resourceCollection = value;
    markNeedsLayout();
  }

  CalendarView _view;

  CalendarView get view => _view;

  set view(CalendarView value) {
    if (_view == value) {
      return;
    }

    _view = value;
    markNeedsLayout();
  }

  SfCalendar _calendar;

  SfCalendar get calendar => _calendar;

  set calendar(SfCalendar value) {
    if (_calendar == value) {
      return;
    }

    _calendar = value;
    markNeedsLayout();
  }

  /// attach will called when the render object rendered in view.
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _appointmentHoverPosition.addListener(markNeedsPaint);
  }

  /// detach will called when the render object removed from view.
  @override
  void detach() {
    _appointmentHoverPosition.removeListener(markNeedsPaint);
    super.detach();
  }

  bool isMobilePlatform;
  List<AppointmentView> appointmentCollection = <AppointmentView>[];
  Map<int, List<AppointmentView>> indexAppointments =
      <int, List<AppointmentView>>{};
  Map<int, RRect> monthAppointmentCountViews = <int, RRect>{};

  final Paint _appointmentPainter = Paint();
  TextPainter _textPainter = TextPainter();

  @override
  bool get isRepaintBoundary => true;

  @override
  List<CustomPainterSemantics> Function(Size size) get semanticsBuilder =>
      _getSemanticsBuilder;

  List<CustomPainterSemantics> _getSemanticsBuilder(Size size) {
    final List<CustomPainterSemantics> semanticsBuilder =
        <CustomPainterSemantics>[];

    final RenderBox? child = firstChild;
    if (child != null) {
      return semanticsBuilder;
    }

    if (appointmentCollection.isEmpty) {
      return semanticsBuilder;
    }

    for (int i = 0; i < appointmentCollection.length; i++) {
      final AppointmentView appointmentView = appointmentCollection[i];
      if (appointmentView.appointment == null ||
          appointmentView.appointmentRect == null) {
        continue;
      }

      final Rect rect = appointmentView.appointmentRect!.outerRect;
      if (rect.height <= 0 || rect.width <= 0) {
        continue;
      }

      semanticsBuilder.add(
        CustomPainterSemantics(
          rect: rect,
          properties: SemanticsProperties(
            label: CalendarViewHelper.getAppointmentSemanticsText(
              appointmentView.appointment!,
            ),
            textDirection: TextDirection.ltr,
          ),
        ),
      );
    }

    if (view != CalendarView.month ||
        calendar.monthViewSettings.appointmentDisplayMode !=
            MonthAppointmentDisplayMode.appointment) {
      return semanticsBuilder;
    }

    final List<int> keys = monthAppointmentCountViews.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      final RRect moreRegionRect = monthAppointmentCountViews[keys[i]]!;
      final Rect rect = moreRegionRect.outerRect;
      if (rect.height <= 0 || rect.width <= 0) {
        continue;
      }

      semanticsBuilder.add(
        CustomPainterSemantics(
          rect: rect,
          properties: const SemanticsProperties(
            label: 'More',
            textDirection: TextDirection.ltr,
          ),
        ),
      );
    }

    return semanticsBuilder;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    RenderBox? child = firstChild;
    if (child == null) {
      return;
    }
    while (child != null) {
      visitor(child);
      child = childAfter(child);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = firstChild;
    if (child == null) {
      return false;
    }

    for (int i = 0; i < appointmentCollection.length; i++) {
      final AppointmentView appointmentView = appointmentCollection[i];
      if (appointmentView.appointment == null ||
          child == null ||
          appointmentView.appointmentRect == null) {
        continue;
      }

      final Offset offset = Offset(
        appointmentView.appointmentRect!.left,
        appointmentView.appointmentRect!.top,
      );
      final bool isHit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset? transformed) {
          assert(transformed == position - offset);
          return child!.hitTest(result, position: transformed!);
        },
      );
      if (isHit) {
        return true;
      }
      child = childAfter(child);
    }

    if (view != CalendarView.month ||
        calendar.monthViewSettings.appointmentDisplayMode !=
            MonthAppointmentDisplayMode.appointment) {
      return false;
    }

    final List<int> keys = monthAppointmentCountViews.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      if (child == null) {
        continue;
      }

      final RRect moreRegionRect = monthAppointmentCountViews[keys[i]]!;
      final Offset offset = Offset(moreRegionRect.left, moreRegionRect.top);
      final bool isHit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset? transformed) {
          assert(transformed == position - offset);
          return child!.hitTest(result, position: transformed!);
        },
      );
      if (isHit) {
        return true;
      }
      child = childAfter(child);
    }

    return false;
  }

  @override
  void performLayout() {
    final Size widgetSize = constraints.biggest;
    size = Size(
      widgetSize.width.isInfinite ? width : widgetSize.width,
      widgetSize.height.isInfinite ? height : widgetSize.height,
    );
    RenderBox? child = firstChild;
    for (int i = 0; i < appointmentCollection.length; i++) {
      final AppointmentView appointmentView = appointmentCollection[i];
      if (appointmentView.appointment == null ||
          child == null ||
          appointmentView.appointmentRect == null) {
        continue;
      }

      child.layout(
        constraints.copyWith(
          minHeight: appointmentView.appointmentRect!.height,
          maxHeight: appointmentView.appointmentRect!.height,
          minWidth: appointmentView.appointmentRect!.width,
          maxWidth: appointmentView.appointmentRect!.width,
        ),
      );
      final CalendarParentData childParentData =
          child.parentData! as CalendarParentData;
      childParentData.offset = Offset(
        appointmentView.appointmentRect!.left,
        appointmentView.appointmentRect!.top,
      );
      child = childAfter(child);
    }

    if (view != CalendarView.month ||
        calendar.monthViewSettings.appointmentDisplayMode !=
            MonthAppointmentDisplayMode.appointment) {
      return;
    }

    final List<int> keys = monthAppointmentCountViews.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      if (child == null) {
        continue;
      }

      final RRect moreRegionRect = monthAppointmentCountViews[keys[i]]!;
      child.layout(
        constraints.copyWith(
          minHeight: moreRegionRect.height,
          maxHeight: moreRegionRect.height,
          minWidth: moreRegionRect.width,
          maxWidth: moreRegionRect.width,
        ),
      );

      final CalendarParentData childParentData =
          child.parentData! as CalendarParentData;
      childParentData.offset = Offset(moreRegionRect.left, moreRegionRect.top);
      child = childAfter(child);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    final bool isNeedDefaultPaint = childCount == 0;
    if (isNeedDefaultPaint) {
      _drawCustomAppointmentView(context.canvas);
    } else {
      for (int i = 0; i < appointmentCollection.length; i++) {
        final AppointmentView appointmentView = appointmentCollection[i];
        if (appointmentView.appointment == null ||
            child == null ||
            appointmentView.appointmentRect == null) {
          continue;
        }

        context.paintChild(
          child,
          Offset(
            appointmentView.appointmentRect!.left,
            appointmentView.appointmentRect!.top,
          ),
        );
        _updateAppointmentHovering(
          appointmentView.appointmentRect!,
          context.canvas,
        );

        child = childAfter(child);
      }

      if (view != CalendarView.month ||
          calendar.monthViewSettings.appointmentDisplayMode !=
              MonthAppointmentDisplayMode.appointment) {
        return;
      }

      final List<int> keys = monthAppointmentCountViews.keys.toList();
      for (int i = 0; i < keys.length; i++) {
        if (child == null) {
          continue;
        }

        final RRect moreRegionRect = monthAppointmentCountViews[keys[i]]!;
        context.paintChild(
          child,
          Offset(moreRegionRect.left, moreRegionRect.top),
        );
        _updateAppointmentHovering(moreRegionRect, context.canvas);

        child = childAfter(child);
      }
    }
  }

  void _drawCustomAppointmentView(Canvas canvas) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    _appointmentPainter.isAntiAlias = true;
    switch (view) {
      case CalendarView.month:
        {
          _drawMonthAppointment(canvas, size, _appointmentPainter);
        }
        break;
      case CalendarView.day:
      case CalendarView.week:
      case CalendarView.workWeek:
        {
          _drawDayAppointments(canvas, size, _appointmentPainter);
        }
        break;
      case CalendarView.timelineDay:
      case CalendarView.timelineWeek:
      case CalendarView.timelineWorkWeek:
      case CalendarView.timelineMonth:
        {
          _drawTimelineAppointments(canvas, size, _appointmentPainter);
        }
        break;
      case CalendarView.schedule:
        return;
    }
  }

  void _drawMonthAppointment(Canvas canvas, Size size, Paint paint) {
    final double cellWidth =
        (size.width - weekNumberPanelWidth) / DateTime.daysPerWeek;
    final double cellHeight =
        size.height / calendar.monthViewSettings.numberOfWeeksInView;

    switch (calendar.monthViewSettings.appointmentDisplayMode) {
      case MonthAppointmentDisplayMode.none:
        return;
      case MonthAppointmentDisplayMode.appointment:
        _drawMonthAppointmentView(canvas, size, cellWidth, cellHeight, paint);
        break;
      case MonthAppointmentDisplayMode.indicator:
        _drawMonthAppointmentIndicator(canvas, cellWidth, cellHeight, paint);
    }
  }

  void _drawMonthAppointmentView(
    Canvas canvas,
    Size size,
    double cellWidth,
    double cellHeight,
    Paint paint,
  ) {
    final int count = visibleDates.length;
    DateTime visibleStartDate = AppointmentHelper.convertToStartTime(
      visibleDates[0],
    );
    DateTime visibleEndDate = AppointmentHelper.convertToEndTime(
      visibleDates[count - 1],
    );
    final bool showTrailingLeadingDates =
        CalendarViewHelper.isLeadingAndTrailingDatesVisible(
          calendar.monthViewSettings.numberOfWeeksInView,
          calendar.monthViewSettings.showTrailingAndLeadingDates,
        );
    if (!showTrailingLeadingDates) {
      final DateTime currentMonthDate = visibleDates[count ~/ 2];
      visibleStartDate = AppointmentHelper.convertToStartTime(
        AppointmentHelper.getMonthStartDate(currentMonthDate),
      );
      visibleEndDate = AppointmentHelper.convertToEndTime(
        AppointmentHelper.getMonthEndDate(currentMonthDate),
      );
    }

    final int maximumDisplayCount =
        calendar.monthViewSettings.appointmentDisplayCount;
    double textSize = -1;
    // right side padding used to add padding on appointment view right side
    // in month view
    for (int i = 0; i < appointmentCollection.length; i++) {
      final AppointmentView appointmentView = appointmentCollection[i];
      if (appointmentView.canReuse ||
          appointmentView.appointment == null ||
          appointmentView.appointmentRect == null) {
        continue;
      }

      final RRect appointmentRect = appointmentView.appointmentRect!;
      if (appointmentView.position < maximumDisplayCount ||
          (appointmentView.position == maximumDisplayCount &&
              appointmentView.maxPositions == maximumDisplayCount)) {
        final CalendarAppointment appointment = appointmentView.appointment!;
        final bool canAddSpanIcon = AppointmentHelper.canAddSpanIcon(
          visibleDates,
          appointment,
          view,
          visibleStartDate: visibleStartDate,
          visibleEndDate: visibleEndDate,
          showTrailingLeadingDates: showTrailingLeadingDates,
        );

        paint.color = appointment.color;
        TextStyle style = AppointmentHelper.getAppointmentTextStyle(
          calendar.appointmentTextStyle,
          view,
          themeData,
        );
        TextSpan span = TextSpan(text: appointment.subject, style: style);
        _textPainter = _updateTextPainter(
          span,
          _textPainter,
          isRTL,
          _textScaleFactor,
        );

        if (textSize == -1) {
          //// left and right side padding value 2 subtracted in appointment width
          double maxTextWidth = appointmentRect.width - 2;
          maxTextWidth = maxTextWidth > 0 ? maxTextWidth : 0;
          for (double j = style.fontSize! - 1; j > 0; j--) {
            _textPainter.layout(maxWidth: maxTextWidth);
            if (_textPainter.height >= appointmentRect.height) {
              style = style.copyWith(fontSize: j);
              span = TextSpan(text: appointment.subject, style: style);
              _textPainter = _updateTextPainter(
                span,
                _textPainter,
                isRTL,
                _textScaleFactor,
              );
            } else {
              textSize = j + 1;
              break;
            }
          }
          if (textSize < 0) {
            textSize = 0;
          }
        } else {
          span = TextSpan(
            text: appointment.subject,
            style: style.copyWith(fontSize: textSize),
          );
          _textPainter = _updateTextPainter(
            span,
            _textPainter,
            isRTL,
            _textScaleFactor,
          );
        }

        canvas.drawRRect(appointmentRect, paint);

        final bool isRecurrenceAppointment =
            appointment.recurrenceRule != null &&
            appointment.recurrenceRule!.isNotEmpty;
        final double iconTextSize = _getTextSize(
          appointmentRect,
          _textPainter.textScaler.scale(textSize),
        );
        const double iconPadding = 2;
        //// Padding 4 is left and right 2 padding.
        final double iconSize = iconTextSize + (2 * iconPadding);
        final double recurrenceIconSize =
            isRecurrenceAppointment || appointment.recurrenceId != null
                ? iconSize
                : 0;
        double forwardSpanIconSize = 0;
        double backwardSpanIconSize = 0;

        if (canAddSpanIcon) {
          final int appStartIndex = MonthAppointmentHelper.getDateIndex(
            appointment.exactStartTime,
            visibleDates,
          );
          final int appEndIndex = MonthAppointmentHelper.getDateIndex(
            appointment.exactEndTime,
            visibleDates,
          );
          if (appStartIndex == appointmentView.startIndex &&
              appEndIndex == appointmentView.endIndex) {
            continue;
          }

          if (appStartIndex != appointmentView.startIndex &&
              appEndIndex != appointmentView.endIndex) {
            forwardSpanIconSize = iconSize;
            backwardSpanIconSize = iconSize;
          } else if (appEndIndex != appointmentView.endIndex) {
            forwardSpanIconSize = iconSize;
          } else {
            backwardSpanIconSize = iconSize;
          }
        }

        const double textPadding = 1;
        _drawSingleLineAppointmentView(
          canvas,
          appointmentRect,
          textPadding,
          style,
          textSize,
          isRecurrenceAppointment,
          recurrenceIconSize,
          forwardSpanIconSize,
          backwardSpanIconSize,
          paint,
        );
        _updateAppointmentHovering(appointmentRect, canvas);
      }
    }

    const double padding = 2;
    const double startPadding = 5;
    double? radius;

    final List<int> keys = monthAppointmentCountViews.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      final int index = keys[i];
      final RRect moreRegionRect = monthAppointmentCountViews[index]!;
      if (radius == null) {
        radius = moreRegionRect.height * 0.12;
        if (radius > 3) {
          radius = 3;
        }
      }
      double startXPosition =
          isRTL
              ? moreRegionRect.right - startPadding
              : moreRegionRect.left + startPadding;
      paint.color = Colors.grey[600]!;
      for (int j = 0; j < 3; j++) {
        canvas.drawCircle(
          Offset(
            startXPosition,
            moreRegionRect.top + (moreRegionRect.height / 2),
          ),
          radius,
          paint,
        );
        if (isRTL) {
          startXPosition -= padding + (2 * radius);
        } else {
          startXPosition += padding + (2 * radius);
        }
      }

      _updateAppointmentHovering(moreRegionRect, canvas);
    }
  }

  void _drawSingleLineAppointmentView(
    Canvas canvas,
    RRect appointmentRect,
    double textPadding,
    TextStyle style,
    double textSize,
    bool isRecurrenceAppointment,
    double recurrenceIconSize,
    double forwardSpanIconSize,
    double backwardSpanIconSize,
    Paint paint,
  ) {
    final double totalIconsWidth =
        recurrenceIconSize + forwardSpanIconSize + backwardSpanIconSize;
    final double textWidth = appointmentRect.width - totalIconsWidth;
    _textPainter.layout(
      maxWidth:
          textWidth - (2 * textPadding) > 0 ? textWidth - (2 * textPadding) : 0,
    );
    final double yPosition =
        appointmentRect.top +
        ((appointmentRect.height - _textPainter.height) / 2);
    final double xPosition =
        isRTL
            ? appointmentRect.right -
                _textPainter.width -
                backwardSpanIconSize -
                textPadding
            : appointmentRect.left + backwardSpanIconSize + textPadding;

    _textPainter.paint(canvas, Offset(xPosition, yPosition));

    if (backwardSpanIconSize != 0) {
      _drawBackwardSpanIconForMonth(
        canvas,
        style,
        textSize,
        appointmentRect,
        backwardSpanIconSize,
        appointmentRect.tlRadius,
        paint,
      );
    }

    if (recurrenceIconSize != 0) {
      _drawRecurrenceIconForMonth(
        canvas,
        style,
        textSize,
        appointmentRect,
        appointmentRect.tlRadius,
        paint,
        isRecurrenceAppointment,
        recurrenceIconSize,
        forwardSpanIconSize,
      );
    }

    if (forwardSpanIconSize != 0) {
      _drawForwardSpanIconForMonth(
        canvas,
        style,
        textSize,
        appointmentRect,
        forwardSpanIconSize,
        appointmentRect.tlRadius,
        paint,
      );
    }
  }

  void _drawForwardSpanIconForMonth(
    Canvas canvas,
    TextStyle style,
    double textSize,
    RRect rect,
    double iconSize,
    Radius cornerRadius,
    Paint paint,
  ) {
    final TextSpan icon = AppointmentHelper.getSpanIcon(
      style.color!,
      textSize,
      !isRTL,
    );
    _textPainter.text = icon;
    _textPainter.layout(maxWidth: rect.width > 0 ? rect.width : 0);

    final double yPosition = AppointmentHelper.getYPositionForSpanIcon(
      icon,
      _textPainter,
      rect,
    );
    final double xPosition = isRTL ? rect.left : rect.right - iconSize;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(xPosition, rect.top, xPosition + iconSize, rect.bottom),
        cornerRadius,
      ),
      paint,
    );
    double iconPadding = (iconSize - _textPainter.width) / 2;
    if (iconPadding < 0) {
      iconPadding = 0;
    }

    _textPainter.paint(canvas, Offset(xPosition + iconPadding, yPosition));
  }

  void _drawBackwardSpanIconForMonth(
    Canvas canvas,
    TextStyle style,
    double textSize,
    RRect rect,
    double iconSize,
    Radius cornerRadius,
    Paint paint,
  ) {
    final TextSpan icon = AppointmentHelper.getSpanIcon(
      style.color!,
      textSize,
      isRTL,
    );
    _textPainter.text = icon;
    _textPainter.layout(maxWidth: rect.width > 0 ? rect.width : 0);

    final double yPosition = AppointmentHelper.getYPositionForSpanIcon(
      icon,
      _textPainter,
      rect,
    );
    final double xPosition = isRTL ? rect.right - iconSize : rect.left;
    double iconPadding = (iconSize - _textPainter.width) / 2;
    if (iconPadding < 0) {
      iconPadding = 0;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(xPosition, rect.top, xPosition + iconSize, rect.bottom),
        cornerRadius,
      ),
      paint,
    );
    _textPainter.paint(canvas, Offset(xPosition + iconPadding, yPosition));
  }

  void _drawRecurrenceIconForMonth(
    Canvas canvas,
    TextStyle style,
    double textSize,
    RRect rect,
    Radius cornerRadius,
    Paint paint,
    bool isRecurrenceAppointment,
    double iconSize,
    double forwardSpanIconSize,
  ) {
    final TextSpan icon = AppointmentHelper.getRecurrenceIcon(
      style.color!,
      textSize,
      isRecurrenceAppointment,
    );
    _textPainter.text = icon;
    _textPainter.layout(maxWidth: rect.width > 0 ? rect.width : 0);
    final double yPosition =
        rect.top + ((rect.height - _textPainter.height) / 2);
    final double recurrenceStartPosition =
        isRTL
            ? rect.left + forwardSpanIconSize
            : rect.right - iconSize - forwardSpanIconSize;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          recurrenceStartPosition,
          yPosition,
          recurrenceStartPosition + iconSize,
          rect.bottom,
        ),
        cornerRadius,
      ),
      paint,
    );
    double iconPadding = (iconSize - _textPainter.width) / 2;
    if (iconPadding < 0) {
      iconPadding = 0;
    }

    _textPainter.paint(
      canvas,
      Offset(recurrenceStartPosition + iconPadding, yPosition),
    );
  }

  void _drawMonthAppointmentIndicator(
    Canvas canvas,
    double cellWidth,
    double cellHeight,
    Paint paint,
  ) {
    double xPosition =
        isRTL
            ? size.width - cellWidth - weekNumberPanelWidth
            : weekNumberPanelWidth;
    double yPosition = 0;
    const double radius = 2.5;
    const double diameter = radius * 2;
    final double bottomPadding =
        cellHeight * 0.2 < radius ? radius : cellHeight * 0.2;
    final int visibleDatesCount = visibleDates.length;
    final int currentMonth = visibleDates[visibleDatesCount ~/ 2].month;
    final bool showTrailingLeadingDates =
        CalendarViewHelper.isLeadingAndTrailingDatesVisible(
          calendar.monthViewSettings.numberOfWeeksInView,
          calendar.monthViewSettings.showTrailingAndLeadingDates,
        );

    for (int i = 0; i < visibleDatesCount; i++) {
      final DateTime currentVisibleDate = visibleDates[i];
      if (!showTrailingLeadingDates &&
          currentVisibleDate.month != currentMonth) {
        continue;
      }

      final List<CalendarAppointment> appointmentLists =
          AppointmentHelper.getSpecificDateVisibleAppointment(
            currentVisibleDate,
            visibleAppointments,
          );
      appointmentLists.sort(
        (CalendarAppointment app1, CalendarAppointment app2) =>
            app1.actualStartTime.compareTo(app2.actualStartTime),
      );
      appointmentLists.sort(
        (CalendarAppointment app1, CalendarAppointment app2) =>
            AppointmentHelper.orderAppointmentsAscending(
              app1.isAllDay,
              app2.isAllDay,
            ),
      );
      appointmentLists.sort(
        (CalendarAppointment app1, CalendarAppointment app2) =>
            AppointmentHelper.orderAppointmentsAscending(
              app1.isSpanned,
              app2.isSpanned,
            ),
      );
      final int count =
          appointmentLists.length <=
                  calendar.monthViewSettings.appointmentDisplayCount
              ? appointmentLists.length
              : calendar.monthViewSettings.appointmentDisplayCount;
      const double indicatorPadding = 2;
      final double indicatorWidth =
          count * diameter + (count - 1) * indicatorPadding;
      if (indicatorWidth > cellWidth) {
        xPosition = indicatorPadding + radius;
      } else {
        final double difference = cellWidth - indicatorWidth;
        xPosition = (difference / 2) + radius;
      }

      double startXPosition = 0;
      if (isRTL) {
        startXPosition = (6 - (i % DateTime.daysPerWeek)) * cellWidth;
      } else {
        startXPosition =
            ((i % DateTime.daysPerWeek) * cellWidth) + _weekNumberPanelWidth;
      }

      xPosition += startXPosition;
      yPosition = (((i / DateTime.daysPerWeek) + 1).toInt()) * cellHeight;
      for (int j = 0; j < count; j++) {
        paint.color = appointmentLists[j].color;
        canvas.drawCircle(
          Offset(xPosition, yPosition - bottomPadding),
          radius,
          paint,
        );
        xPosition += diameter + indicatorPadding;
        if (startXPosition + cellWidth < xPosition + diameter) {
          break;
        }
      }
    }
  }

  void _updateAppointmentHovering(RRect rect, Canvas canvas) {
    final Offset? hoverPosition = appointmentHoverPosition.value;
    if (hoverPosition == null) {
      return;
    }

    if (rect.left < hoverPosition.dx &&
        rect.right > hoverPosition.dx &&
        rect.top < hoverPosition.dy &&
        rect.bottom > hoverPosition.dy) {
      _appointmentPainter.color = calendarTheme.selectionBorderColor!
          .withValues(alpha: 0.4);
      _appointmentPainter.strokeWidth = 2;
      _appointmentPainter.style = PaintingStyle.stroke;
      canvas.drawRRect(rect, _appointmentPainter);
      _appointmentPainter.style = PaintingStyle.fill;
    }
  }

  void _drawDayAppointments(Canvas canvas, Size size, Paint paint) {
    const int textStartPadding = 3;

    final bool useMobilePlatformUI = CalendarViewHelper.isMobileLayoutUI(
      size.width,
      isMobilePlatform,
    );
    for (int i = 0; i < appointmentCollection.length; i++) {
      final AppointmentView appointmentView = appointmentCollection[i];
      if (appointmentView.canReuse ||
          appointmentView.appointmentRect == null ||
          appointmentView.appointment == null) {
        continue;
      }

      final CalendarAppointment appointment = appointmentView.appointment!;
      paint.color = appointment.color;
      final RRect appointmentRect = appointmentView.appointmentRect!;
      canvas.drawRRect(appointmentRect, paint);

      double xPosition = appointmentRect.left;
      double yPosition = appointmentRect.top;
      final bool canAddSpanIcon = AppointmentHelper.canAddSpanIcon(
        visibleDates,
        appointment,
        view,
      );
      bool canAddForwardIcon = false;
      final TextStyle appointmentTextStyle =
          AppointmentHelper.getAppointmentTextStyle(
            calendar.appointmentTextStyle,
            view,
            themeData,
          );
      if (canAddSpanIcon) {
        if (CalendarViewHelper.isSameTimeSlot(
              appointment.exactStartTime,
              appointment.actualStartTime,
            ) &&
            !CalendarViewHelper.isSameTimeSlot(
              appointment.exactEndTime,
              appointment.actualEndTime,
            )) {
          canAddForwardIcon = true;
        } else if (!CalendarViewHelper.isSameTimeSlot(
              appointment.exactStartTime,
              appointment.actualStartTime,
            ) &&
            CalendarViewHelper.isSameTimeSlot(
              appointment.exactEndTime,
              appointment.actualEndTime,
            )) {
          yPosition += _getTextSize(
            appointmentRect,
            appointmentTextStyle.fontSize! * textScaleFactor,
          );
        }
      }

      final TextSpan span = TextSpan(
        text: appointment.subject,
        style: appointmentTextStyle,
      );

      _textPainter = _updateTextPainter(
        span,
        _textPainter,
        isRTL,
        _textScaleFactor,
      );

      final double totalHeight = appointmentRect.height - textStartPadding;
      _updatePainterMaxLines(totalHeight);

      //// left and right side padding value 2 subtracted in appointment width
      double maxTextWidth = appointmentRect.width - textStartPadding;
      maxTextWidth = maxTextWidth > 0 ? maxTextWidth : 0;
      _textPainter.layout(maxWidth: maxTextWidth);

      /// minIntrinsicWidth property in text painter used to get the
      /// minimum text width of the text.
      /// eg., The text as 'Meeting' and it rendered in two lines and
      /// first line has 'Meet' text and second line has 'ing' text then it
      /// return second lines width.
      /// We are using the minIntrinsicWidth to restrict the text rendering
      /// when the appointment view bound does not hold single letter.
      final double textWidth = appointmentRect.width - textStartPadding;
      if (textWidth < _textPainter.minIntrinsicWidth &&
          textWidth < _textPainter.width &&
          textWidth < (appointmentTextStyle.fontSize ?? 15) * textScaleFactor) {
        _updateAppointmentHovering(appointmentRect, canvas);

        continue;
      }

      if ((_textPainter.maxLines == 1 || _textPainter.maxLines == null) &&
          _textPainter.height > totalHeight) {
        _updateAppointmentHovering(appointmentRect, canvas);
        continue;
      }

      if (isRTL) {
        xPosition +=
            appointmentRect.width - textStartPadding - _textPainter.width;
      }

      _textPainter.paint(
        canvas,
        Offset(
          xPosition + (isRTL ? 0 : textStartPadding),
          yPosition + textStartPadding,
        ),
      );
      final bool isRecurrenceAppointment =
          appointment.recurrenceRule != null &&
          appointment.recurrenceRule!.isNotEmpty;

      if (canAddSpanIcon) {
        if (canAddForwardIcon) {
          _addForwardSpanIconForDay(
            canvas,
            appointmentRect,
            size,
            appointmentRect.tlRadius,
            paint,
            appointmentTextStyle,
          );
        } else {
          _addBackwardSpanIconForDay(
            canvas,
            appointmentRect,
            size,
            appointmentRect.tlRadius,
            paint,
            appointmentTextStyle,
          );
        }
      }

      if (isRecurrenceAppointment || appointment.recurrenceId != null) {
        _addRecurrenceIconForDay(
          canvas,
          size,
          appointmentRect,
          appointmentRect.width,
          textStartPadding,
          paint,
          appointmentRect.tlRadius,
          useMobilePlatformUI,
          isRecurrenceAppointment,
          appointmentTextStyle,
        );
      }

      _updateAppointmentHovering(appointmentRect, canvas);
    }
  }

  void _addBackwardSpanIconForDay(
    Canvas canvas,
    RRect rect,
    Size size,
    Radius cornerRadius,
    Paint paint,
    TextStyle appointmentTextStyle,
  ) {
    canvas.save();
    const double bottomPadding = 2;
    final double textSize = _getTextSize(rect, appointmentTextStyle.fontSize!);
    final TextSpan icon = AppointmentHelper.getSpanIcon(
      appointmentTextStyle.color!,
      textSize,
      false,
    );
    _textPainter = _updateTextPainter(
      icon,
      _textPainter,
      isRTL,
      _textScaleFactor,
    );
    _textPainter.layout(maxWidth: rect.width);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          rect.left,
          rect.top,
          rect.right,
          rect.top + _textPainter.width,
        ),
        cornerRadius,
      ),
      paint,
    );

    final double xPosition = _getXPositionForSpanIconForDay(icon, rect);

    final double yPosition = rect.top + bottomPadding;
    canvas.translate(xPosition, yPosition);
    const double radians = 90 * math.pi / 180;
    canvas.rotate(radians);
    _textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  double _getXPositionForSpanIconForDay(TextSpan icon, RRect rect) {
    /// There is a space around the font, hence to get the start position we
    /// must calculate the icon start position, apart from the space, and the
    /// value 1.5 used since the space on top and bottom of icon is not even,
    /// hence to rectify this tha value 1.5 used, and tested with multiple
    /// device.
    final double iconStartPosition =
        (_textPainter.height - (icon.style!.fontSize! * textScaleFactor)) / 1.5;
    return rect.left +
        (rect.width - _textPainter.height) / 2 +
        _textPainter.height +
        iconStartPosition;
  }

  void _addForwardSpanIconForDay(
    Canvas canvas,
    RRect rect,
    Size size,
    Radius cornerRadius,
    Paint paint,
    TextStyle appointmentTextStyle,
  ) {
    canvas.save();
    const double bottomPadding = 2;
    final double textSize = _getTextSize(rect, appointmentTextStyle.fontSize!);
    final TextSpan icon = AppointmentHelper.getSpanIcon(
      appointmentTextStyle.color!,
      textSize,
      true,
    );
    _textPainter = _updateTextPainter(
      icon,
      _textPainter,
      isRTL,
      _textScaleFactor,
    );
    _textPainter.layout(maxWidth: rect.width);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          rect.left,
          rect.bottom - _textPainter.width,
          rect.right,
          rect.bottom,
        ),
        cornerRadius,
      ),
      paint,
    );

    final double xPosition = _getXPositionForSpanIconForDay(icon, rect);
    final double yPosition =
        rect.bottom - (textSize * textScaleFactor) - bottomPadding;
    canvas.translate(xPosition, yPosition);
    const double radians = 90 * math.pi / 180;
    canvas.rotate(radians);
    _textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _updatePainterMaxLines(double height) {
    /// [preferredLineHeight] is used to get the line height based on text
    /// style and text. floor the calculated value to set the minimum line
    /// count to painter max lines property.
    final int maxLines = (height / _textPainter.preferredLineHeight).floor();
    if (maxLines <= 0) {
      return;
    }

    _textPainter.maxLines = maxLines;
  }

  void _addRecurrenceIconForDay(
    Canvas canvas,
    Size size,
    RRect rect,
    double appointmentWidth,
    int textPadding,
    Paint paint,
    Radius cornerRadius,
    bool useMobilePlatformUI,
    bool isRecurrenceAppointment,
    TextStyle appointmentTextStyle,
  ) {
    final double xPadding = useMobilePlatformUI ? 1 : 2;
    const double bottomPadding = 2;
    double textSize = appointmentTextStyle.fontSize!;
    if (rect.width < textSize || rect.height < textSize) {
      textSize = rect.width > rect.height ? rect.height : rect.width;
    }

    final TextSpan icon = AppointmentHelper.getRecurrenceIcon(
      appointmentTextStyle.color!,
      textSize,
      isRecurrenceAppointment,
    );
    _textPainter.text = icon;
    double maxTextWidth = appointmentWidth - textPadding - 2;
    maxTextWidth = maxTextWidth > 0 ? maxTextWidth : 0;
    _textPainter.layout(maxWidth: maxTextWidth);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          isRTL
              ? rect.left + textSize + xPadding
              : rect.right - textSize - xPadding,
          rect.bottom - bottomPadding - textSize,
          isRTL ? rect.left : rect.right,
          rect.bottom,
        ),
        cornerRadius,
      ),
      paint,
    );
    _textPainter.paint(
      canvas,
      Offset(
        isRTL ? rect.left + xPadding : rect.right - textSize - xPadding,
        rect.bottom - bottomPadding - textSize,
      ),
    );
  }

  void _drawTimelineAppointments(Canvas canvas, Size size, Paint paint) {
    const double textStartPadding = 2;
    final bool useMobilePlatformUI = CalendarViewHelper.isMobileLayoutUI(
      size.width,
      isMobilePlatform,
    );
    for (int i = 0; i < appointmentCollection.length; i++) {
      final AppointmentView appointmentView = appointmentCollection[i];
      if (appointmentView.canReuse ||
          appointmentView.appointmentRect == null ||
          appointmentView.appointment == null) {
        continue;
      }

      final CalendarAppointment appointment = appointmentView.appointment!;
      paint.color = appointment.color;
      final RRect appointmentRect = appointmentView.appointmentRect!;
      canvas.drawRRect(appointmentRect, paint);
      final bool canAddSpanIcon = AppointmentHelper.canAddSpanIcon(
        visibleDates,
        appointment,
        view,
      );
      double forwardSpanIconSize = 0;
      double backwardSpanIconSize = 0;
      const double iconPadding = 2;
      final TextStyle appointmentTextStyle =
          AppointmentHelper.getAppointmentTextStyle(
            calendar.appointmentTextStyle,
            view,
            themeData,
          );
      final double iconSize =
          _getTextSize(
            appointmentRect,
            appointmentTextStyle.fontSize! * textScaleFactor,
          ) +
          (2 * iconPadding);

      if (canAddSpanIcon) {
        final DateTime appStartTime = appointment.exactStartTime;
        final DateTime appEndTime = appointment.exactEndTime;
        final DateTime viewStartDate = AppointmentHelper.convertToStartTime(
          visibleDates[0],
        );
        final DateTime viewEndDate = AppointmentHelper.convertToEndTime(
          visibleDates[visibleDates.length - 1],
        );
        if (AppointmentHelper.canAddForwardSpanIcon(
          appStartTime,
          appEndTime,
          viewStartDate,
          viewEndDate,
        )) {
          forwardSpanIconSize = iconSize;
        } else if (AppointmentHelper.canAddBackwardSpanIcon(
          appStartTime,
          appEndTime,
          viewStartDate,
          viewEndDate,
        )) {
          backwardSpanIconSize = iconSize;
        } else {
          forwardSpanIconSize = iconSize;
          backwardSpanIconSize = iconSize;
        }
      }

      double maxWidth =
          appointmentRect.width -
          (2 * textStartPadding) -
          backwardSpanIconSize -
          forwardSpanIconSize;
      maxWidth = maxWidth > 0 ? maxWidth : 0;
      final TextSpan span = TextSpan(
        text: _getTimelineAppointmentText(appointment, canAddSpanIcon),
        style: appointmentTextStyle,
      );

      _textPainter = _updateTextPainter(
        span,
        _textPainter,
        isRTL,
        _textScaleFactor,
      );
      final double totalHeight =
          appointmentRect.height - (2 * textStartPadding);
      _updatePainterMaxLines(totalHeight);

      /// In RTL, when the text wraps into multiple line the line width is
      /// smaller than the expected when we use the
      /// 'TextWidthBasis.longestLine]` which renders the subject text out of
      /// the appointment rect, hence to overcome this we have added checked
      /// this condition and set the text width basis.
      if (view == CalendarView.timelineMonth) {
        _textPainter.textWidthBasis = TextWidthBasis.parent;
      }

      //// left and right side padding value 2 subtracted in appointment width
      _textPainter.layout(maxWidth: maxWidth);
      if ((_textPainter.maxLines == null || _textPainter.maxLines == 1) &&
          _textPainter.height > totalHeight) {
        _updateAppointmentHovering(appointmentRect, canvas);
        continue;
      }

      final double xPosition =
          isRTL
              ? appointmentRect.right -
                  backwardSpanIconSize -
                  _textPainter.width -
                  textStartPadding
              : appointmentRect.left + backwardSpanIconSize + textStartPadding;
      final int maxLines =
          (appointmentRect.height / _textPainter.preferredLineHeight).floor();
      final bool isRecurrenceAppointment =
          appointment.recurrenceRule != null &&
          appointment.recurrenceRule!.isNotEmpty;

      if (maxLines == 1) {
        _drawSingleLineAppointmentView(
          canvas,
          appointmentRect,
          textStartPadding,
          appointmentTextStyle,
          appointmentTextStyle.fontSize!,
          isRecurrenceAppointment,
          isRecurrenceAppointment || appointment.recurrenceId != null
              ? iconSize
              : 0,
          forwardSpanIconSize,
          backwardSpanIconSize,
          paint,
        );
      } else {
        _textPainter.paint(
          canvas,
          Offset(xPosition, appointmentRect.top + textStartPadding),
        );

        if (forwardSpanIconSize != 0) {
          _addForwardSpanIconForTimeline(
            canvas,
            size,
            appointmentRect,
            maxWidth,
            appointmentRect.tlRadius,
            paint,
            isMobilePlatform,
            appointmentTextStyle,
          );
        }

        if (backwardSpanIconSize != 0) {
          _addBackwardSpanIconForTimeline(
            canvas,
            size,
            appointmentRect,
            maxWidth,
            appointmentRect.tlRadius,
            paint,
            isMobilePlatform,
            appointmentTextStyle,
          );
        }

        if (isRecurrenceAppointment || appointment.recurrenceId != null) {
          _addRecurrenceIconForTimeline(
            canvas,
            size,
            appointmentRect,
            maxWidth,
            appointmentRect.tlRadius,
            paint,
            useMobilePlatformUI,
            isRecurrenceAppointment,
            appointmentTextStyle,
          );
        }
      }

      _updateAppointmentHovering(appointmentRect, canvas);
    }
  }

  /// To display the different text on spanning appointment for timeline day
  /// view, for other views we just display the subject of the appointment and
  /// for timeline day view  we display the current date, and total dates of the
  ///  spanning appointment.
  String _getTimelineAppointmentText(
    CalendarAppointment appointment,
    bool canAddSpanIcon,
  ) {
    if (view != CalendarView.timelineDay || !canAddSpanIcon) {
      return appointment.subject;
    }

    return AppointmentHelper.getSpanAppointmentText(
      appointment,
      visibleDates[0],
      _localizations,
    );
  }

  double _getTextSize(RRect rect, double textSize) {
    if (rect.width < textSize || rect.height < textSize) {
      return rect.width > rect.height ? rect.height : rect.width;
    }

    return textSize;
  }

  double _getYPositionForSpanIconInTimeline(
    TextSpan icon,
    RRect rect,
    double xPadding,
    bool isMobilePlatform,
  ) {
    /// There is a space around the font, hence to get the start position we
    /// must calculate the icon start position, apart from the space, and the
    /// value 2 used since the space on top and bottom of icon is not even,
    /// hence to rectify this tha value 2 used, and tested with multiple
    /// device.
    final double iconStartPosition =
        (_textPainter.height - (icon.style!.fontSize! * textScaleFactor) / 2) /
        2;
    return rect.top - iconStartPosition + (isMobilePlatform ? 1 : xPadding);
  }

  void _addForwardSpanIconForTimeline(
    Canvas canvas,
    Size size,
    RRect rect,
    double maxWidth,
    Radius cornerRadius,
    Paint paint,
    bool isMobilePlatform,
    TextStyle appointmentTextStyle,
  ) {
    const double xPadding = 2;
    final double textSize = _getTextSize(rect, appointmentTextStyle.fontSize!);
    final TextSpan icon = AppointmentHelper.getSpanIcon(
      appointmentTextStyle.color!,
      textSize,
      !isRTL,
    );
    _textPainter = _updateTextPainter(
      icon,
      _textPainter,
      isRTL,
      _textScaleFactor,
    );
    _textPainter.layout(maxWidth: maxWidth);
    final double xPosition =
        isRTL
            ? rect.left + xPadding
            : rect.right - _textPainter.width - xPadding;

    final double yPosition = _getYPositionForSpanIconInTimeline(
      icon,
      rect,
      xPadding,
      isMobilePlatform,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          xPosition,
          rect.top + 1,
          isRTL ? rect.left : rect.right,
          rect.bottom,
        ),
        cornerRadius,
      ),
      paint,
    );
    _textPainter.paint(canvas, Offset(xPosition, yPosition));
  }

  void _addBackwardSpanIconForTimeline(
    Canvas canvas,
    Size size,
    RRect rect,
    double maxWidth,
    Radius cornerRadius,
    Paint paint,
    bool isMobilePlatform,
    TextStyle appointmentTextStyle,
  ) {
    const double xPadding = 2;
    final double textSize = _getTextSize(rect, appointmentTextStyle.fontSize!);
    final TextSpan icon = AppointmentHelper.getSpanIcon(
      appointmentTextStyle.color!,
      textSize,
      isRTL,
    );
    _textPainter = _updateTextPainter(
      icon,
      _textPainter,
      isRTL,
      _textScaleFactor,
    );
    _textPainter.layout(maxWidth: maxWidth);
    final double xPosition =
        isRTL
            ? rect.right - _textPainter.width - xPadding
            : rect.left + xPadding;

    final double yPosition = _getYPositionForSpanIconInTimeline(
      icon,
      rect,
      xPadding,
      isMobilePlatform,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          xPosition,
          rect.top + 1,
          isRTL ? rect.right : rect.left,
          rect.bottom,
        ),
        cornerRadius,
      ),
      paint,
    );
    _textPainter.paint(canvas, Offset(xPosition, yPosition));
  }

  void _addRecurrenceIconForTimeline(
    Canvas canvas,
    Size size,
    RRect rect,
    double maxWidth,
    Radius cornerRadius,
    Paint paint,
    bool useMobilePlatformUI,
    bool isRecurrenceAppointment,
    TextStyle appointmentTextStyle,
  ) {
    final double xPadding = useMobilePlatformUI ? 1 : 2;
    const double bottomPadding = 2;
    final double textSize = _getTextSize(rect, appointmentTextStyle.fontSize!);

    final TextSpan icon = AppointmentHelper.getRecurrenceIcon(
      appointmentTextStyle.color!,
      textSize,
      isRecurrenceAppointment,
    );
    _textPainter.text = icon;
    _textPainter.layout(maxWidth: maxWidth);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          isRTL ? rect.left + xPadding : rect.right - textSize - xPadding,
          rect.bottom - bottomPadding - textSize,
          isRTL ? rect.left : rect.right,
          rect.bottom,
        ),
        cornerRadius,
      ),
      paint,
    );
    _textPainter.paint(
      canvas,
      Offset(
        isRTL ? rect.left + xPadding : rect.right - textSize - xPadding,
        rect.bottom - bottomPadding - textSize,
      ),
    );
  }
}

TextPainter _updateTextPainter(
  TextSpan span,
  TextPainter textPainter,
  bool isRTL,
  double textScaleFactor,
) {
  textPainter.text = span;
  textPainter.maxLines = 1;
  textPainter.textDirection = TextDirection.ltr;
  textPainter.textAlign = isRTL ? TextAlign.right : TextAlign.left;
  textPainter.textWidthBasis = TextWidthBasis.longestLine;
  textPainter.textScaler = TextScaler.linear(textScaleFactor);
  return textPainter;
}

/// SF-15 (Nestify): immutable input for [CascadeLayout.resolve] describing one
/// timed day/week/workWeek appointment.
///
/// Carries only the geometry-relevant fields so the cascade math stays a pure
/// function that is unit-testable without a widget tree.
class CascadeItem {
  /// Creates a cascade input item.
  const CascadeItem({
    required this.start,
    required this.end,
    required this.position,
    required this.maxPositions,
  });

  /// Actual start time of the appointment.
  final DateTime start;

  /// Actual end time of the appointment.
  final DateTime end;

  /// Syncfusion lane index assigned by
  /// `AppointmentHelper.setAppointmentPositionAndMaxPosition`.
  final int position;

  /// Syncfusion overlap-cluster column count (shared by every member of the
  /// same cluster). Drives the cascade activation threshold.
  final int maxPositions;
}

/// SF-15 (Nestify): the horizontal placement of one cascade appointment,
/// expressed as fractions in `[0, 1]` of the day-column content width
/// (`cellWidth - cellEndPadding`). The consumer maps these to pixels.
class CascadeBox {
  /// Creates a cascade box.
  const CascadeBox({required this.leftFraction, required this.widthFraction});

  /// Left edge as a fraction of the day-column content width.
  final double leftFraction;

  /// Width as a fraction of the day-column content width.
  final double widthFraction;
}

/// SF-15 (Nestify): high-density cascade collision geometry for timed
/// day/week/workWeek appointments, selected via
/// [AppointmentOverlapMode.cascade].
///
/// ## Why a custom shape (not raw FullCalendar / react-big-calendar)
///
/// Both FullCalendar's `timegrid` slot-overlap and react-big-calendar's
/// `overlap.js` widen the *left-most* event so it overlaps everything to its
/// right. The Nestify §0.3 target is the opposite: the first event of an
/// overlap batch stays a clean, narrow, isolated column on the left, while the
/// *later* batch cascades on top of the deepest existing branch. So this port
/// keeps react-big-calendar's container / row / leaf **tree** (it captures the
/// branch structure precisely) but replaces its width/offset math with the
/// FullCalendar "forward-pressure" idea tuned to §0.3.
///
/// ## Algorithm (maps to §0.3)
///
/// For the baseline cluster A(8–10,pos0) B(8–10,pos1) C(9–11,pos2)
/// D(9–9:30,pos3), maxPositions=4:
///
/// 1. **Tree** (react-big-calendar): sort by start asc / end desc; the first
///    event becomes a *container*; a same-start sibling becomes a *row* of that
///    container; later overlapping events become *leaves* of the most recent
///    overlapping row. → A = container, B = row of A, C & D = leaves of B. This
///    yields the §0.3 branch split: A is its own (shallow) branch; B hosts the
///    C+D overlay stack.
/// 2. **Widths by branch depth** (forward pressure): `branchDepth` = the
///    deepest row stack = `1 + max(row.leaves)` (= 3 here). `unit =
///    width / (branchDepth + 1)` (= 1/4). The container gets a clean `unit`
///    column on the far left (A → narrow, isolated, no overlap). The row gets
///    the whole remaining branch region (B → wide).
/// 3. **Overlay offset** (cascade): each leaf shifts right by
///    `unit * kCascadeOffsetFactor` and extends to the branch's right edge, so
///    successive leaves get progressively narrower (C wide, D narrow) and both
///    overlap the row B underneath — the §0.3 "压盖" overlay.
///
/// Result fractions: A `[0, .25]`, B `[.25, .75]`, C `[.5, .5]`, D `[.75, .25]`
/// — every event is one regular rect; A.width < B.width; D.width < C.width; A
/// does not intersect B/C/D; C and D both intersect B.
///
/// The exact offset step and readability floor have no industry standard and
/// are tuned on-device against Google Calendar in T6 (OQ-3); only the *shape*
/// (the invariants above) is fixed here.
class CascadeLayout {
  CascadeLayout._();

  /// Minimum overlap-cluster column count (`maxPositions`) required before the
  /// cascade layout kicks in. Below this, the cluster keeps the SF-6 laneFill
  /// behavior. SF-15 OQ-3: kept at 4 (the §0.3 baseline) until tuned in T6.
  static const int kCascadeMinColumns = 4;

  /// Right-shift applied to each cascade leaf, as a multiple of the branch
  /// `unit` width. `1.0` reproduces the §0.3 baseline (each leaf shifts by one
  /// full unit). SF-15 OQ-3: tuned on-device in T6 — smaller = tighter overlap
  /// over the row beneath, larger = more separation.
  static const double kCascadeOffsetFactor = 1.0;

  /// Minimum readable rect width, in logical pixels, applied by the consumer
  /// after the fractional box is mapped to pixels. SF-15 OQ-3: a placeholder
  /// floor tuned on-device in T6; inactive for the §0.3 baseline.
  static const double kCascadeMinReadableWidth = 24.0;

  /// Mirrors the `_updateDayAppointmentDetails` entry filter: a timed,
  /// single-day, non-spanned appointment that is visible in [column].
  ///
  /// Kept as the single source of truth for cascade eligibility; the render
  /// loop keeps its own inline `continue` so the SF-6 path stays byte-identical.
  static bool isEligibleTimedAppointment(
    CalendarAppointment appointment,
    int column,
  ) {
    if (column == -1 || appointment.isSpanned || appointment.isAllDay) {
      return false;
    }
    return AppointmentHelper.getDifference(
          appointment.startTime,
          appointment.endTime,
        ).inDays <=
        0;
  }

  /// SF-15 (Nestify): 命中测试——返回 rect 包含点 `(x, y)` 的 appointment view，
  /// 按绘制顺序决定取哪一个。
  ///
  /// [views] 是 start-asc 序的渲染集合（后入列 = 后绘制 = 视觉上层）。
  ///
  /// - [AppointmentOverlapMode.cascade]：重叠 rect 故意互相压盖（§0.3 overlay），
  ///   同一点可能落进多个 rect，视觉**顶层 = 最后绘制**，所以必须**反向遍历**
  ///   （末尾 → 头部），返回第一个命中即顶层。前向遍历会选到被压在下面的最早
  ///   事件，与"点哪个看哪个"反直觉，并误导长按选中 / 拖拽落点。
  /// - [AppointmentOverlapMode.laneFill]（默认）：lane 几何下 rect 不重叠，前向
  ///   与反向命中结果一致，保持**前向**遍历以字节级复刻 SF-6 行为。
  ///
  /// 纯函数（不依赖 widget 状态），便于单测；只读 [views]，不产生副作用。
  static AppointmentView? hitTest(
    AppointmentOverlapMode mode,
    List<AppointmentView> views,
    double x,
    double y,
  ) {
    final bool reverse = mode == AppointmentOverlapMode.cascade;
    for (int k = 0; k < views.length; k++) {
      final int i = reverse ? views.length - 1 - k : k;
      final AppointmentView view = views[i];
      final RRect? rect = view.appointmentRect;
      if (view.appointment != null &&
          rect != null &&
          rect.left <= x &&
          rect.right >= x &&
          rect.top <= y &&
          rect.bottom >= y) {
        return view;
      }
    }
    return null;
  }

  /// Resolves the per-item cascade box, or `null` when the item should keep the
  /// SF-6 laneFill geometry (non-cascade [mode], or a cluster below
  /// [kCascadeMinColumns]). The returned list is index-aligned with [items].
  static List<CascadeBox?> resolve(
    AppointmentOverlapMode mode,
    List<CascadeItem> items,
  ) {
    final List<CascadeBox?> result = List<CascadeBox?>.filled(
      items.length,
      null,
    );
    if (mode != AppointmentOverlapMode.cascade || items.isEmpty) {
      return result;
    }
    for (final List<int> cluster in _clusterIndices(items)) {
      int maxPositions = 1;
      for (final int idx in cluster) {
        if (items[idx].maxPositions > maxPositions) {
          maxPositions = items[idx].maxPositions;
        }
      }
      if (maxPositions < kCascadeMinColumns) {
        continue;
      }
      _assignClusterBoxes(items, cluster, result);
    }
    return result;
  }

  /// Partitions [items] into clusters of transitively overlapping appointments
  /// (union-find over [_cascadeOverlaps]). O(n²), matching the existing
  /// `_computeDayAppointmentLaneExtent` scan; n is the per-view appointment
  /// count, which is small.
  static List<List<int>> _clusterIndices(List<CascadeItem> items) {
    final int n = items.length;
    final List<int> parent = List<int>.generate(n, (int i) => i);
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    void union(int a, int b) {
      final int ra = find(a);
      final int rb = find(b);
      if (ra != rb) {
        parent[ra] = rb;
      }
    }

    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        if (_cascadeOverlaps(
          items[i].start,
          items[i].end,
          items[j].start,
          items[j].end,
        )) {
          union(i, j);
        }
      }
    }

    final Map<int, List<int>> groups = <int, List<int>>{};
    for (int i = 0; i < n; i++) {
      groups.putIfAbsent(find(i), () => <int>[]).add(i);
    }
    return groups.values.toList();
  }

  /// Builds the react-big-calendar container / row / leaf forest for one
  /// cluster and writes each member's [CascadeBox] into [out].
  static void _assignClusterBoxes(
    List<CascadeItem> items,
    List<int> cluster,
    List<CascadeBox?> out,
  ) {
    final List<_CascadeNode> nodes =
        cluster
            .map(
              (int idx) => _CascadeNode(idx, items[idx].start, items[idx].end),
            )
            .toList();
    // start asc, then end desc (longer first), then original index for a
    // deterministic, stable order on ties.
    nodes.sort((_CascadeNode a, _CascadeNode b) {
      final int c = a.start.compareTo(b.start);
      if (c != 0) {
        return c;
      }
      final int c2 = b.end.compareTo(a.end);
      if (c2 != 0) {
        return c2;
      }
      return a.index.compareTo(b.index);
    });

    final List<_CascadeNode> containers = <_CascadeNode>[];
    for (final _CascadeNode node in nodes) {
      _CascadeNode? container;
      for (final _CascadeNode c in containers) {
        if (_cascadeOverlaps(c.start, c.end, node.start, node.end)) {
          container = c;
          break;
        }
      }
      if (container == null) {
        node.rows = <_CascadeNode>[];
        containers.add(node);
        continue;
      }
      node.container = container;
      _CascadeNode? row;
      for (int j = container.rows!.length - 1; j >= 0; j--) {
        final _CascadeNode candidate = container.rows![j];
        if (_cascadeOverlaps(
          candidate.start,
          candidate.end,
          node.start,
          node.end,
        )) {
          row = candidate;
          break;
        }
      }
      if (row != null) {
        row.leaves!.add(node);
        node.row = row;
      } else {
        node.leaves = <_CascadeNode>[];
        container.rows!.add(node);
      }
    }

    for (final _CascadeNode c in containers) {
      _allocateSubtree(c, 0, 1, out);
    }
  }

  /// Allocates the horizontal band `[lo, hi]` (fractions) to a container
  /// subtree: a clean narrow column for the container itself, a wide branch
  /// region for its rows, and a right-shifted overlay for each row's leaves.
  static void _allocateSubtree(
    _CascadeNode container,
    double lo,
    double hi,
    List<CascadeBox?> out,
  ) {
    final double w = hi - lo;
    final List<_CascadeNode> rows = container.rows ?? const <_CascadeNode>[];
    int branchDepth = 1;
    for (final _CascadeNode r in rows) {
      final int depth = 1 + (r.leaves?.length ?? 0);
      if (depth > branchDepth) {
        branchDepth = depth;
      }
    }
    final double unit = w / (branchDepth + 1);
    out[container.index] = CascadeBox(leftFraction: lo, widthFraction: unit);

    final double branchLo = lo + unit;
    final double step = unit * kCascadeOffsetFactor;
    // Guard so tuned offset factors (T6) can never collapse a leaf below `unit`
    // or push it past the branch; inactive at the default factor of 1.0.
    final double maxLeft = hi - unit;
    for (final _CascadeNode r in rows) {
      out[r.index] = CascadeBox(
        leftFraction: branchLo,
        widthFraction: hi - branchLo,
      );
      final List<_CascadeNode> leaves = r.leaves ?? const <_CascadeNode>[];
      for (int i = 0; i < leaves.length; i++) {
        double left = branchLo + (i + 1) * step;
        if (left > maxLeft) {
          left = maxLeft;
        }
        out[leaves[i].index] = CascadeBox(
          leftFraction: left,
          widthFraction: hi - left,
        );
      }
    }
  }

  /// Time overlap test for cascade clustering. OQ-6: ignores seconds, mirroring
  /// `CalendarViewHelper.isSameTimeSlot` / Syncfusion's
  /// `_isIntersectingAppointmentInDayView` — shared start/end slots count as
  /// overlapping, while back-to-back (`a.end == b.start`) does not.
  static bool _cascadeOverlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    if (CalendarViewHelper.isSameTimeSlot(aStart, bStart) ||
        CalendarViewHelper.isSameTimeSlot(aEnd, bEnd)) {
      return true;
    }
    final DateTime a0 = _floorToMinute(aStart);
    final DateTime a1 = _floorToMinute(aEnd);
    final DateTime b0 = _floorToMinute(bStart);
    final DateTime b1 = _floorToMinute(bEnd);
    return a0.isBefore(b1) && b0.isBefore(a1);
  }

  static DateTime _floorToMinute(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
}

/// SF-15 (Nestify): a node in the react-big-calendar container / row / leaf
/// forest used by [CascadeLayout]. `rows != null` marks a container;
/// `leaves != null` marks a row base; otherwise the node is a leaf.
class _CascadeNode {
  _CascadeNode(this.index, this.start, this.end);

  final int index;
  final DateTime start;
  final DateTime end;
  _CascadeNode? container;
  _CascadeNode? row;
  List<_CascadeNode>? rows;
  List<_CascadeNode>? leaves;
}
