import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myadds/screen/auth/forgot_password_screen.dart';
import 'package:myadds/screen/auth/registration_screen.dart';
import 'package:myadds/screen/business_management_screen.dart';
import 'package:myadds/screen/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _pink = Color(0xFFFE2C55);
  static const Color _cyan = Color(0xFF06B6D4);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final uid = cred.user!.uid;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!snap.exists) {
        if (!mounted) return;
        _showSnack('لا توجد بيانات ملف للمستخدم. تواصل مع الدعم.');
        return;
      }

      final type = (snap.data()?['userType'] ?? 'user').toString();
      if (!mounted) return;
      
      // Check if there's a redirect request (e.g., from booking screen)
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final redirectTo = args?['redirectTo'] as String?;
      final bookingArgs = args?['bookingArgs'] as Map<String, dynamic>?;
      
      if (type == 'owner') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BusinessManagementScreen()),
          (route) => false,
        );
      } else {
        // If there's a redirect to checkout with booking args, go there
        if (redirectTo == '/checkout' && bookingArgs != null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
          // Navigate to checkout with booking arguments
          Navigator.of(context).pushNamed('/checkout', arguments: bookingArgs);
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_mapAuthError(e));
    } catch (e) {
      _showSnack('حدث خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
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
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: ClipPath(
                  clipper: _TopWaveClipper(),
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _cyan.withOpacity(.12),
                          _cyan.withOpacity(.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ClipPath(
                  clipper: _BottomWaveClipper(),
                  child: Container(
                    height: 260,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _pink.withOpacity(.10),
                          _pink.withOpacity(.03),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -90,
              right: -70,
              child: _softBlob(_pink.withOpacity(.06), 220),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: _softBlob(_cyan.withOpacity(.07), 260),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.black87,
                          ),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushReplacementNamed(context, '/welcome');
                            }
                          },
                          tooltip: 'رجوع',
                        ),
                        const Spacer(),
                        const Text(
                          "تسجيل الدخول",
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 80,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 24),
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [_pink, _cyan],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                              const SizedBox(height: 20),

                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: _input(
                                        'البريد الإلكتروني',
                                        const Icon(Icons.email_outlined),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'يجب إدخال البريد الإلكتروني';
                                        }
                                        final ok = RegExp(
                                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                        ).hasMatch(v.trim());
                                        if (!ok)
                                          return 'أدخل بريدًا إلكترونيًا صالحًا';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: _input(
                                        'كلمة المرور',
                                        const Icon(Icons.lock_outline),
                                        suffix: IconButton(
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty)
                                          return 'يجب إدخال كلمة المرور';
                                        if (v.length < 6) {
                                          return 'كلمة المرور يجب أن تحتوي على 6 أحرف على الأقل';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ForgotPasswordScreen(),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "نسيت كلمة المرور؟",
                                          style: TextStyle(
                                            color: _cyan,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _pink,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: _loading
                                            ? null
                                            : _signInWithEmail,
                                        child: const Text(
                                          "تسجيل الدخول",
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 28),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text("ليس لديك حساب؟ "),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const RegistrationScreen(),
                                                ),
                                              ),
                                          child: const Text(
                                            'أنشئ حسابًا جديدًا',
                                            style: TextStyle(
                                              color: _cyan,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            if (_loading)
              Container(
                color: Colors.black.withOpacity(0.12),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
  InputDecoration _input(String label, Icon prefix, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _cyan, width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withOpacity(.12)),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  void _showSnack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح.';
      case 'user-disabled':
        return 'تم تعطيل هذا المستخدم.';
      case 'user-not-found':
        return 'لا يوجد مستخدم بهذا البريد.';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة، حاول مجددًا.';
      case 'too-many-requests':
        return 'محاولات كثيرة. حاول لاحقًا.';
      case 'network-request-failed':
        return 'خطأ في الاتصال. تحقق من الإنترنت.';
      default:
        return 'خطأ في تسجيل الدخول (${e.code}).';
    }
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
class _TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.lineTo(0, size.height * .60);
    p.quadraticBezierTo(
      size.width * .25,
      size.height * .40,
      size.width * .50,
      size.height * .55,
    );
    p.quadraticBezierTo(
      size.width * .80,
      size.height * .75,
      size.width,
      size.height * .50,
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
      size.height * .50,
    );
    p.lineTo(size.width, size.height);
    p.lineTo(0, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
