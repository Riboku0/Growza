import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class GrowzaMotion {
  static const breathing = Duration(seconds: 6);
  static const scenery = Duration(seconds: 18);
  static const growth = Duration(milliseconds: 1500);
  static const celebration = Duration(milliseconds: 1500);
  static const numbers = Duration(milliseconds: 200);
  static const press = Duration(milliseconds: 120);
  static const route = Duration(milliseconds: 280);
  static const breathScale = .015;
  static const swayRadians = .008;
  static const pressScale = .97;
  static const particleCount = 12;
  static const hapticsEnabled = true;
  static const breathingCurve = Curves.easeInOutSine;
  static const growthCurve = Cubic(.22, 1, .36, 1.04);
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  static void feedback(BuildContext context, {bool stageChanged = false}) {
    if (!hapticsEnabled || reduced(context)) return;
    if (stageChanged) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }
}

/// Keeps decorative motion independent of the focus timer and suspends it
/// when the route, scroll viewport, or application is no longer visible.
class MotionLoop extends StatefulWidget {
  const MotionLoop({
    super.key,
    required this.builder,
    this.child,
    this.active = true,
    this.duration = GrowzaMotion.breathing,
  });
  final TransitionBuilder builder;
  final Widget? child;
  final bool active;
  final Duration duration;
  static double phaseOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MotionPhase>()?.phase ?? 0;
  @override
  MotionLoopState createState() => MotionLoopState();
}

class MotionLoopState extends State<MotionLoop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  ScrollPosition? _position;
  bool _foreground = true, _visible = true, _pendingCheck = false;
  bool get isAnimating => _controller.isAnimating;
  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_scheduleVisibility);
      _position = position;
      _position?.addListener(_scheduleVisibility);
    }
    _sync();
    _scheduleVisibility();
  }

  @override
  void didUpdateWidget(MotionLoop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    _sync();
  }

  void _scheduleVisibility() {
    if (_pendingCheck) return;
    _pendingCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingCheck = false;
      if (!mounted) return;
      final render = context.findRenderObject();
      final size = MediaQuery.maybeSizeOf(context);
      if (render is RenderBox && render.hasSize && size != null) {
        final rect = render.localToGlobal(Offset.zero) & render.size;
        _visible = rect.overlaps(Offset.zero & size);
      }
      _sync();
    });
  }

  void _sync() {
    if (!mounted) return;
    final enabled =
        widget.active &&
        !GrowzaMotion.reduced(context) &&
        TickerMode.valuesOf(context).enabled &&
        _foreground &&
        _visible;
    if (enabled && !_controller.isAnimating) _controller.repeat();
    if (!enabled && _controller.isAnimating) _controller.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _position?.removeListener(_scheduleVisibility);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => _MotionPhase(
      phase: GrowzaMotion.reduced(context) || !widget.active
          ? 0
          : _controller.value,
      child: Builder(builder: (inner) => widget.builder(inner, child)),
    ),
  );
}

class _MotionPhase extends InheritedWidget {
  const _MotionPhase({required this.phase, required super.child});
  final double phase;
  @override
  bool updateShouldNotify(_MotionPhase oldWidget) => oldWidget.phase != phase;
}

class MotionPress extends StatefulWidget {
  const MotionPress({super.key, required this.child});
  final Widget child;
  @override
  State<MotionPress> createState() => _MotionPressState();
}

class _MotionPressState extends State<MotionPress> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => _pressed = true),
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed && !GrowzaMotion.reduced(context)
          ? GrowzaMotion.pressScale
          : 1,
      duration: GrowzaMotion.reduced(context)
          ? Duration.zero
          : GrowzaMotion.press,
      child: widget.child,
    ),
  );
}

class MotionValue extends StatelessWidget {
  const MotionValue(this.value, {super.key, this.style, this.align});
  final String value;
  final TextStyle? style;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: GrowzaMotion.reduced(context)
        ? Duration.zero
        : GrowzaMotion.numbers,
    child: Text(value, key: ValueKey(value), style: style, textAlign: align),
  );
}

class GrowzaPageTransitions extends PageTransitionsBuilder {
  const GrowzaPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (GrowzaMotion.reduced(context)) return child;
    final eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .02),
          end: Offset.zero,
        ).animate(eased),
        child: child,
      ),
    );
  }
}

class GrowzaRoute<T> extends MaterialPageRoute<T> {
  GrowzaRoute({required super.builder, super.settings, super.fullscreenDialog});
  @override
  Duration get transitionDuration => GrowzaMotion.route;
  @override
  Duration get reverseTransitionDuration => GrowzaMotion.route;
}
