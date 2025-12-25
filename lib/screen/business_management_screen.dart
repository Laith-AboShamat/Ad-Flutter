import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'auth/login_screen.dart';
import '../features/owner_reports/owner_reports_screen.dart';
import '../features/owner_expenses/expenses_screen.dart';
import 'home_screen.dart';

class BusinessManagementScreen extends StatefulWidget {
  const BusinessManagementScreen({super.key});

  @override
  State<BusinessManagementScreen> createState() =>
      _BusinessManagementScreenState();
}

class _BusinessManagementScreenState extends State<BusinessManagementScreen> {
  Map<String, dynamic>? _availability;
  bool _initialLoading = true;
  bool _uploading = false;
  double _uploadProgress = 0.0;
  String? _videoDownloadUrl;
  bool _savingPrice = false;

  Future<void> _savePrice() async {
    final raw = _price.text.trim();
    final value = num.tryParse(raw);

    if (raw.isEmpty || value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل سعرًا صحيحًا')),
      );
      return;
    }

    setState(() => _savingPrice = true);

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
      );
      setState(() => _savingPrice = false);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('chalets')
          .doc(user.uid)
          .set({
        'ownerId': user.uid,
        'price': value,
        'updatedPriceAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ السعر بنجاح ✅')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }

    setState(() => _savingPrice = false);
  }

  bool _savingDescription = false;

  Future<void> _saveDescription() async {
    final desc = _description.text.trim();

    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل وصف الشاليه')),
      );
      return;
    }

    setState(() => _savingDescription = true);

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
      );
      setState(() => _savingDescription = false);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('chalets')
          .doc(user.uid)
          .set({
        'ownerId': user.uid,
        'description': desc,
        'updatedDescriptionAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الوصف بنجاح ✅')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }

    setState(() => _savingDescription = false);
  }

  bool _savingCalendar = false;
  Future<void> _saveCalendar() async {

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
      );
      return;
    }

    setState(() {
      _savingCalendar = true;
    });

    try {
      final monthKey =
          "${_visibleMonth.year.toString().padLeft(4, '0')}-${_visibleMonth.month.toString().padLeft(2, '0')}";

      final daysMap = {
        for (final e in _booked.entries) e.key: e.value,
      };

      final docRef =
      FirebaseFirestore.instance.collection('chalets').doc(user.uid);

      await docRef.set({
        'ownerId': user.uid,
        'availability': {
          monthKey: daysMap,
        },
        'updatedAvailabilityAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _availability ??= {};
      _availability![monthKey] = daysMap;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التقويم لهذا الشهر ✅')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ التقويم: $e')),
      );
    }

    setState(() {
      _savingCalendar = false;
    });
  }
  void _applyAvailabilityForCurrentMonth() {
    if (_availability == null) return;

    final monthKey =
        "${_visibleMonth.year.toString().padLeft(4, '0')}-${_visibleMonth.month.toString().padLeft(2, '0')}";

    final monthData = _availability![monthKey];
    if (monthData is Map<String, dynamic>) {
      monthData.forEach((dateKey, value) {
        if (value is bool && _booked.containsKey(dateKey)) {
          _booked[dateKey] = value;
        }
      });
      setState(() {});
    }
  }


  Future<void> _loadChaletData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _initialLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('chalets')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        final priceValue = data['price'];
        if (priceValue != null) {
          _price.text = priceValue.toString();
        }

        final descValue = data['description'];
        if (descValue is String) {
          _description.text = descValue;
        }
        final avail = data['availability'];
        if (avail is Map<String, dynamic>) {
          _availability = avail;
          _applyAvailabilityForCurrentMonth();
        }

        final existingVideoName = data['videoFileName'];
        if (existingVideoName is String && existingVideoName.isNotEmpty) {
          _videoFileName = existingVideoName;
        }
        final existingVideoStatus = data['videoStatus'];
        if (existingVideoStatus is String && existingVideoStatus.isNotEmpty) {
          _videoStatus = existingVideoStatus;
        }
        final existingVideoUrl = data['videoUrl'];
        if (existingVideoUrl is String && existingVideoUrl.isNotEmpty) {
          _videoDownloadUrl = existingVideoUrl;
        }
      }
    } catch (e) {
      debugPrint('Error loading chalet data: $e');
    }

    setState(() => _initialLoading = false);
  }






  static const Color _pink = Color(0xFFFE2C55);
  static const Color _cyan = Color(0xFF06B6D4);

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  String? _videoFileName;
  String? _videoFilePath;
  String? _videoStatus; // pending / approved / denied

  DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  final Map<String, bool> _booked = {};

  @override
  void initState() {
    super.initState();
    _initMonthGrid(_visibleMonth);
    _loadChaletData();
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  // ---------------------- VIDEO PICKING ----------------------

  Future<void> _pickVideo() async {
    final XFile? picked = await _picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (!mounted) return;

    if (picked == null) {
      // المستخدم رجع بدون اختيار فيديو → لا نعمل شيء
      return;
    }

    setState(() {
      _videoFileName = picked.name;
      _videoFilePath = picked.path;
    });
  }

  void _removeVideo() {
    setState(() {
      _videoFileName = null;
      _videoFilePath = null;
    });
  }


  Future<void> _uploadVideoToStorage() async {
    if (_videoFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر فيديو أولاً')),
      );
      return;
    }

    try {
      setState(() {
        _uploading = true;
        _uploadProgress = 0;
      });

      // 1️⃣ Get owner UID
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // 2️⃣ Fetch chalet belonging to this owner
      final snapshot = await FirebaseFirestore.instance
          .collection('chalets')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على شاليه لهذا المالك')),
        );
        return;
      }

      // 3️⃣ This is your chalet document ID
      final chaletId = snapshot.docs.first.id;

      // 4️⃣ Upload video to Storage
      final file = File(_videoFilePath!);
      final fileName = 'chalet_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final ref = FirebaseStorage.instance
          .ref()
          .child('chalets_videos/$fileName');

      final uploadTask = ref.putFile(file);

      uploadTask.snapshotEvents.listen((e) {
        final total = e.totalBytes;
        final transferred = e.bytesTransferred;
        if (total > 0) {
          setState(() {
            _uploadProgress = transferred / total;
          });
        }
      });

      final storageSnap = await uploadTask;
      final downloadUrl = await storageSnap.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('chalets')
          .doc(chaletId)
          .set({
        'videoFileName': fileName,
        'videoUrl': downloadUrl,
        'videoStatus': 'pending',
        'likes': FieldValue.increment(0),
        'commentsCount': FieldValue.increment(0),
        'updatedVideoAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _uploading = false;
        _videoDownloadUrl = downloadUrl;
        _videoFileName = fileName;
        _videoStatus = 'pending';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفع الفيديو، بانتظار موافقة الإدارة ✅'),
        ),
      );
    } catch (e) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في رفع الفيديو: $e')),
      );
    }
  }


  void _initMonthGrid(DateTime month) {
    _booked.clear();
    final int year = month.year;
    final int mon = month.month;
    final int daysInMonth = DateTime(year, mon + 1, 0).day;
    for (int d = 1; d <= daysInMonth; d++) {
      final key = _keyOf(DateTime(year, mon, d));
      _booked.putIfAbsent(key, () => false);
    }
    setState(() {});
  }

  String _keyOf(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  void _prevMonth() {
    final m = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    _visibleMonth = m;
    _initMonthGrid(m);
    _applyAvailabilityForCurrentMonth();
  }

  void _nextMonth() {
    final m = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    _visibleMonth = m;
    _initMonthGrid(m);
    _applyAvailabilityForCurrentMonth();
  }


  bool _isPastDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isBefore(today);
  }

  void _toggleDay(DateTime day) {
    // Don't allow toggling past dates
    if (_isPastDate(day)) return;
    
    final key = _keyOf(day);
    if (_booked.containsKey(key)) {
      setState(() => _booked[key] = !(_booked[key]!));
    }
  }

  void _setAll(bool booked) {
    setState(() {
      for (final k in _booked.keys) {
        // Parse the date from the key
        final parts = k.split('-');
        if (parts.length == 3) {
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          // Skip past dates
          if (!_isPastDate(date)) {
            _booked[k] = booked;
          }
        }
      }
    });
  }

  Color _dayColor(bool isBooked, DateTime date) {
    if (_isPastDate(date)) {
      return Colors.grey;
    }
    return isBooked ? Colors.red : Colors.green;
  }

  String _dayLabel(bool isBooked, DateTime date) {
    if (_isPastDate(date)) {
      return 'منتهي';
    }
    return isBooked ? 'محجوز' : 'متاح';
  }

  // ---------------------- SAVE ----------------------

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _name.text.trim(),
      'location': _location.text.trim(),
      'price': _price.text.trim(),
      'description': _description.text.trim(),
      'month': {
        'year': _visibleMonth.year,
        'month': _visibleMonth.month,
      },
      'days': {
        for (final e in _booked.entries)
          e.key: e.value ? 'booked' : 'available',
      },
      'videoName': _videoFileName ?? '',
      'videoPath': _videoFilePath ?? '',
    };

    // TODO: هنا تقدر تبعت data للسيرفر حقك

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ بيانات الشاليه ✅'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------- BUILD ----------------------

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xfff5f7fa),
        body: Stack(
          children: [
            // خلفية ناعمة
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
                  // AppBar custom
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.home_work_outlined,
                                    color: Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'إدارة الشاليه',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.home_outlined,
                              color: Colors.black87,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const HomeScreen()),
                              );
                            },
                            tooltip: 'العودة للتطبيق',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.analytics_outlined,
                              color: Colors.black87,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const OwnerReportsScreen(),
                                ),
                              );
                            },
                            tooltip: 'التقارير',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: Colors.black87,
                            ),
                            onPressed: () async {
                              try {
                                await FirebaseAuth.instance.signOut();
                                try {
                                  await GoogleSignIn().signOut();
                                } catch (_) {}
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('حدث خطأ أثناء تسجيل الخروج: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                            tooltip: 'تسجيل الخروج',
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadChaletData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            // بطاقة الفيديو + حالة الموافقة
                            _VideoCard(
                              pink: _pink,
                              cyan: _cyan,
                              fileName: _videoFileName,
                              onPick: _pickVideo,
                              onRemove: _removeVideo,
                              onUpload: _uploadVideoToStorage,
                              uploading: _uploading,
                              progress: _uploadProgress,
                              uploaded: _videoDownloadUrl != null,
                              status: _videoStatus,
                            ),

                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _price,
                              keyboardType: TextInputType.number,
                              decoration: _input(
                                'سعر الحجز (₪)',
                              ),
                            ),
                            const SizedBox(height: 8),

                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _savingPrice ? null : _savePrice,
                                icon: _savingPrice
                                    ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                    : const Icon(Icons.cloud_upload),
                                label: Text(_savingPrice ? 'جاري الحفظ...' : 'حفظ السعر'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _cyan,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _description,
                              decoration: _input(
                                'وصف الشاليه (عدد الغرف، المرافق…)',
                              ),
                              minLines: 3,
                              maxLines: 6,
                            ),
                            const SizedBox(height: 8),

                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _savingDescription ? null : _saveDescription,
                                icon: _savingDescription
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.cloud_upload),
                                label: Text(_savingDescription ? 'جاري الحفظ...' : 'حفظ الوصف'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _pink,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const OwnerExpensesScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.receipt_long_rounded),
                                label: const Text('المصاريف'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black87,
                                  side: const BorderSide(color: Colors.black26),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // التقويم
                            _MonthCalendar(
                              month: _visibleMonth,
                              bookedMap: _booked,
                              onPrev: _prevMonth,
                              onNext: _nextMonth,
                              onToggle: _toggleDay,
                              dayColor: (isBooked, date) => _dayColor(isBooked, date),
                              dayLabel: (isBooked, date) => _dayLabel(isBooked, date),
                            ),

                            const SizedBox(height: 20),

                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.event_available),
                                  label: const Text('تحديد الشهر متاح'),
                                  onPressed: () => _setAll(false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green.shade700,
                                    side: BorderSide(
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.event_busy),
                                  label: const Text('تحديد الشهر محجوز'),
                                  onPressed: () => _setAll(true),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    side: BorderSide(
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                ),
                                _legendBox(color: Colors.green, label: 'متاح'),
                                _legendBox(color: Colors.red, label: 'محجوز'),
                                _legendBox(color: Colors.grey, label: 'منتهي'),
                              ],
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _pink,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _savingCalendar ? null : _saveCalendar,
                                child: Text(
                                  _savingCalendar ? 'جاري حفظ التقويم...' : 'حفظ التقويم',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------- HELPERS ----------------------

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

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _cyan, width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _legendBox({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.black87)),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  final Color pink;
  final Color cyan;
  final String? fileName;
  final String? status; // pending / approved / denied
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final VoidCallback onUpload;
  final bool uploading;
  final double progress;
  final bool uploaded;

  const _VideoCard({
    required this.pink,
    required this.cyan,
    required this.fileName,
    required this.status,
    required this.onPick,
    required this.onRemove,
    required this.onUpload,
    required this.uploading,
    required this.progress,
    required this.uploaded,
  });

  @override
  Widget build(BuildContext context) {
    final hasVideo = fileName != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            pink.withOpacity(0.04),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // avatar circle
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [pink, cyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),

          // text + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName ?? 'ارفع فيديو للشاليه من المعرض',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fileName == null ? Colors.black54 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الصيغ المدعومة: MP4 / MOV',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                if (hasVideo && status != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        status == 'approved'
                            ? Icons.verified_rounded
                            : status == 'denied'
                                ? Icons.block
                                : Icons.hourglass_bottom_rounded,
                        size: 16,
                        color: status == 'approved'
                            ? Colors.green
                            : status == 'denied'
                                ? Colors.red
                                : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          status == 'approved'
                              ? 'تمت الموافقة على الفيديو ✅'
                              : status == 'denied'
                                  ? 'تم رفض الفيديو ❌'
                                  : 'في انتظار موافقة الإدارة ⏳',
                          style: TextStyle(
                            fontSize: 12,
                            color: status == 'approved'
                                ? Colors.green
                                : status == 'denied'
                                    ? Colors.red
                                    : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (uploading) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress == 0 ? null : progress,
                    minHeight: 4,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'جاري الرفع ${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ] else if (uploaded) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'تم رفع الفيديو',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),
          if (fileName != null)
            IconButton(
              tooltip: 'إزالة الفيديو',
              icon: const Icon(Icons.close_rounded),
              onPressed: uploading ? null : onRemove,
            ),
          Column(
            children: [
              ElevatedButton(
                onPressed: uploading ? null : onPick,
                style: ElevatedButton.styleFrom(
                  backgroundColor: pink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(fileName == null ? 'اختيار' : 'تغيير'),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed:
                (fileName == null || uploading || uploaded) ? null : onUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: uploaded ? Colors.green : cyan,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  uploaded
                      ? 'مرفوع'
                      : (uploading ? 'جاري الرفع' : 'رفع للتخزين'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),

    );
  }
}

// ---------------------- CALENDAR ----------------------

class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final Map<String, bool> bookedMap;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(DateTime day) onToggle;
  final Color Function(bool isBooked, DateTime date) dayColor;
  final String Function(bool isBooked, DateTime date) dayLabel;

  const _MonthCalendar({
    required this.month,
    required this.bookedMap,
    required this.onPrev,
    required this.onNext,
    required this.onToggle,
    required this.dayColor,
    required this.dayLabel,
  });

  int _daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;

  int _satLeadingBlanks(DateTime m) {
    final w = DateTime(m.year, m.month, 1).weekday;
    if (w == 6) return 0;
    if (w == 7) return 1;
    return w + 1;
  }

  @override
  Widget build(BuildContext context) {
    final daysCount = _daysInMonth(month);
    final leading = _satLeadingBlanks(month);
    final cells = leading + daysCount;
    final rows = (cells / 7).ceil();

    final headerStyle =
    Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final capped = MediaQuery.of(context).copyWith(
      textScaleFactor: MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.15),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(.08)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "${_arabicMonthName(month.month)} ${month.year}",
                    style: headerStyle,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
          const SizedBox(height: 6),

          MediaQuery(
            data: capped,
            child: Row(
              children: const [
                _DayHeader('السبت'),
                _DayHeader('الأحد'),
                _DayHeader('الاثنين'),
                _DayHeader('الثلاثاء'),
                _DayHeader('الأربعاء'),
                _DayHeader('الخميس'),
                _DayHeader('الجمعة'),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Column(
            children: List.generate(rows, (r) {
              return Row(
                children: List.generate(7, (c) {
                  final cellIndex = r * 7 + c;
                  final dayNumber = cellIndex - leading + 1;
                  if (dayNumber < 1 || dayNumber > daysCount) {
                    return const Expanded(child: SizedBox(height: 54));
                  }
                  final date = DateTime(month.year, month.month, dayNumber);
                  final key =
                      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                  final booked = bookedMap[key] ?? false;
                  
                  // Check if date is in the past
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final dateOnly = DateTime(date.year, date.month, date.day);
                  final isPast = dateOnly.isBefore(today);

                  return Expanded(
                    child: GestureDetector(
                      onTap: isPast ? null : () => onToggle(date),
                      child: Opacity(
                        opacity: isPast ? 0.5 : 1.0,
                        child: Container(
                          height: 54,
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: dayColor(booked, date),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.black.withOpacity(.06),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dayNumber.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dayLabel(booked, date),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _arabicMonthName(int m) {
    const names = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return names[m - 1];
  }
}

// ---------------------- DAY HEADER ----------------------

class _DayHeader extends StatelessWidget {
  final String title;
  const _DayHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _NoWrapText(title: title),
      ),
    );
  }
}

class _NoWrapText extends StatelessWidget {
  final String title;
  const _NoWrapText({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
