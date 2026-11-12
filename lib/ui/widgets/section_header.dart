import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onAction,
    this.actionLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 12), trailing!],
        if (onAction != null && actionLabel != null) ...<Widget>[
          const SizedBox(width: 4),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

/// Small rounded statistic used inside cards and headers.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color tint = accent ?? scheme.primary;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: compact ? 28 : 34,
            height: compact ? 28 : 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: compact ? 15 : 18, color: tint),
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleLarge)
                    ?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact pill with an icon and text.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    this.color,
    this.background,
    this.pulse = false,
  });

  final String label;
  final IconData icon;
  final Color? color;
  final Color? background;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color tint = color ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget labelText = Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tint,
              fontWeight: FontWeight.w600,
            ),
          );
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _PulseDot(color: tint, pulse: pulse),
              const SizedBox(width: 6),
              if (constraints.maxWidth.isFinite)
                Flexible(child: labelText)
              else
                labelText,
            ],
          );
        },
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.pulse});

  final Color color;
  final bool pulse;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) {
      return Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double t = _controller.value;
        return SizedBox(
          width: 12,
          height: 12,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Opacity(
                opacity: (1 - t) * 0.5,
                child: Container(
                  width: 7 + t * 5,
                  height: 7 + t * 5,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
