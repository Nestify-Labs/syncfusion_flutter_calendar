// SF-22: date blocks abut without their rulers; one ruler stays fixed.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Internal three-block layout used only by continuous detail views.
class DayWindowScrollLayout extends MultiChildRenderObjectWidget {
  const DayWindowScrollLayout({
    super.key,
    required super.children,
    required this.position,
    required this.rulerWidth,
    required this.isRTL,
  });
  final double position;
  final double rulerWidth;
  final bool isRTL;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _DayWindowLayout(position, rulerWidth, isRTL);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _DayWindowLayout).update(position, rulerWidth, isRTL);
  }
}

class _DayWindowParentData extends ContainerBoxParentData<RenderBox> {}

class _DayWindowLayout extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  _DayWindowLayout(this.position, this.rulerWidth, this.isRTL);
  double position, rulerWidth;
  bool isRTL;
  double get width => size.width / 3;
  double get stride => width - rulerWidth;
  Rect get dateViewport =>
      Rect.fromLTWH(width + (isRTL ? 0 : rulerWidth), 0, stride, size.height);

  void update(double value, double ruler, bool rtl) {
    if (position == value && rulerWidth == ruler && isRTL == rtl) {
      return;
    }
    position = value;
    rulerWidth = ruler;
    isRTL = rtl;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _DayWindowParentData();
    }
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    int index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tight(Size(width, size.height)),
        parentUsesSize: true,
      );
      final ContainerBoxParentData<RenderBox> data =
          child.parentData! as ContainerBoxParentData<RenderBox>;
      data.offset = Offset(
        index == 3 ? width : width + position + (index - 1) * stride,
        0,
      );
      index++;
      child = data.nextSibling;
    }
  }

  Rect _dateClip(RenderBox child) {
    final Offset offset =
        (child.parentData! as ContainerBoxParentData<RenderBox>).offset;
    if (identical(child, lastChild)) {
      return Rect.fromLTWH(
        width + (isRTL ? stride : 0),
        0,
        rulerWidth,
        size.height,
      );
    }
    return Rect.fromLTWH(
      offset.dx + (isRTL ? 0 : rulerWidth),
      0,
      stride,
      size.height,
    ).intersect(dateViewport);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    while (child != null) {
      final RenderBox page = child;
      final ContainerBoxParentData<RenderBox> data =
          page.parentData! as ContainerBoxParentData<RenderBox>;
      final Rect clip = _dateClip(page);
      if (!clip.isEmpty) {
        context.pushClipRect(
          needsCompositing,
          offset,
          clip,
          (PaintingContext ctx, Offset origin) =>
              ctx.paintChild(page, origin + data.offset),
        );
      }
      child = data.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!Rect.fromLTWH(width, 0, width, size.height).contains(position))
      return false;
    RenderBox? child = lastChild;
    while (child != null) {
      final RenderBox page = child;
      final ContainerBoxParentData<RenderBox> data =
          page.parentData! as ContainerBoxParentData<RenderBox>;
      if (_dateClip(page).contains(position) &&
          result.addWithPaintOffset(
            offset: data.offset,
            position: position,
            hitTest:
                (BoxHitTestResult result, Offset local) =>
                    page.hitTest(result, position: local),
          ))
        return true;
      child = data.previousSibling;
    }
    return false;
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _dateClip(child as RenderBox);

  // SF-22: buffered blocks are mounted but unpainted. Do not expose their
  // paint-derived appointment semantics until their date columns are visible.
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    RenderBox? child = firstChild;
    while (child != null) {
      if (!_dateClip(child).isEmpty) {
        visitor(child);
      }
      child =
          (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
    }
  }

  @override
  Rect? describeSemanticsClip(RenderObject? child) =>
      child == null ? dateViewport : _dateClip(child as RenderBox);
}
