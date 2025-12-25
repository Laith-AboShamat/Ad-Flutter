import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widget/whatsapp_support_button.dart';
import 'package:myadds/features/owner_expenses/expense_model.dart';

/// شاشة مصاريف الشاليه (للمالك): إضافة/عرض/حذف المصاريف حسب الشهر.
class OwnerExpensesScreen extends StatefulWidget {
  const OwnerExpensesScreen({super.key});

  @override
  State<OwnerExpensesScreen> createState() => _OwnerExpensesScreenState();
}

class _OwnerExpensesScreenState extends State<OwnerExpensesScreen> {
  static const Color _pink = Color(0xFFFE2C55);

  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  DateTime _monthStart(DateTime m) => DateTime(m.year, m.month, 1);
  DateTime _monthEndExclusive(DateTime m) => DateTime(m.year, m.month + 1, 1);

  String _monthLabel(DateTime m) {
    final mm = m.month.toString().padLeft(2, '0');
    return '${m.year}-$mm';
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(DateTime.now().year - 5, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      helpText: 'اختر الشهر',
    );
    if (picked == null) return;
    setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _expensesStream(String ownerId) {
    // Query by ownerId only to avoid composite indexes.
    return FirebaseFirestore.instance
        .collection('chalet_expenses')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots();
  }

  Future<void> _openAddDialog(String ownerId) async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime date = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إضافة مصروف', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'العنوان (مثال: كهرباء)',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'المبلغ (شيكل)',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'ملاحظة (اختياري)',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(DateTime.now().year - 5, 1, 1),
                        lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                      );
                      if (picked == null) return;
                      setModal(() => date = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'تاريخ المصروف: ${date.year}/${date.month}/${date.day}',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        final amount = num.tryParse(amountCtrl.text.trim());
                        final note = noteCtrl.text.trim();

                        if (title.isEmpty || amount == null || amount <= 0) {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('أدخل عنوان ومبلغ صحيح', style: GoogleFonts.cairo())),
                          );
                          return;
                        }

                        try {
                          await FirebaseFirestore.instance.collection('chalet_expenses').add({
                            'ownerId': ownerId,
                            'title': title,
                            'amount': amount,
                            'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
                            if (note.isNotEmpty) 'note': note,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          Navigator.pop(ctx);
                        } catch (e) {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ في إضافة المصروف: $e', style: GoogleFonts.cairo())),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteExpense(String id) async {
    await FirebaseFirestore.instance.collection('chalet_expenses').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: Text('مصاريف الشاليه', style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
          body: Center(child: Text('يجب تسجيل الدخول أولاً', style: GoogleFonts.cairo())),
        ),
      );
    }

    final start = _monthStart(_selectedMonth);
    final end = _monthEndExclusive(_selectedMonth);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: Text('مصاريف الشاليه', style: GoogleFonts.cairo(color: Colors.black87, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: 'اختيار شهر',
              onPressed: _pickMonth,
              icon: const Icon(Icons.calendar_month_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _pink,
          foregroundColor: Colors.white,
          onPressed: () => _openAddDialog(user.uid),
          icon: const Icon(Icons.add),
          label: Text('إضافة', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _expensesStream(user.uid),
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
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Text(
                        'تعذر تحميل المصاريف. تأكد من صلاحيات Firestore.',
                        style: GoogleFonts.cairo(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const WhatsAppSupportButton(
                      message: 'مرحبا، عندي مشكلة في شاشة مصاريف الشاليه.',
                    ),
                  ],
                ),
              );
            }

            final List<ChaletExpense> all = (snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .map((d) => ChaletExpense.fromDoc(d))
                .toList();

            final List<ChaletExpense> items = <ChaletExpense>[];
            for (final exp in all) {
              final expDate = exp.date;
              if (!expDate.isBefore(start) && expDate.isBefore(end)) {
                items.add(exp);
              }
            }

            items.sort((a, b) => b.date.compareTo(a.date));

            final total = items.fold<num>(0, (sum, exp) => sum + exp.amount);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.red.withOpacity(0.12),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Colors.redAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('شهر', style: GoogleFonts.cairo(color: Colors.black54, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(_monthLabel(_selectedMonth), style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('إجمالي المصاريف', style: GoogleFonts.cairo(color: Colors.black54, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('${total.toStringAsFixed(0)} شيكل', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Text('لا يوجد مصاريف لهذا الشهر', style: GoogleFonts.cairo(color: Colors.black54)),
                  )
                else
                  ...items.map(
                    (exp) {
                      final expNote = exp.note;
                      final expDate = exp.date;
                      return Dismissible(
                        key: ValueKey(exp.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 16),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('حذف المصروف؟', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                                  content: Text('هل أنت متأكد؟', style: GoogleFonts.cairo()),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                      child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) => _deleteExpense(exp.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.payments_rounded, color: Colors.redAccent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(exp.title, style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${expDate.year}/${expDate.month}/${expDate.day}${(expNote?.isNotEmpty ?? false) ? ' • $expNote' : ''}',
                                      style: GoogleFonts.cairo(color: Colors.black54, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${exp.amount.toStringAsFixed(0)}',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                              const SizedBox(width: 6),
                              Text('₪', style: GoogleFonts.cairo(color: Colors.black54)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }
}
