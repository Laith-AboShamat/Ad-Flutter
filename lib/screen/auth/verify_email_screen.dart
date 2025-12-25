import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const Color _pink = Color(0xFFFE2C55);
  static const Color _cyan = Color(0xFF25F4EE);
  static const Color _bgTop = Color(0xFFFDFDFE);
  static const Color _bgBottom = Color(0xFFF5FBFC);

  bool _isVerified = false;
  bool _sending = false;
  DateTime? _nextSendAt;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    _checkVerification();
    _poll = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _checkVerification(),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _checkVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    final ok = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!mounted) return;
    setState(() => _isVerified = ok);

    if (ok) {
      await user.getIdToken(true);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        return 'محاولات كثيرة خلال وقت قصير. انتظر قليلًا ثم جرّب مجددًا.';
      case 'network-request-failed':
        return 'خطأ في الشبكة. تأكد من اتصالك بالإنترنت.';
      default:
        return 'تعذّر الإرسال: ${e.code}';
    }
  }

  int _secondsLeft() {
    if (_nextSendAt == null) return 0;
    final now = DateTime.now();
    return now.isBefore(_nextSendAt!)
        ? _nextSendAt!.difference(now).inSeconds
        : 0;
  }

  Future<void> _resend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('لا يوجد مستخدم مسجّل.');
      return;
    }
    final left = _secondsLeft();
    if (left > 0) {
      _toast('انتظر $left ثانية قبل إعادة الإرسال.');
      return;
    }

    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance.setLanguageCode('ar');
      await user.sendEmailVerification();
      _nextSendAt = DateTime.now().add(const Duration(seconds: 45));
      HapticFeedback.lightImpact();
      _toast('تم إرسال رسالة تحقق جديدة. افحص البريد/Spam.');
    } on FirebaseAuthException catch (e) {
      _toast(_mapAuthError(e));
    } catch (e) {
      _toast('حدث خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = _secondsLeft();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_bgTop, _bgBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _Wave(
                height: 140,
                colors: [_cyan.withOpacity(.16), _cyan.withOpacity(.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                clipper: _TopWaveClipper(),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Wave(
                height: 180,
                colors: [_pink.withOpacity(.14), _pink.withOpacity(.04)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                clipper: _BottomWaveClipper(),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.black87,
                          ),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'رجوع',
                        ),
                        const Spacer(),
                        const Text(
                          'تأكيد البريد الإلكتروني',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _isVerified
                              ? const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CircularProgressIndicator.adaptive(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _pink,
                                    ),
                                  ),
                                )
                              : _VerifyCard(
                                  pink: _pink,
                                  cyan: _cyan,
                                  sending: _sending,
                                  left: left,
                                  onResend: _resend,
                                  onCheck: _checkVerification,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _VerifyCard extends StatelessWidget {
  const _VerifyCard({
    required this.pink,
    required this.cyan,
    required this.sending,
    required this.left,
    required this.onResend,
    required this.onCheck,
  });

  final Color pink;
  final Color cyan;
  final bool sending;
  final int left;
  final VoidCallback onResend;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [pink, cyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: pink.withOpacity(.25), blurRadius: 20),
                BoxShadow(color: cyan.withOpacity(.20), blurRadius: 20),
              ],
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'افتح بريدك الإلكتروني',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),

          Text(
            'أرسلنا رابط تحقق إلى بريدك. بعد الضغط على الرابط سنلتقط التحقق تلقائيًا، أو اضغط «تم التحقق».',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black.withOpacity(.65), height: 1.6),
          ),
          const SizedBox(height: 22),

          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCheck,
              style: ElevatedButton.styleFrom(
                backgroundColor: pink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              child: const Text('تم التحقق'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: (sending || left > 0) ? null : onResend,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: (sending || left > 0) ? Colors.black26 : cyan,
                  width: 1.4,
                ),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sending) ...[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    const Text('جارٍ الإرسال...'),
                  ] else if (left > 0) ...[
                    const Icon(Icons.timer_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text('أعد الإرسال خلال ${left}s'),
                  ] else ...[
                    const Icon(Icons.refresh_rounded, size: 18),
                    const SizedBox(width: 8),
                    const Text('إعادة إرسال الرسالة'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'تأكد من مجلد Spam/الرسائل غير المرغوب فيها.',
            style: const TextStyle(color: Colors.black54, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _Wave extends StatelessWidget {
  const _Wave({
    required this.height,
    required this.colors,
    required this.begin,
    required this.end,
    required this.clipper,
  });
  final double height;
  final List<Color> colors;
  final Alignment begin;
  final Alignment end;
  final CustomClipper<Path> clipper;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: clipper,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: begin, end: end),
        ),
      ),
    );
  }
}

class _TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.lineTo(0, size.height * .62);
    p.quadraticBezierTo(
      size.width * .25,
      size.height * .40,
      size.width * .50,
      size.height * .56,
    );
    p.quadraticBezierTo(
      size.width * .80,
      size.height * .76,
      size.width,
      size.height * .52,
    );
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.moveTo(0, 0);
    p.quadraticBezierTo(
      size.width * .20,
      size.height * .35,
      size.width * .48,
      size.height * .28,
    );
    p.quadraticBezierTo(
      size.width * .78,
      size.height * .20,
      size.width,
      size.height * .52,
    );
    p.lineTo(size.width, size.height);
    p.lineTo(0, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
