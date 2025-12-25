import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class ChaletDetailsBookingScreen extends StatefulWidget {
  const ChaletDetailsBookingScreen({super.key});

  @override
  State<ChaletDetailsBookingScreen> createState() =>
      _ChaletDetailsBookingScreenState();
}

class _ChaletDetailsBookingScreenState
    extends State<ChaletDetailsBookingScreen> {
  static const Color _pink = Color(0xFFFE2C55);

  String? _chaletId;
  Map<String, dynamic>? _chaletData;
  Map<String, Map<String, bool>>? _availability;
  DateTime _visibleMonth = DateTime.now();
  final Set<String> _selectedDates = {};
  bool _loading = true;

  // Check if user is authenticated (not a guest)
  bool get _isAuthenticated => FirebaseAuth.instance.currentUser != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _chaletId = args['chaletId'] as String?;
      _chaletData = args['chaletData'] as Map<String, dynamic>?;
      _loadAvailability();
    }
  }

  Future<void> _loadAvailability() async {
    if (_chaletId == null) return;

    setState(() => _loading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('chalets')
          .doc(_chaletId)
          .get();

      final data = doc.data();
      if (data != null && data['availability'] != null) {
        final avail = data['availability'] as Map<String, dynamic>?;
        _availability = {};
        avail?.forEach((monthKey, monthData) {
          if (monthData is Map<String, dynamic>) {
            _availability![monthKey] = {};
            monthData.forEach((dateKey, value) {
              _availability![monthKey]![dateKey] = value == true || value == 'booked';
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading availability: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _keyOf(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  bool _isDateBooked(DateTime date) {
    final monthKey =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}";
    final dateKey = _keyOf(date);
    return _availability?[monthKey]?[dateKey] == true;
  }

  bool _isDateSelected(DateTime date) {
    return _selectedDates.contains(_keyOf(date));
  }

  bool _canSelectDate(DateTime date) {
    if (_isDateBooked(date)) return false;
    if (_selectedDates.isEmpty) return true;
    if (_selectedDates.length >= 3) return false;

    final selected = _selectedDates.map((k) {
      final parts = k.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }).toList()..sort();

    if (selected.isEmpty) return true;

    final first = selected.first;

    // Check if date is within 3 days range
    final daysDiff = date.difference(first).inDays;
    if (daysDiff < 0) {
      // Date is before first selected
      final newFirst = date;
      final newLast = selected.last;
      return newLast.difference(newFirst).inDays < 3;
    } else {
      // Date is after last selected
      final newFirst = selected.first;
      final newLast = date;
      return newLast.difference(newFirst).inDays < 3;
    }
  }

  void _toggleDate(DateTime date) {
    // Guests cannot select dates
    if (!_isAuthenticated) {
      _showGuestLoginPrompt();
      return;
    }

    if (!_canSelectDate(date) && !_isDateSelected(date)) return;

    final key = _keyOf(date);
    setState(() {
      if (_selectedDates.contains(key)) {
        _selectedDates.remove(key);
      } else {
        if (_selectedDates.length < 3) {
          _selectedDates.add(key);
        }
      }
    });
  }

  void _prevMonth() {
    // Guests can still navigate months to view, but cannot select
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    // Guests can still navigate months to view, but cannot select
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
  }

  void _showGuestLoginPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'تسجيل الدخول مطلوب',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          'يجب تسجيل الدخول لحجز الشاليه',
          style: GoogleFonts.cairo(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Save booking arguments to pass to login, then redirect back
              final bookingArgs = _selectedDates.isNotEmpty && _chaletId != null && _chaletData != null
                  ? {
                      'chaletId': _chaletId,
                      'chaletData': _chaletData,
                      'selectedDates': _selectedDates.map((k) {
                        final parts = k.split('-');
                        return DateTime(
                          int.parse(parts[0]),
                          int.parse(parts[1]),
                          int.parse(parts[2]),
                        );
                      }).toList()..sort(),
                      'totalDays': _selectedDates.length,
                    }
                  : null;
              
              Navigator.pushNamed(
                context,
                '/login',
                arguments: bookingArgs != null
                    ? {
                        'redirectTo': '/checkout',
                        'bookingArgs': bookingArgs,
                      }
                    : null,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'تسجيل الدخول',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCheckout() {
    if (_selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى اختيار تاريخ للحجز',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
      return;
    }

    if (_chaletId == null || _chaletData == null) return;

    final selectedDatesList = _selectedDates.map((k) {
      final parts = k.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }).toList()..sort();

    Navigator.pushNamed(
      context,
      '/checkout',
      arguments: {
        'chaletId': _chaletId,
        'chaletData': _chaletData,
        'selectedDates': selectedDatesList,
        'totalDays': _selectedDates.length,
      },
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final normalized = _normalizePhoneForWhatsApp(phone);
    final uri = Uri.parse('https://wa.me/$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _normalizePhoneForWhatsApp(String raw) {
    final trimmed = raw.replaceAll(' ', '');
    if (trimmed.startsWith('970')) return trimmed;
    if (trimmed.startsWith('0')) return '970${trimmed.substring(1)}';
    return '970$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    if (_chaletData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('تفاصيل الشاليه', style: GoogleFonts.cairo()),
        ),
        body: const Center(child: Text('لا توجد بيانات')),
      );
    }

    final chaletName = _chaletData!['name'] as String? ?? 'شاليه';
    final location = _chaletData!['location'] as String? ?? 'غير محدد';
    final phone = _chaletData!['phone'] as String? ?? '';
    final price = _chaletData!['price'] ?? 0;
    final description = _chaletData!['description'] as String? ?? '';

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
            'تفاصيل الشاليه',
            style: GoogleFonts.cairo(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chalet Info Section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chaletName,
                            style: GoogleFonts.cairo(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (description.isNotEmpty) ...[
                            Text(
                              description,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Icon(Icons.location_on, color: _pink, size: 20),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.phone, color: _pink, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (phone.isNotEmpty) ...[
                                IconButton(
                                  icon: const Icon(Icons.phone_in_talk, color: _pink),
                                  onPressed: () => _callPhone(phone),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat, color: Colors.green),
                                  onPressed: () => _openWhatsApp(phone),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _pink.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'السعر: $price شيكل / ليلة',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _pink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),

                    // Calendar Section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اختر تاريخ الحجز',
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _pink.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _pink, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: _pink, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'أن اقصى عدد الايام للحجز هو 3 أيام متتالية',
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: _pink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!_isAuthenticated) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'يجب تسجيل الدخول لحجز الشاليه',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            'يمكنك اختيار حتى 3 أيام متتالية',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildCalendar(),
                          const SizedBox(height: 16),
                          if (_selectedDates.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'التواريخ المختارة:',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ..._selectedDates.map((dateKey) {
                                    final parts = dateKey.split('-');
                                    final date = DateTime(
                                      int.parse(parts[0]),
                                      int.parse(parts[1]),
                                      int.parse(parts[2]),
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '${date.year}/${date.month}/${date.day}',
                                        style: GoogleFonts.cairo(),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 8),
                                  Text(
                                    'إجمالي: ${_selectedDates.length} ليلة × $price = ${_selectedDates.length * (price is int ? price : int.tryParse('$price') ?? 0)} شيكل',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w700,
                                      color: _pink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
              onPressed: _isAuthenticated ? _navigateToCheckout : _showGuestLoginPrompt,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAuthenticated ? _pink : Colors.grey[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                !_isAuthenticated
                    ? 'تسجيل الدخول للحجز'
                    : (_selectedDates.isEmpty
                        ? 'اختر تاريخ للحجز'
                        : 'احجز الآن (${_selectedDates.length} ليلة)'),
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

  Widget _buildCalendar() {
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysInMonth = lastDay.day;
    final startingWeekday = firstDay.weekday % 7; // 0 = Sunday, 6 = Saturday

    final weekDays = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Month Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _pink.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _prevMonth,
                ),
                Text(
                  '${_getMonthName(month)} $year',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          // Week Days Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: weekDays.map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Calendar Grid
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (int week = 0; week < 6; week++)
                  Row(
                    children: [
                      for (int day = 0; day < 7; day++)
                        Expanded(
                          child: _buildDayCell(week, day, startingWeekday, daysInMonth, year, month),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(int week, int day, int startingWeekday, int daysInMonth, int year, int month) {
    final dayNumber = week * 7 + day - startingWeekday + 1;

    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 40);
    }

    final date = DateTime(year, month, dayNumber);
    final isBooked = _isDateBooked(date);
    final isSelected = _isDateSelected(date);
    final canSelect = _canSelectDate(date);
    final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

    Color bgColor = Colors.white;
    Color textColor = Colors.black87;
    String label = '$dayNumber';

    if (isPast) {
      bgColor = Colors.grey[200]!;
      textColor = Colors.grey[400]!;
    } else if (isBooked) {
      bgColor = Colors.red[100]!;
      textColor = Colors.red[700]!;
      label = 'محجوز';
    } else if (isSelected) {
      bgColor = _pink;
      textColor = Colors.white;
    } else if (!canSelect && !isPast) {
      bgColor = Colors.orange[50]!;
      textColor = Colors.orange[700]!;
    }

    return GestureDetector(
      onTap: (isPast || isBooked || !_isAuthenticated) ? null : () => _toggleDate(date),
      child: Container(
        margin: const EdgeInsets.all(2),
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: _pink, width: 2)
              : Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: isBooked ? 10 : 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
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
    return months[month - 1];
  }
}

