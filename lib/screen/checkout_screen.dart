import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widget/notification_helper.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color _pink = Color(0xFFFE2C55);
  String? _chaletId;
  Map<String, dynamic>? _chaletData;
  List<DateTime>? _selectedDates;
  int _totalDays = 0;
  int _totalPrice = 0;
  bool _processing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _chaletId = args['chaletId'] as String?;
      _chaletData = args['chaletData'] as Map<String, dynamic>?;
      _selectedDates = args['selectedDates'] as List<DateTime>?;
      _totalDays = args['totalDays'] as int? ?? 0;
      final price = _chaletData?['price'] ?? 0;
      final fullPrice = _totalDays * (price is int ? price : int.tryParse('$price') ?? 0);
      // Calculate 10% deposit
      _totalPrice = (fullPrice * 0.1).round();
    }
  }

  Future<void> _processPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      NotificationHelper.showWarning(context, 'يجب تسجيل الدخول أولاً');
      Navigator.pop(context);
      return;
    }

    if (_chaletId == null || _selectedDates == null || _selectedDates!.isEmpty) {
      return;
    }

    setState(() => _processing = true);

    try {
      // Check if user already has a confirmed booking
      final existingBookings = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'confirmed')
          .get();

      if (existingBookings.docs.isNotEmpty) {
        if (!mounted) return;
        setState(() => _processing = false);
        NotificationHelper.showWarning(
          context,
          'لديك حجز مؤكد بالفعل. لا يمكنك حجز شاليه آخر حتى يتم إلغاء الحجز الحالي',
        );
        return;
      }

      // Simulate payment processing (virtual payment)
      await Future.delayed(const Duration(seconds: 2));

      // Update availability in Firestore
      final chaletRef = FirebaseFirestore.instance.collection('chalets').doc(_chaletId);

      // Get current availability
      final doc = await chaletRef.get();
      final data = doc.data() ?? {};
      final availability = Map<String, dynamic>.from(data['availability'] ?? {});

      // Mark selected dates as booked
      for (final date in _selectedDates!) {
        final monthKey =
            "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}";
        final dateKey =
            "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

        if (!availability.containsKey(monthKey)) {
          availability[monthKey] = <String, dynamic>{};
        }

        final monthData = Map<String, dynamic>.from(availability[monthKey] as Map? ?? {});
        monthData[dateKey] = true; // true means booked
        availability[monthKey] = monthData;
      }

      // Get ownerId from chalet document
      final ownerId = data['ownerId'] as String? ?? '';

      // Save booking record
      await FirebaseFirestore.instance.collection('bookings').add({
        'chaletId': _chaletId,
        'ownerId': ownerId,
        'userId': user.uid,
        'chaletName': _chaletData?['name'] ?? '',
        'selectedDates': _selectedDates!.map((d) => Timestamp.fromDate(d)).toList(),
        'totalDays': _totalDays,
        'totalPrice': _totalPrice,
        'status': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update chalet availability
      await chaletRef.update({
        'availability': availability,
        'updatedAvailabilityAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Show success message
      NotificationHelper.showSuccess(context, 'تم الحجز بنجاح! ✅');

      // Navigate back to home
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      
      // More detailed error message
      String errorMessage = 'حدث خطأ أثناء المعالجة';
      if (e.toString().contains('PERMISSION_DENIED')) {
        errorMessage = 'خطأ في الصلاحيات: يرجى التأكد من نشر قواعد Firestore في Firebase Console';
      } else {
        errorMessage = 'حدث خطأ: $e';
      }
      
      NotificationHelper.showError(context, errorMessage);
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chaletName = _chaletData?['name'] as String? ?? 'شاليه';
    final location = _chaletData?['location'] as String? ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'الدفع',
            style: GoogleFonts.cairo(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chalet Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملخص الحجز',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.home, color: _pink, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            chaletName,
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: _pink, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              location,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Booking Details
              Text(
                'تفاصيل الحجز',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (_selectedDates != null)
                      ..._selectedDates!.map((date) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${date.year}/${date.month}/${date.day}',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _pink.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'محجوز',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: _pink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'عدد الليالي',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          '$_totalDays ليلة',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'السعر لكل ليلة',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          '${_chaletData?['price'] ?? 0} شيكل',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'السعر الكامل',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          () {
                            final price = _chaletData?['price'] ?? 0;
                            final priceValue = price is int ? price : (int.tryParse('$price') ?? 0);
                            return '${_totalDays * priceValue} شيكل';
                          }(),
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الدفعة المقدمة (10%)',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '$_totalPrice شيكل',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المبلغ المطلوب',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$_totalPrice شيكل',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _pink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payment Method (Virtual)
              Text(
                'طريقة الدفع',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: _pink, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payment, color: _pink, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'دفع افتراضي',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'سيتم تأكيد الحجز فوراً',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle, color: _pink),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: ElevatedButton(
              onPressed: _processing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: _processing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'تأكيد الدفع والحجز',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

