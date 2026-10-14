import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sign-in button using Google brand colors (not a proprietary asset copy).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.enabled = true,
    this.label = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final bool busy;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !busy && onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: canTap ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: canTap ? 1 : 0.55,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFF4285F4),
                      ),
                    )
                  else
                    const _GoogleGMark(size: 22),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      busy ? 'Signing in…' : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF3C4043),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
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

class _GoogleGMark extends StatelessWidget {
  const _GoogleGMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    // Simple multicolor "G" mark in official Google palette hues.
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.18;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final sweep = 1.7 * 3.14159;
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect.deflate(stroke / 2), -0.15, sweep * 0.35, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      rect.deflate(stroke / 2),
      sweep * 0.2,
      sweep * 0.25,
      false,
      paint,
    );
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      rect.deflate(stroke / 2),
      sweep * 0.45,
      sweep * 0.25,
      false,
      paint,
    );
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      rect.deflate(stroke / 2),
      sweep * 0.7,
      sweep * 0.3,
      false,
      paint,
    );

    final bar = Paint()..color = const Color(0xFF4285F4);
    final cy = size.height / 2;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.45,
        cy - stroke / 2,
        size.width * 0.42,
        stroke,
      ),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Soft neon panel used on auth / account surfaces.
class AuthNeonPanel extends StatelessWidget {
  const AuthNeonPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: child,
    );
  }
}
