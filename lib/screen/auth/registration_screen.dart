import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'verify_email_screen.dart';

enum UserType { user, owner } // مستخدم عادي أو صاحب شاليه

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  // ألوان TikTok (pastel) لتوحيد الثيم
  static const Color _pink = Color(0xFFFE2C55);
  static const Color _cyan = Color(0xFF06B6D4); // أغمق شوي من السماوي

  final _formKey = GlobalKey<FormState>();

  // عام
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // حقول خاصة لصاحب الشاليه
  final _chaletName = TextEditingController();
  final _chaletAddress = TextEditingController();

  UserType _userType = UserType.user; // الافتراضي: مستخدم عادي
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;
  bool _loading = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _chaletName.dispose();
    _chaletAddress.dispose();
    super.dispose();
  }

  // ====================== Helpers ======================

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'هذا البريد مستخدم من قبل.';
      case 'invalid-email':
        return 'بريد إلكتروني غير صالح.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة (6 أحرف فأكثر).';
      case 'operation-not-allowed':
        return 'تم تعطيل طريقة التسجيل هذه.';
      case 'network-request-failed':
        return 'مشكلة اتصال بالشبكة.';
      default:
        return 'خطأ (${e.code}). حاول لاحقًا.';
    }
  }

  Future<void> _createUserDoc({
    required User user,
    required String first,
    required String last,
    required String email,
    String? phone,
    required UserType type,
    String? chaletName,
    String? chaletAddress,
    bool overwriteIfExists = false,
  }) async {
    final users = FirebaseFirestore.instance.collection('users').doc(user.uid);

    final data = {
      'uid': user.uid,
      'firstName': first,
      'lastName': last,
      'email': email,
      'phone': phone ?? '',
      'userType': type.name, // 'user' or 'owner'
      if (type == UserType.owner) ...{
        'chaletName': chaletName ?? '',
        'chaletAddress': chaletAddress ?? '',
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'emailVerified': user.emailVerified,
    };

    final snap = await users.get();
    if (!snap.exists || overwriteIfExists) {
      await users.set(data, SetOptions(merge: true));
    }

    if (type == UserType.owner) {
      await _ensureOwnerChaletDoc(
        user: user,
        phone: phone,
        chaletName: chaletName,
        chaletAddress: chaletAddress,
      );
    }
  }

  Future<void> _ensureOwnerChaletDoc({
    required User user,
    String? chaletName,
    String? chaletAddress,
    String? phone,
  }) async {
    final chalets =
        FirebaseFirestore.instance.collection('chalets').doc(user.uid);
    final snapshot = await chalets.get();

    final trimmedName = chaletName?.trim() ?? '';
    final trimmedAddress = chaletAddress?.trim() ?? '';
    final trimmedPhone = phone?.trim() ?? '';

    if (!snapshot.exists) {
      await chalets.set({
        'ownerId': user.uid,
        'name': trimmedName,
        'location': trimmedAddress,
        'phone': trimmedPhone,
        'price': 0,
        'description': '',
        'availability': {},
        'likes': 0,
        'commentsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAvailabilityAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final updates = <String, dynamic>{
      'ownerId': user.uid,
    };

    if (trimmedName.isNotEmpty) updates['name'] = trimmedName;
    if (trimmedAddress.isNotEmpty) updates['location'] = trimmedAddress;
    if (trimmedPhone.isNotEmpty) updates['phone'] = trimmedPhone;

    if (updates.length > 1) {
      await chalets.set(updates, SetOptions(merge: true));
    }
  }


  Future<void> _onRegister() async {
    FocusScope.of(context).unfocus();

    if (_userType == UserType.owner) {
      if (_chaletName.text.trim().isEmpty ||
          _chaletAddress.text.trim().length < 5) {
        _toast('يرجى إدخال اسم وعنوان الشاليه بشكل صحيح');
        return;
      }
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      _toast('يجب الموافقة على الشروط والأحكام');
      return;
    }

    final email = _email.text.trim().toLowerCase();

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.setLanguageCode('ar');

      // فحص مسبق لأي مزوّد
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(
        email,
      );
      if (methods.isNotEmpty) {
        _toast(
          'هذا البريد مستخدم من قبل. جرّب تسجيل الدخول أو استعادة كلمة المرور.',
        );
        return;
      }

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _password.text,
      );

      await cred.user?.updateDisplayName(
        '${_first.text.trim()} ${_last.text.trim()}',
      );

      await _createUserDoc(
        user: cred.user!,
        first: _first.text.trim(),
        last: _last.text.trim(),
        email: email,
        phone: _phone.text.trim(),
        type: _userType,
        chaletName: _userType == UserType.owner
            ? _chaletName.text.trim()
            : null,
        chaletAddress: _userType == UserType.owner
            ? _chaletAddress.text.trim()
            : null,
      );

      await cred.user!.sendEmailVerification();

      _toast('تم إنشاء الحساب — تفقد بريدك لتأكيده');
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-continue-uri' ||
          e.code == 'missing-android-pkg-name' ||
          e.code == 'unauthorized-continue-uri') {
        _toast(
          'تم إنشاء الحساب لكن فشل إرسال التحقق بإعدادات الرابط. أعد المحاولة بدون إعدادات مخصّصة.',
        );
      } else {
        _toast(_mapAuthError(e));
      }
    } catch (e) {
      _toast('حدث خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ====================== Google Sign-Up / Sign-In ======================

  Future<void> _onGoogle() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.setLanguageCode('ar');

      UserCredential credential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        credential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final gUser = await GoogleSignIn().signIn();
        if (gUser == null) return; // المستخدم لغى العملية
        final gAuth = await gUser.authentication;
        final googleCred = GoogleAuthProvider.credential(
          accessToken: gAuth.accessToken,
          idToken: gAuth.idToken,
        );
        credential = await FirebaseAuth.instance.signInWithCredential(
          googleCred,
        );
      }

      final user = credential.user!;
      await _createUserDoc(
        user: user,
        first: _first.text.trim().isEmpty
            ? (user.displayName?.split(' ').first ?? '')
            : _first.text.trim(),
        last: _last.text.trim().isEmpty
            ? (user.displayName?.split(' ').skip(1).join(' ') ?? '')
            : _last.text.trim(),
        email: (user.email ?? _email.text.trim()).toLowerCase(),
        phone: _phone.text.trim(),
        type: _userType,
        chaletName: _userType == UserType.owner
            ? _chaletName.text.trim()
            : null,
        chaletAddress: _userType == UserType.owner
            ? _chaletAddress.text.trim()
            : null,
      );

      _toast('تم الدخول عبر Google ✅');
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      _toast(_mapAuthError(e));
    } catch (e) {
      _toast(
        'فشل تسجيل Google. تأكد من إضافة SHA-1/256 في Firebase لمشروع Android.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ====================== UI ======================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // عربي RTL
      child: Scaffold(
        body: Stack(
          children: [
            // خلفية متدرجة ناعمة (مطابقة للّوجين/السلاش)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFDFDFE), Color(0xFFF5FBFC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // تموجات شفافة علوية وسفلية
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: ClipPath(
                  clipper: _TopWaveClipper(),
                  child: Container(
                    height: 210,
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
                    height: 250,
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
            // توهجات خفيفة للعمق
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
                  // AppBar يدوي بسيط (يمين: رجوع — وسط: العنوان)
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
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'رجوع',
                        ),
                        const Spacer(),
                        const Text(
                          'سجّل الآن',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  // المحتوى — منزّل شوي للوسط (paddingVertical أكبر)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),

                            // نوع الحساب (ChoiceChips)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text('نوع الحساب', style: _labelBold()),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                _choiceChip(
                                  label: 'مستخدم عادي',
                                  selected: _userType == UserType.user,
                                  onTap: () =>
                                      setState(() => _userType = UserType.user),
                                ),
                                _choiceChip(
                                  label: 'صاحب شاليه',
                                  selected: _userType == UserType.owner,
                                  onTap: () => setState(
                                    () => _userType = UserType.owner,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // الاسم الأول/الثاني
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _first,
                                    decoration: _input(
                                      'الاسم الأول',
                                      const Icon(Icons.person),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'أدخل الاسم الأول'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _last,
                                    decoration: _input(
                                      'اسم العائلة',
                                      const Icon(Icons.person_outline),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'أدخل اسم العائلة'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // البريد الإلكتروني
                            TextFormField(
                              controller: _email,
                              decoration: _input(
                                'البريد الإلكتروني',
                                const Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'أدخل بريدك الإلكتروني';
                                final ok = RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(v.trim());
                                return ok ? null : 'البريد الإلكتروني غير صالح';
                              },
                            ),
                            const SizedBox(height: 12),

                            // رقم الهاتف
                            TextFormField(
                              controller: _phone,
                              decoration: _input(
                                'رقم الهاتف',
                                const Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                final s = v?.trim() ?? '';
                                return s.isEmpty || s.length >= 7
                                    ? null
                                    : 'أدخل رقمًا صحيحًا';
                              },
                            ),
                            const SizedBox(height: 12),

                            // حقول إضافية لصاحب الشاليه
                            if (_userType == UserType.owner) ...[
                              TextFormField(
                                controller: _chaletName,
                                decoration: _input(
                                  'اسم الشاليه',
                                  const Icon(Icons.home_work),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'أدخل اسم الشاليه'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _chaletAddress,
                                decoration: _input(
                                  'عنوان الشاليه',
                                  const Icon(Icons.location_on),
                                  hint: 'المدينة / المنطقة / الشارع',
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().length < 5)
                                    ? 'أدخل عنوانًا مفصّلًا'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                            ],

                            // كلمة المرور
                            TextFormField(
                              controller: _password,
                              obscureText: _obscurePass,
                              decoration: _input(
                                'كلمة المرور',
                                const Icon(Icons.lock),
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePass
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePass = !_obscurePass,
                                  ),
                                ),
                              ),
                              validator: (v) => (v != null && v.length >= 6)
                                  ? null
                                  : 'الحد الأدنى 6 أحرف',
                            ),
                            const SizedBox(height: 12),

                            // تأكيد كلمة المرور
                            TextFormField(
                              controller: _confirm,
                              obscureText: _obscureConfirm,
                              decoration: _input(
                                'تأكيد كلمة المرور',
                                const Icon(Icons.lock_outline),
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                                ),
                              ),
                              validator: (v) => (v == _password.text)
                                  ? null
                                  : 'كلمتا المرور غير متطابقتين',
                            ),
                            const SizedBox(height: 8),

                            // الموافقة على الشروط
                            Row(
                              children: [
                                Checkbox(
                                  value: _acceptTerms,
                                  onChanged: (v) =>
                                      setState(() => _acceptTerms = v ?? false),
                                  activeColor: _pink,
                                ),
                                const Expanded(
                                  child: Text('أوافق على الشروط والأحكام'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // زر التسجيل (وردي موحّد مع اللوجين/ويلكم)
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _pink,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _loading ? null : _onRegister,
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'سجّل الآن',
                                        style: TextStyle(color: Colors.white),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),

                            // التسجيل عبر جوجل (Outlined Cyan)
                            const Center(child: Text('أو أنشئ حسابًا بواسطة')),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _onGoogle,
                                icon: const Icon(Icons.g_mobiledata, size: 28),
                                label: const Text('Google'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: const BorderSide(
                                    color: _cyan,
                                    width: 1.4,
                                  ),
                                  foregroundColor: _cyan,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),

            if (_loading)
              Container(
                color: Colors.black.withOpacity(0.08),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------- أدوات تصميم موحدة --------------------
  TextStyle _labelBold() => const TextStyle(fontWeight: FontWeight.w700);

  InputDecoration _input(
    String label,
    Icon prefix, {
    Widget? suffix,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _pink,
      side: BorderSide(color: selected ? _pink : Colors.black.withOpacity(.12)),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// Clippers للتموّجات (نفس المستخدمة في الشاشات الأخرى)
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
