// lib/widgets/buttons.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/brand.dart';

class FilledGradientButton extends StatelessWidget {
  const FilledGradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.textColor = Colors.white,
    this.gradient,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color textColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final g = gradient ??
        const LinearGradient(
          colors: [Brand.red, Color(0xFFF74B8B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    return SizedBox(
      height: 50,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: g,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton.icon(
          icon: Icon(icon, size: 22),
          label: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: textColor,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onTap,
        ),
      ),
    );
  }
}

class OutlineNeonButton extends StatelessWidget {
  const OutlineNeonButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.borderOpacity = .18,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.cairo(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: Colors.white.withOpacity(borderOpacity),
            width: 1.2,
          ),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: icon,
        label: Text(
          label,
          style: GoogleFonts.cairo(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(.15), width: 1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onPressed: onTap,
      ),
    );
  }
}
