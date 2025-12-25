import 'package:cloud_firestore/cloud_firestore.dart';

class ChaletExpense {
  ChaletExpense({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.amount,
    required DateTime date,
    this.note,
    this.createdAt,
  }) : _date = date;

  final String id;
  final String ownerId;
  final String title;
  final num amount;
  final DateTime _date;
  final String? note;
  final DateTime? createdAt;

  /// Non-null expense date (normalized to day).
  DateTime get date => DateTime(_date.year, _date.month, _date.day);

  static ChaletExpense fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final rawAmount = data['amount'];
    final num amount = rawAmount is num ? rawAmount : num.tryParse('${data['amount']}') ?? 0;

    final rawDate = data['date'];
    DateTime date = DateTime.now();
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is DateTime) {
      date = rawDate;
    }

    DateTime? createdAt;
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) createdAt = rawCreatedAt.toDate();

    return ChaletExpense(
      id: doc.id,
      ownerId: (data['ownerId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      amount: amount,
      date: date,
      note: data['note'] as String?,
      createdAt: createdAt,
    );
  }
}
