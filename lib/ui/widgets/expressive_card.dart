import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/motion.dart';

/// A rounded, tonal surface with an optional springy press animation.
/// The base building block for the "expressive" look of the app.
class ExpressiveCard extends StatefulWidget {
  const ExpressiveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadius.lg,
    this.color,
    this.borderColor,
    this.onTap,
    this.onLongPress,
    this.enableHover = true,
    this.shadow,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableHover;
  final List<BoxShadow>? shadow;
  final Clip clipBehavior;

  @override
  State<ExpressiveCard> createState() => _ExpressiveCardState();
}

class _ExpressiveCardState extends State<ExpressiveCard> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(widget.radius);
    final bool hovered = _hovered && _interactive && widget.enableHover;

    return Semantics(
      button: _interactive,
      child: MouseRegion(
        cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: _interactive ? (_) => setState(() => _hovered = true) : null,
        onExit: _interactive ? (_) => setState(() => _hovered = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.988 : (hovered ? 1.004 : 1.0),
          duration: AppMotion.quick,
          curve: AppMotion.spring,
          child: AnimatedContainer(
            duration: AppMotion.short,
            curve: AppMotion.emphasized,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: widget.shadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  color: widget.color ?? scheme.surfaceContainerLow,
                  borderRadius: radius,
                  border: widget.borderColor == null
                      ? null
                      : Border.all(color: widget.borderColor!),
                ),
                child: InkWell(
                  borderRadius: radius,
                  onTap: widget.onTap,
                  onLongPress: widget.onLongPress,
                  onHighlightChanged: _interactive
                      ? (bool value) => setState(() => _pressed = value)
                      : null,
                  child: Padding(padding: widget.padding, child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
