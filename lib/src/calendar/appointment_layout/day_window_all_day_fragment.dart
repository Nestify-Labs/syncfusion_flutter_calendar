// SF-22: date blocks clip slices of the same viewport-wide all-day card.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Internal presentation adapter; the parent's fragment remains the hit region.
class DayWindowAllDayFragment extends SingleChildRenderObjectWidget {
  const DayWindowAllDayFragment({
    required this.changes,
    required this.cardBounds,
    required super.child,
    super.key,
  });

  final Listenable changes;
  final Rect Function() cardBounds;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _AllDayFragment(changes, cardBounds);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _AllDayFragment).update(changes, cardBounds);
  }
}

class _AllDayFragment extends RenderShiftedBox {
  _AllDayFragment(this._changes, this._cardBounds) : super(null);
  Listenable _changes;
  Rect Function() _cardBounds;
  Rect _card = Rect.zero;

  void update(Listenable changes, Rect Function() bounds) {
    if (!identical(changes, _changes)) {
      if (attached) {
        _changes.removeListener(markNeedsLayout);
      }
      _changes = changes;
      if (attached) {
        _changes.addListener(markNeedsLayout);
      }
    }
    _cardBounds = bounds;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _changes.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _changes.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    _card = _cardBounds();
    child?.layout(
      BoxConstraints.tight(
        Size(_card.width.clamp(0.0, double.infinity), size.height),
      ),
    );
    if (child != null) {
      (child!.parentData! as BoxParentData).offset = Offset(_card.left, 0);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _card.isEmpty) {
      return;
    }
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (
      PaintingContext context,
      Offset origin,
    ) {
      context.paintChild(child!, origin + Offset(_card.left, 0));
    });
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => Offset.zero & size;

  @override
  Rect? describeSemanticsClip(RenderObject? child) => Offset.zero & size;
}
