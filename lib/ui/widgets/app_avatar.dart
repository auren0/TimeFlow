import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/app_icons.dart';
import '../../data/app_visuals.dart';

/// A rounded app icon. Real OS icons are loaded through [AppIcons]; while they
/// are unavailable (demo data, unsupported platforms) a quiet initial tile is
/// shown instead.
class AppAvatar extends StatefulWidget {
  const AppAvatar({
    super.key,
    required this.appId,
    required this.appName,
    this.size = 44,
    this.heroTag,
    this.showBorder = false,
  });

  final String appId;
  final String appName;
  final double size;
  final String? heroTag;
  final bool showBorder;

  @override
  State<AppAvatar> createState() => _AppAvatarState();
}

class _AppAvatarState extends State<AppAvatar> {
  Uint8List? _bytes;
  bool _loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AppAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appId != widget.appId) {
      _bytes = null;
      _loading = false;
      _request++;
      _load();
    } else if (_bytes == null) {
      // A path may have been learned by live tracking since the last build.
      _load();
    }
  }

  void _load() {
    if (_loading) return;
    _loading = true;
    final int request = ++_request;
    final String appId = widget.appId;
    AppIcons.load(appId).then((Uint8List? bytes) {
      if (request != _request) return;
      _loading = false;
      if (!mounted || bytes == _bytes) return;
      setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppVisual visual = AppVisuals.forApp(widget.appId, widget.appName);
    final BorderRadius radius = BorderRadius.circular(widget.size * 0.28);

    final Widget fallback = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          visual.color.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.24 : 0.14,
          ),
          scheme.surfaceContainerHigh,
        ),
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: visual.icon != null
          ? Icon(visual.icon, size: widget.size * 0.5, color: visual.color)
          : Text(
              AppVisuals.initial(widget.appName),
              style: theme.textTheme.labelLarge?.copyWith(
                color: visual.color,
                fontWeight: FontWeight.w600,
                fontSize: widget.size * 0.32,
              ),
            ),
    );

    final Uint8List? bytes = _bytes;
    Widget avatar = RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: bytes == null
            ? KeyedSubtree(
                key: const ValueKey<String>('fallback'),
                child: fallback,
              )
            : Container(
                key: const ValueKey<String>('icon'),
                width: widget.size,
                height: widget.size,
                decoration: widget.showBorder
                    ? BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      )
                    : null,
                alignment: Alignment.center,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
      ),
    );

    if (widget.heroTag != null) {
      avatar = Hero(
        tag: widget.heroTag!,
        flightShuttleBuilder:
            (
              BuildContext flightContext,
              Animation<double> animation,
              HeroFlightDirection direction,
              BuildContext fromContext,
              BuildContext toContext,
            ) {
              return FadeTransition(
                opacity: animation,
                child: Material(color: Colors.transparent, child: avatar),
              );
            },
        child: avatar,
      );
    }
    return avatar;
  }
}
