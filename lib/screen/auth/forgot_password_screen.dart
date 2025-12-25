import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color _pink = Color(0xFFFE2C55);
  static const Color _cyan = Color(0xFF25F4EE);
  static const Color _bg = Color(0xFFF9FBFC);
  static const Color _card = Colors.white;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sending = false;

  final _emailReg = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$',
    caseSensitive: false,
  );

  bool get _isValidEmail => _emailReg.hasMatch(_email.text.trim());

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _onSendCode() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);

    try {
      final email = _email.text.trim();
      await FirebaseAuth.instance.setLanguageCode('ar');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال رابط إعادة التعيين إلى $email ✅',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
      Navigator.maybePop(context);
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'invalid-email' => 'عنوان البريد الإلكتروني غير صالح.',
        'user-not-found' => 'لا يوجد مستخدم بهذا البريد.',
        'network-request-failed' => 'خطأ في الشبكة. تحقّق من الاتصال.',
        'too-many-requests' => 'محاولات كثيرة. جرّب لاحقًا.',
        _ => 'فشل الإرسال (${e.code}).',
      };
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg, style: GoogleFonts.cairo())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ غير متوقع: $e', style: GoogleFonts.cairo()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 72,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x22FE2C55),
                  Color(0x2225F4EE),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 12,
              end: 16,
              top: 8,
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.maybePop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(colors: [_pink, _cyan]),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'نسيت كلمة المرور',
                  style: GoogleFonts.cairo(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),

        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_pink, _cyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    color: _card,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Color(0xFFE7EDF1)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'إعادة تعيين كلمة المرور',
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'أدخل بريدك الإلكتروني لإرسال رابط إعادة التعيين.',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),

                            TextFormField(
                              controller: _email,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              onChanged: (_) => setState(() {}),
                              style: GoogleFonts.cairo(fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'أدخل بريدك الإلكتروني',
                                hintStyle: GoogleFonts.cairo(
                                  color: Colors.black38,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE7EDF1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE7EDF1),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: _pink,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final v = (value ?? '').trim();
                                if (v.isEmpty)
                                  return 'يرجى إدخال البريد الإلكتروني';
                                if (!_emailReg.hasMatch(v))
                                  return 'البريد الإلكتروني غير صالح';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: (_sending || !_isValidEmail)
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFFE9EDF1),
                                            Color(0xFFE9EDF1),
                                          ],
                                        )
                                      : const LinearGradient(
                                          colors: [_pink, _cyan],
                                        ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton(
                                  onPressed: (_sending || !_isValidEmail)
                                      ? null
                                      : _onSendCode,
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _sending
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          'إرسال الرابط',
                                          style: GoogleFonts.cairo(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    kIsWeb
                        ? 'سنعيد توجيهك لصفحة تأكيد على المتصفح.'
                        : 'تفقد بريدك الوارد أو مجلد الرسائل غير المرغوبة.',
                    style: GoogleFonts.cairo(
                      color: Colors.black45,
                      fontSize: 12.5,
                    ),
                    textAlign: TextAlign.center,
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
