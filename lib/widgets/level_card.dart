import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Visual state for a campaign level card.
enum LevelCardState { locked, available, current, completed }

/// Production-ready level tile for the campaign level select screen.
class LevelCard extends StatefulWidget {
  const LevelCard({
    super.key,
    required this.number,
    required this.name,
    required this.state,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.bestScore,
    required this.onTap,
    this.compact = false,
  });

  final int number;
  final String name;
  final LevelCardState state;
  final Color primary;
  final Color secondary;
  final Color accent;
  final int bestScore;
  final VoidCallback? onTap;
  final bool compact;

  bool get isInteractive => state != LevelCardState.locked && onTap != null;

  @override
  State<LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<LevelCard> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  Future<void> _handleTap() async {
    if (!widget.isInteractive) return;
    HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final interactive = widget.isInteractive;
    final lift = (_hovered || _pressed) && interactive;
    final scale = _pressed && interactive ? 0.96 : 1.0;

    final borderColor = switch (state) {
      LevelCardState.current => widget.accent,
      LevelCardState.completed => widget.primary.withValues(alpha: 0.65),
      LevelCardState.available => widget.secondary.withValues(alpha: 0.45),
      LevelCardState.locked => Colors.white.withValues(alpha: 0.08),
    };

    final glowColor = switch (state) {
      LevelCardState.current => widget.accent.withValues(alpha: 0.45),
      LevelCardState.completed => widget.primary.withValues(alpha: 0.22),
      LevelCardState.available => widget.secondary.withValues(alpha: 0.12),
      LevelCardState.locked => Colors.transparent,
    };

    final numberColor = switch (state) {
      LevelCardState.locked => Colors.white.withValues(alpha: 0.28),
      LevelCardState.completed => AppColors.softWhite,
      LevelCardState.current => Colors.white,
      LevelCardState.available => AppColors.softWhite,
    };

    final fill = switch (state) {
      LevelCardState.locked => [
        const Color(0xFF0A0F1C).withValues(alpha: 0.92),
        const Color(0xFF121826).withValues(alpha: 0.88),
      ],
      LevelCardState.completed => [
        widget.primary.withValues(alpha: 0.22),
        const Color(0xFF0C1428).withValues(alpha: 0.95),
      ],
      LevelCardState.current => [
        widget.accent.withValues(alpha: 0.28),
        widget.primary.withValues(alpha: 0.16),
        const Color(0xFF101B3A),
      ],
      LevelCardState.available => [
        widget.secondary.withValues(alpha: 0.16),
        const Color(0xFF10182E).withValues(alpha: 0.96),
      ],
    };

    return MouseRegion(
      onEnter: interactive ? (_) => _setHovered(true) : null,
      onExit: interactive ? (_) => _setHovered(false) : null,
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: interactive ? (_) => _setPressed(true) : null,
        onTapUp: interactive
            ? (_) {
                _setPressed(false);
                _handleTap();
              }
            : null,
        onTapCancel: interactive ? () => _setPressed(false) : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, lift ? -3 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: fill,
              ),
              border: Border.all(
                color: borderColor,
                width: state == LevelCardState.current ? 2 : 1.2,
              ),
              boxShadow: [
                if (state == LevelCardState.current)
                  BoxShadow(
                    color: glowColor,
                    blurRadius: lift ? 22 : 16,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 4),
                  ),
                if (state == LevelCardState.completed)
                  BoxShadow(
                    color: glowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                if (lift && state == LevelCardState.available)
                  BoxShadow(
                    color: widget.secondary.withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Positioned(
                    right: -18,
                    top: -18,
                    child: IgnorePointer(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              (state == LevelCardState.locked
                                      ? Colors.white
                                      : widget.primary)
                                  .withValues(
                                    alpha: state == LevelCardState.locked
                                        ? 0.03
                                        : 0.1,
                                  ),
                        ),
                      ),
                    ),
                  ),
                  if (state == LevelCardState.current)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.accent.withValues(alpha: 0.1),
                              widget.accent,
                              widget.primary,
                              widget.accent.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      widget.compact ? 12 : 14,
                      widget.compact ? 12 : 14,
                      widget.compact ? 12 : 14,
                      widget.compact ? 10 : 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusBadge(
                              state: state,
                              primary: widget.primary,
                              accent: widget.accent,
                            ),
                            const Spacer(),
                            if (state == LevelCardState.current)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.accent.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: widget.accent.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'NEXT',
                                  style: TextStyle(
                                    color: widget.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          '${widget.number}',
                          style: TextStyle(
                            fontSize: widget.compact ? 28 : 34,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            color: numberColor,
                            letterSpacing: -0.5,
                            shadows: state == LevelCardState.current
                                ? [
                                    Shadow(
                                      color: widget.accent.withValues(
                                        alpha: 0.55,
                                      ),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: state == LevelCardState.locked
                                ? Colors.white.withValues(alpha: 0.32)
                                : AppColors.softWhite.withValues(alpha: 0.88),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _FooterMeta(
                          state: state,
                          bestScore: widget.bestScore,
                          accent: widget.accent,
                          primary: widget.primary,
                        ),
                      ],
                    ),
                  ),
                  if (state == LevelCardState.locked)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.state,
    required this.primary,
    required this.accent,
  });

  final LevelCardState state;
  final Color primary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = switch (state) {
      LevelCardState.locked => (
        Icons.lock_rounded,
        Colors.white38,
        Colors.white.withValues(alpha: 0.06),
      ),
      LevelCardState.completed => (
        Icons.check_rounded,
        primary,
        primary.withValues(alpha: 0.18),
      ),
      LevelCardState.current => (
        Icons.play_arrow_rounded,
        accent,
        accent.withValues(alpha: 0.2),
      ),
      LevelCardState.available => (
        Icons.bolt_rounded,
        primary,
        primary.withValues(alpha: 0.14),
      ),
    };

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _FooterMeta extends StatelessWidget {
  const _FooterMeta({
    required this.state,
    required this.bestScore,
    required this.accent,
    required this.primary,
  });

  final LevelCardState state;
  final int bestScore;
  final Color accent;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    if (state == LevelCardState.locked) {
      return Text(
        'Locked',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.28),
        ),
      );
    }

    if (bestScore > 0) {
      return Row(
        children: [
          Icon(
            Icons.emoji_events_rounded,
            size: 13,
            color: accent.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Best $bestScore',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      );
    }

    if (state == LevelCardState.completed) {
      return Text(
        'Cleared',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: primary.withValues(alpha: 0.85),
        ),
      );
    }

    return Text(
      state == LevelCardState.current ? 'Ready to play' : 'Playable',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.softWhite.withValues(alpha: 0.55),
      ),
    );
  }
}
