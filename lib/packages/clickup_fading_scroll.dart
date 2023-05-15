library clickup_fading_scroll;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A widget builder for a scrollable subtree that must fade with a
/// [FadingScrollable].
typedef FadingScrollWidgetBuilder = Widget Function(
  BuildContext context,
  ScrollController controller,
);

/// Add a fading effect to a scrollable [child].
class FadingScroll extends StatefulWidget {
  const FadingScroll({
    Key? key,
    required this.builder,
    this.controller,
    double? startFadingSize,
    double? endFadingSize,
    double? fadingSize,
    double? startScrollExtent,
    double? endScrollExtent,
    double? scrollExtent,
    this.transitionDuration,
  })  : startScrollExtent = startScrollExtent ?? scrollExtent,
        endScrollExtent = endScrollExtent ?? scrollExtent,
        startFadingSize = startFadingSize ?? fadingSize,
        endFadingSize = endFadingSize ?? fadingSize,
        super(key: key);

  /// The scroll controller that is used to track the scrolling status.
  ///
  /// If not provided, one is created internally and given to the [builder].
  final ScrollController? controller;

  /// A builder for the scrollable child that will have the fading mask applied.
  final FadingScrollWidgetBuilder builder;

  /// The minimum amount of scroll needed after which the fading mask has
  /// its [startFadingSize] full size.
  final double? startScrollExtent;

  /// The minimum amount of scroll needed before which the fading mask has
  /// its [endFadingSize] full size.
  ///
  /// If not provided, it is equivalent to [endScrollExtent]. And if neither
  /// [startScrollExtent] nor [endScrollExtent] is provided then its value
  /// is [defaultScrollExtent].
  final double? endScrollExtent;

  /// The fading mask maximum size when there is content hidden before the
  /// start of the current scroll position.
  ///
  /// If not provided, it is equivalent to [startScrollExtent]. And if neither
  /// [startScrollExtent] nor [endScrollExtent] is provided then its value
  /// is [defaultScrollExtent].
  final double? startFadingSize;

  /// The fading mask maximum size when there is content hidden after the
  /// end of the current scroll position.
  ///
  /// If not provided, it is equivalent to [endScrollExtent].
  final double? endFadingSize;

  /// The duration for animate the mask whenever it changes.
  ///
  /// If `null`, the transition isn't animated.
  final Duration? transitionDuration;

  /// The default value if neither [startScrollExtent] nor [endScrollExtent] is
  /// provided to a [FadingScroll].
  static const defaultScrollExtent = 50.0;

  @override
  State<FadingScroll> createState() => _FadingScrollableState();
}

class _FadingScrollableState extends State<FadingScroll> {
  late ScrollController controller = widget.controller ?? ScrollController();

  var _totalExtent = 0.0;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {}); // Trigger initial frame
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant FadingScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newController = widget.controller;
    if (oldWidget.controller == null && newController != null) {
      controller.dispose();
      setState(() {
        controller = newController;
      });
    } else if (oldWidget.controller != null && newController == null) {
      setState(() {
        controller = ScrollController();
      });
    }

    // This is needed because the notifier doesn't update its children of a
    // layout change.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final newTotalExtent =
            controller.hasClients && controller.position.hasContentDimensions
                ? controller.position.extentBefore +
                    controller.position.extentInside +
                    controller.position.extentAfter
                : 0.0;
        if (newTotalExtent != _totalExtent) {
          _totalExtent = newTotalExtent;
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      controller.dispose();
    }
    super.dispose();
  }

  double _fadingMaxAmount(double maxExtent) {
    final viewportDimension =
        controller.hasClients && controller.position.hasContentDimensions
            ? controller.position.viewportDimension
            : 0.0;
    return (maxExtent / viewportDimension).clamp(0, 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final startScrollExtent = widget.startScrollExtent ??
        widget.endScrollExtent ??
        FadingScroll.defaultScrollExtent;
    final endScrollExtent = widget.endScrollExtent ??
        widget.startScrollExtent ??
        FadingScroll.defaultScrollExtent;

    final startFadingMaxExtent = widget.startFadingSize ?? startScrollExtent;
    final endFadingMaxExtent = widget.endFadingSize ?? endScrollExtent;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final isAttached = controller.hasClients;
        final isVertical =
            !isAttached || controller.position.axis == Axis.vertical;
        final startAmount = !isAttached ||
                !controller.position.hasContentDimensions ||
                controller.position.extentBefore <= 0
            ? 0.0
            : (controller.position.extentBefore / startScrollExtent)
                .clamp(0.0, 1.0);
        final endAmount = !isAttached ||
                !controller.position.hasContentDimensions ||
                controller.position.extentAfter <= 0
            ? 0.0
            : (controller.position.extentAfter / endScrollExtent)
                .clamp(0.0, 1.0);
        final startFadingMaxAmount = _fadingMaxAmount(startFadingMaxExtent);
        final endFadingMaxAmount = _fadingMaxAmount(endFadingMaxExtent);
        final startStop = startFadingMaxAmount * startAmount;
        final endStop = 1 - endFadingMaxAmount * endAmount;
        final transitionDuration = widget.transitionDuration;
        if (transitionDuration == null) {
          return _Mask(
            startStop: startStop,
            endStop: endStop,
            child: child!,
            isVertical: isVertical,
          );
        }
        return _AnimatedMask(
          duration: transitionDuration,
          startStop: startStop,
          endStop: endStop,
          isVertical: isVertical,
          child: child!,
        );
      },
      child: widget.builder(context, controller),
    );
  }
}

class _Mask extends StatelessWidget {
  const _Mask({
    Key? key,
    required this.startStop,
    required this.endStop,
    required this.child,
    required this.isVertical,
  }) : super(key: key);

  final double startStop;
  final double endStop;
  final bool isVertical;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final startStop = this.startStop.clamp(0.0, 1.0);
    final endStop = this.endStop.clamp(0.0, 1.0);
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: isVertical ? Alignment.topCenter : Alignment.centerLeft,
          end: isVertical ? Alignment.bottomCenter : Alignment.centerRight,
          colors: <Color>[
            if (startStop > 0.0) const Color(0x00FFFFFF),
            const Color(0xFFFFFFFF),
            const Color(0xFFFFFFFF),
            if (endStop < 1.0) const Color(0x00FFFFFF),
          ],
          stops: <double>[
            0.0,
            if (startStop > 0.0) startStop.toDouble(),
            if (endStop < 1.0) endStop.toDouble(),
            1,
          ],
          tileMode: TileMode.mirror,
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

class _AnimatedMask extends ImplicitlyAnimatedWidget {
  const _AnimatedMask({
    Key? key,
    required this.startStop,
    required this.endStop,
    required this.child,
    required this.isVertical,
    Curve curve = Curves.linear,
    required Duration duration,
    VoidCallback? onEnd,
  }) : super(
          key: key,
          curve: curve,
          duration: duration,
          onEnd: onEnd,
        );

  final double startStop;
  final double endStop;
  final bool isVertical;
  final Widget child;

  @override
  AnimatedWidgetBaseState<_AnimatedMask> createState() => _AnimatedMaskState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<double>('startStop', startStop));
    properties.add(DiagnosticsProperty<double>('endStop', endStop));
  }
}

class _AnimatedMaskState extends AnimatedWidgetBaseState<_AnimatedMask> {
  Tween<double>? _startStop;
  Tween<double>? _endStop;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _startStop = visitor(_startStop, widget.startStop,
            (dynamic value) => Tween<double>(begin: value as double))
        as Tween<double>?;
    _endStop = visitor(_endStop, widget.endStop,
            (dynamic value) => Tween<double>(begin: value as double))
        as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    final startStop = _startStop!.evaluate(animation);
    final endStop = _endStop!.evaluate(animation);
    return _Mask(
      endStop: endStop.toDouble(),
      startStop: startStop.toDouble(),
      isVertical: widget.isVertical,
      child: widget.child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<Tween<double>>('startStop', _startStop,
        defaultValue: null));
    description.add(DiagnosticsProperty<Tween<double>>('endStop', _endStop,
        defaultValue: null));
  }
}
