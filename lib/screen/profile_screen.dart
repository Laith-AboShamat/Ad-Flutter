import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widget/notification_helper.dart';
import 'auth/login_screen.dart';


const Color kPrimary = Color(0xFFFE2C55);
const Color kAccent = Color(0xFF25F4EE);
const Color kBg = Color(0xFFF9FBFC);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onBackToPrevTab});
  final VoidCallback? onBackToPrevTab;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تسجيل الخروج: $e')),
        );
      }
    }
  }

  Future<void> _checkIn(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'checkInDate': FieldValue.serverTimestamp(),
        'status': 'checked_in',
      });
      if (mounted) {
        NotificationHelper.showSuccess(context, 'تم تسجيل الوصول بنجاح ✅');
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'حدث خطأ: $e');
      }
    }
  }

  Future<void> _checkOut(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'checkOutDate': FieldValue.serverTimestamp(),
        'status': 'checked_out',
      });
      if (mounted) {
        NotificationHelper.showSuccess(context, 'تم تسجيل المغادرة بنجاح ✅');
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'حدث خطأ: $e');
      }
    }
  }

  Future<void> _cancelBooking(String bookingId, String chaletId, List<dynamic> selectedDates) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تأكيد الإلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        content: Text('هل أنت متأكد من إلغاء هذا الحجز؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('نعم، إلغاء', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update booking status
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Free up the dates in chalet availability
      final chaletRef = FirebaseFirestore.instance.collection('chalets').doc(chaletId);
      final doc = await chaletRef.get();
      final data = doc.data() ?? {};
      final availability = Map<String, dynamic>.from(data['availability'] ?? {});

      for (final dateTimestamp in selectedDates) {
        DateTime date;
        if (dateTimestamp is Timestamp) {
          date = dateTimestamp.toDate();
        } else {
          continue;
        }

        final monthKey = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}";
        final dateKey = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

        if (availability.containsKey(monthKey)) {
          final monthData = Map<String, dynamic>.from(availability[monthKey] as Map? ?? {});
          monthData.remove(dateKey);
          availability[monthKey] = monthData;
        }
      }

      await chaletRef.update({
        'availability': availability,
        'updatedAvailabilityAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        NotificationHelper.showSuccess(context, 'تم إلغاء الحجز بنجاح ✅');
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'حدث خطأ: $e');
      }
    }
  }

  String _initials(User? u) {
    final name = (u?.displayName ?? '').trim();
    if (name.isEmpty) return 'إ';
    final parts = name.split(RegExp(r'\s+'));
    final first = parts.first.characters.firstOrNull ?? '';
    final last =
        (parts.length > 1 ? parts.last.characters.firstOrNull : '') ?? '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: Text(
            'ملفي',
            style: GoogleFonts.cairo(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33FE2C55),
                  Color(0x3325F4EE),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 200,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x11FE2C55),
                      Color(0x1125F4EE),
                      Color(0x00FFFFFF),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(140),
                  ),
                ),
              ),
            ),
            user == null
                ? Center(
                    child: Text(
                      'يجب تسجيل الدخول',
                      style: GoogleFonts.cairo(),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _Avatar(photoUrl: user.photoURL, initials: _initials(user)),
                        const SizedBox(height: 12),
                        Text(
                          user.displayName?.trim().isNotEmpty == true
                              ? user.displayName!.trim()
                              : 'مستخدم إعلاناتي',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? 'بدون بريد',
                          style: GoogleFonts.cairo(
                            color: Colors.black54,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Bookings Section
                        Text(
                          'حجوزاتي',
                          style: GoogleFonts.cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('bookings')
                              // Show bookings that belong to the signed-in user
                              .where('userId', isEqualTo: user.uid)
                              // Avoid requiring a composite index; we'll sort client-side.
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'تعذر تحميل الحجوزات. تأكد من الاتصال أو صلاحيات القراءة.',
                                  style: GoogleFonts.cairo(color: Colors.red, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            final docs = snapshot.data?.docs.toList() ?? [];

                            // Sort client-side by createdAt desc to avoid composite index need.
                            docs.sort((a, b) {
                              final at = a['createdAt'];
                              final bt = b['createdAt'];
                              if (at is Timestamp && bt is Timestamp) {
                                return bt.compareTo(at);
                              }
                              return 0;
                            });

                            if (docs.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 12),
                                    Text(
                                      'لا توجد حجوزات',
                                      style: GoogleFonts.cairo(
                                        fontSize: 16,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Column(
                              children: docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final status = data['status'] as String? ?? 'confirmed';
                                final chaletName = data['chaletName'] as String? ?? 'شاليه';
                                final totalDays = data['totalDays'] as int? ?? 0;
                                final totalPrice = data['totalPrice'] as int? ?? 0;
                                final selectedDates = data['selectedDates'] as List<dynamic>? ?? [];
                                final checkInDate = data['checkInDate'] as Timestamp?;
                                final checkOutDate = data['checkOutDate'] as Timestamp?;

                                String statusText = 'مؤكد';
                                Color statusColor = Colors.green;
                                if (status == 'checked_in') {
                                  statusText = 'تم الوصول';
                                  statusColor = Colors.blue;
                                } else if (status == 'checked_out') {
                                  statusText = 'تم المغادرة';
                                  statusColor = Colors.grey;
                                } else if (status == 'cancelled') {
                                  statusText = 'ملغي';
                                  statusColor = Colors.red;
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              chaletName,
                                              style: GoogleFonts.cairo(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              statusText,
                                              style: GoogleFonts.cairo(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (selectedDates.isNotEmpty) ...[
                                        Text(
                                          'التواريخ:',
                                          style: GoogleFonts.cairo(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: selectedDates.map((dateTimestamp) {
                                            DateTime date;
                                            if (dateTimestamp is Timestamp) {
                                              date = dateTimestamp.toDate();
                                            } else {
                                              return const SizedBox.shrink();
                                            }
                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: kPrimary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${date.year}/${date.month}/${date.day}',
                                                style: GoogleFonts.cairo(
                                                  fontSize: 12,
                                                  color: kPrimary,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'عدد الليالي: $totalDays',
                                            style: GoogleFonts.cairo(
                                              fontSize: 14,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          Text(
                                            'السعر: $totalPrice شيكل',
                                            style: GoogleFonts.cairo(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: kPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (checkInDate != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'تاريخ الوصول: ${_formatDate(checkInDate.toDate())}',
                                          style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                      if (checkOutDate != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'تاريخ المغادرة: ${_formatDate(checkOutDate.toDate())}',
                                          style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                      if (status != 'cancelled' && status != 'checked_out') ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            if (status == 'confirmed') ...[
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _checkIn(doc.id),
                                                  icon: const Icon(Icons.login, size: 18),
                                                  label: Text(
                                                    'تسجيل الوصول',
                                                    style: GoogleFonts.cairo(fontSize: 12),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.blue,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            if (status == 'checked_in') ...[
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _checkOut(doc.id),
                                                  icon: const Icon(Icons.logout, size: 18),
                                                  label: Text(
                                                    'تسجيل المغادرة',
                                                    style: GoogleFonts.cairo(fontSize: 12),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.orange,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () => _cancelBooking(
                                                  doc.id,
                                                  data['chaletId'] as String? ?? '',
                                                  selectedDates,
                                                ),
                                                icon: const Icon(Icons.cancel_outlined, size: 18),
                                                label: Text(
                                                  'إلغاء',
                                                  style: GoogleFonts.cairo(fontSize: 12),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                  side: const BorderSide(color: Colors.red),
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => _signOut(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'تسجيل الخروج',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(
      {
        required this.photoUrl,
        required this.initials
      });
  final String? photoUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (photoUrl ?? '').isNotEmpty;
    return Container(
      width: 118,
      height: 118,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [kPrimary, kAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(5),
      child: CircleAvatar(
        backgroundColor: Colors.white,
        child: hasPhoto
            ? ClipOval(
                child: Image.network(
                  photoUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
            : Text(
                initials,
                style: GoogleFonts.cairo(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
      ),
    );
  }
}
