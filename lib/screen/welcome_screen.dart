import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  // Sign out any existing session when entering guest mode
  Future<void> _continueAsGuest(BuildContext context) async {
    try {
      // Sign out from Firebase Auth if there's an active session
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseAuth.instance.signOut();
        // Also sign out from Google Sign In if it was used
        try {
          await GoogleSignIn().signOut();
        } catch (_) {
          // Ignore Google Sign In errors
        }
      }
    } catch (e) {
      // If sign out fails, continue anyway - we'll check auth state in HomeScreen
      debugPrint('Error signing out for guest mode: $e');
    }

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // TikTok Pastel (Soft) Palette
  static const Color _pink = Color(0xFFFE2C55);
  static const Color _cyan = Color(0xFF25F4EE);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final contentW = size.width >= 420 ? 420.0 : size.width - 40;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFDFDFE), Color(0xFFF5FBFC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: -120,
              right: -90,
              child: _softBlob(_pink.withOpacity(.07), 260),
            ),
            Positioned(
              bottom: -120,
              left: -100,
              child: _softBlob(_cyan.withOpacity(.08), 300),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentW),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // العنوان بالنص (Gradient لطيف جدًا)
                        _GradientTitle(
                          text: 'اعلاناتي',

                          gradient: const LinearGradient(
                            colors: [_pink, _cyan],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'أهلا بك في تطبيق إعلاناتي — أول تطبيق شاليهات في فلسطين',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            color: const Color(0xFF1F2937).withOpacity(.75),
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // زر أساسي: تسجيل الدخول (واضح وبسيط)
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/login'),
                            icon: const Icon(Icons.login_rounded),
                            label: Text(
                              'تسجيل الدخول',
                              style: GoogleFonts.cairo(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: _pink, // نبرة وردي ناعمة واضحة
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // زر ثانوي: إنشاء حساب جديد (Outlined بسيان واضح)
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/register'),
                            icon: Icon(
                              Icons.person_add_alt_1_rounded,
                              color: _cyan,
                            ),
                            label: Text(
                              'إنشاء حساب جديد',
                              style: GoogleFonts.cairo(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: BorderSide(color: _cyan, width: 1.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () => _continueAsGuest(context),
                          child: Text(
                            'متابعة كضيف',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827).withOpacity(.75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _softBlob(Color c, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: c, blurRadius: 90, spreadRadius: 50)],
      ),
    );
  }
}
class _GradientTitle extends StatelessWidget {
  final String text;
  final Gradient gradient;
  const _GradientTitle({required this.text, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => gradient.createShader(r),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: .2,
        ),
      ),
    );
  }
}
