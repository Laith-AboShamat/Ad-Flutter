import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../screen/business_management_screen.dart';
import '../../widget/whatsapp_support_button.dart';
import '../owner_expenses/expenses_screen.dart';

class OwnerReportsScreen extends StatefulWidget {
  const OwnerReportsScreen({super.key});
  @override
  State<OwnerReportsScreen> createState() => _OwnerReportsScreenState();
}

class _OwnerReportsScreenState extends State<OwnerReportsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  Future<void> _pickMonth() async {
    // Using a date picker is a quick, dependency-free way to pick a month.
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(DateTime.now().year - 5, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      helpText: 'اختر الشهر',
    );

    if (picked == null) return;

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: Text(
            'تقارير الشاليه',
            style: GoogleFonts.cairo(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'العودة لإدارة الشاليه',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const BusinessManagementScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.home_work_outlined),
            ),
            IconButton(
              tooltip: 'اختيار شهر',
              onPressed: _pickMonth,
              icon: const Icon(Icons.calendar_month_rounded),
            ),
          ],
        ),
        body: user == null
            ? Center(child: Text('يجب تسجيل الدخول أولاً', style: GoogleFonts.cairo()))
            : _ReportsBody(ownerId: user.uid, month: _selectedMonth),
      ),
    );
  }
}

class _ReportsBody extends StatelessWidget {
  const _ReportsBody({super.key, required this.ownerId, required this.month});

  final String ownerId;
  final DateTime month;

  static const Color _pink = Color(0xFFFE2C55);
  static const Color _cyan = Color(0xFF25F4EE);

  DateTime _monthStart(DateTime m) => DateTime(m.year, m.month, 1);
  DateTime _monthEndExclusive(DateTime m) => DateTime(m.year, m.month + 1, 1);

  String _monthLabel(DateTime m) {
    final mm = m.month.toString().padLeft(2, '0');
    return '${m.year}-$mm';
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? 0;
  }

  int _nightsFromSelectedDates(List<dynamic> selected) {
    return selected.whereType<Timestamp>().length;
  }

  DateTime? _firstDateFromSelected(List<dynamic> selected) {
    final dates = <DateTime>[];
    for (final x in selected) {
      if (x is Timestamp) dates.add(x.toDate());
    }
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }

  DateTime? _lastDateFromSelected(List<dynamic> selected) {
    final dates = <DateTime>[];
    for (final x in selected) {
      if (x is Timestamp) dates.add(x.toDate());
    }
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.last;
  }

  bool _selectedDatesOverlapMonth(List<dynamic> selected, DateTime start, DateTime endExclusive) {
    for (final x in selected) {
      if (x is! Timestamp) continue;
      final d = x.toDate();
      if (!d.isBefore(start) && d.isBefore(endExclusive)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final start = _monthStart(month);
    final end = _monthEndExclusive(month);

    // Query by ownerId only to avoid composite indexes, then filter by month in-app.
    final bookingsStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots();

    final expensesStream = FirebaseFirestore.instance
        .collection('chalet_expenses')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: bookingsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'تعذر تحميل التقارير. تأكد من صلاحيات Firestore.',
                    style: GoogleFonts.cairo(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                const WhatsAppSupportButton(
                  message: 'مرحبا، عندي مشكلة في تقارير الشاليه داخل التطبيق.',
                ),
              ],
            ),
          );
        }

        final docs = (snap.data?.docs ?? []).toList();

        // Filter by month: include any booking that has at least one selected date inside the month.
        // This fixes cases where a booking starts in a different month but overlaps this month.
        final monthDocs = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final selected = (data['selectedDates'] as List?)?.toList() ?? const [];
          return _selectedDatesOverlapMonth(selected, start, end);
        }).toList();

        // Sort by createdAt desc
        monthDocs.sort((a, b) {
          final ad = a.data() as Map<String, dynamic>;
          final bd = b.data() as Map<String, dynamic>;
          final at = ad['createdAt'];
          final bt = bd['createdAt'];
          if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
          return 0;
        });

        int confirmedCount = 0;
        int cancelledCount = 0;
        int checkedInCount = 0;
        int checkedOutCount = 0;
        int pendingArrivalCount = 0;

        int revenueDeposit = 0;
        int revenueTotal = 0;
        int nights = 0;

        for (final doc in monthDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'confirmed').toString();

          final totalDays = _asInt(data['totalDays']);
          final selected = (data['selectedDates'] as List?)?.toList() ?? const [];

          // Nights calculation: if totalDays is missing/0, fallback to selectedDates count.
          final nightsForThis = totalDays > 0 ? totalDays : _nightsFromSelectedDates(selected);

          // totalPrice is currently the 10% deposit (from CheckoutScreen).
          final deposit = _asInt(data['totalPrice']);
          // Use stored fullPrice if available, else estimate: deposit * 10.
          final fullPrice = data.containsKey('fullPrice') ? _asInt(data['fullPrice']) : (deposit * 10);

          if (status == 'cancelled') {
            cancelledCount++;
            continue;
          }

          if (status == 'checked_in') {
            checkedInCount++;
          } else if (status == 'checked_out') {
            checkedOutCount++;
          } else {
            pendingArrivalCount++;
          }

          confirmedCount++;
          nights += nightsForThis;
          revenueDeposit += deposit;
          revenueTotal += fullPrice;
        }

        final avgNights = confirmedCount == 0 ? 0.0 : (nights / confirmedCount);
        final totalAll = confirmedCount + cancelledCount;
        final cancelRate = totalAll == 0 ? 0.0 : (cancelledCount / totalAll);

        return StreamBuilder<QuerySnapshot>(
            stream: expensesStream,
            builder: (context, exSnap) {
              if (exSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final monthExpenses = (exSnap.data?.docs ?? []).where((d) {
                final data = d.data() as Map<String, dynamic>;
                final date = (data['date'] as Timestamp).toDate();
                return !date.isBefore(start) && date.isBefore(end);
              }).toList();

              monthExpenses.sort((a, b) {
                final ad = a.data() as Map<String, dynamic>;
                final bd = b.data() as Map<String, dynamic>;
                final at = ad['date'] as Timestamp;
                final bt = bd['date'] as Timestamp;
                return bt.compareTo(at);
              });
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeaderCard(monthLabel: _monthLabel(month)),
                  const SizedBox(height: 12),
                  _KpiGrid(
                    items: [
                      _Kpi('الحجوزات', confirmedCount.toString(), Icons.event_available_rounded, _pink),
                      _Kpi('ملغي', cancelledCount.toString(), Icons.event_busy_rounded, Colors.red),
                      _Kpi('ليالي محجوزة', nights.toString(), Icons.nightlight_round, Colors.indigo),
                      _Kpi('متوسط الليالي', avgNights.toStringAsFixed(1), Icons.bar_chart_rounded, Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _KpiGrid(
                    items: [
                      _Kpi('عربون (شيكل)', revenueDeposit.toString(), Icons.payments_rounded, _cyan),
                      _Kpi('إيراد تقديري', revenueTotal.toString(), Icons.account_balance_wallet_rounded, _pink),
                      _Kpi('لم يتم الوصول', pendingArrivalCount.toString(), Icons.nights_stay_rounded, const Color(0xFF6B7280)),
                      _Kpi('تم الوصول', checkedInCount.toString(), Icons.login_rounded, Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _KpiGrid(
                    items: [
                      _Kpi('تم المغادرة', checkedOutCount.toString(), Icons.logout_rounded, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InsightCard(
                    title: 'ملاحظات سريعة',
                    lines: [
                      'نسبة الإلغاء: ${(cancelRate * 100).toStringAsFixed(0)}%',
                      'العربون هو المبلغ المسجل في الحجوزات (10%).',
                      'الإيراد التقديري = العربون × 10 (إن لم يتم تخزين fullPrice في الحجز).',
                      'صافي الربح = الإيراد التقديري - المصاريف.',
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFE2C55),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OwnerExpensesScreen()),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded, size: 20),
                      label: Text('عرض المصاريف', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ExpensesMiniList(expenses: monthExpenses),
                  const SizedBox(height: 24),
                  _BookingsList(docs: monthDocs),
                ],
              );
            });
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({super.key, required this.monthLabel});

  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFFFE2C55), Color(0xFF25F4EE)],
              ),
            ),
            child: const Icon(Icons.insights_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تقرير شهر',
                  style: GoogleFonts.cairo(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  monthLabel,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({super.key, required this.items});

  final List<_Kpi> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.9,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.value,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({super.key, required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.check_circle, size: 16, color: Color(0xFF25D366)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l,
                      style: GoogleFonts.cairo(color: Colors.black87, height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsList extends StatelessWidget {
  const _BookingsList({super.key, required this.docs});

  final List<QueryDocumentSnapshot> docs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حجوزات هذا الشهر', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            Text('لا يوجد حجوزات بهذا الشهر', style: GoogleFonts.cairo(color: Colors.black54))
          else
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final chaletName = (data['chaletName'] ?? 'شاليه').toString();
              final status = (data['status'] ?? 'confirmed').toString();
              final totalDays = (data['totalDays'] ?? 0).toString();
              final totalPrice = (data['totalPrice'] ?? 0).toString();
              final createdAt = data['createdAt'] as Timestamp?;

              Color color = Colors.green;
              String statusText = 'مؤكد';
              if (status == 'cancelled') {
                color = Colors.red;
                statusText = 'ملغي';
              } else if (status == 'checked_in') {
                color = Colors.blue;
                statusText = 'تم الوصول';
              } else if (status == 'checked_out') {
                color = Colors.grey;
                statusText = 'تم المغادرة';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(chaletName, style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            '$statusText • $totalDays ليلة • $totalPrice شيكل (عربون)',
                            style: GoogleFonts.cairo(color: Colors.black54, fontSize: 12.5),
                          ),
                          if (createdAt != null)
                            Text(
                              'تاريخ الحجز: ${createdAt.toDate().year}/${createdAt.toDate().month}/${createdAt.toDate().day}',
                              style: GoogleFonts.cairo(color: Colors.black45, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ExpensesMiniList extends StatelessWidget {
  const _ExpensesMiniList({super.key, required this.expenses});

  final List<QueryDocumentSnapshot> expenses;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) return const SizedBox();

    // Take at most 3 latest expenses for the mini-list.
    final limitedExpenses = expenses.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المصاريف الأخيرة', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...limitedExpenses.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] ?? 0).toString();
            final description = (data['description'] ?? '').toString();
            final createdAt = data['createdAt'] as Timestamp?;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$amount شيكل',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: GoogleFonts.cairo(color: Colors.black54, fontSize: 12.5),
                        ),
                        if (createdAt != null)
                          Text(
                            'تاريخ المصروف: ${createdAt.toDate().year}/${createdAt.toDate().month}/${createdAt.toDate().day}',
                            style: GoogleFonts.cairo(color: Colors.black45, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (expenses.length > 3)
            TextButton(
              onPressed: () {
                // TODO: Navigate to full expenses list screen.
              },
              child: Text(
                'عرض كل المصاريف',
                style: GoogleFonts.cairo(color: const Color(0xFFFE2C55)),
              ),
            ),
        ],
      ),
    );
  }
}
