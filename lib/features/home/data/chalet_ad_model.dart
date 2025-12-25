import 'package:cloud_firestore/cloud_firestore.dart';

class ChaletAd {
  final String id;
  final String ownerId;
  final String description;
  final int price;
  final String chaletName;
  final String chaletAddress;
  final String phone;
  final DateTime? updatedAvailabilityAt;
  final String videoFileName;
  final String videoStatus; // pending / approved / denied
  final int likes;
  final int commentsCount;

  ChaletAd({
    required this.id,
    required this.ownerId,
    required this.description,
    required this.price,
    required this.chaletName,
    required this.chaletAddress,
    required this.phone,
    required this.updatedAvailabilityAt,
    required this.videoFileName,
    required this.videoStatus,
    required this.likes,
    required this.commentsCount,
  });

  factory ChaletAd.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final ts = data['updatedAvailabilityAt'];

    return ChaletAd(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      description: data['description'] as String? ?? '',
      chaletName: data['name'] as String? ?? '',
      chaletAddress: data['location'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      price: (data['price'] ?? 0) is int
          ? data['price'] as int
          : int.tryParse('${data['price']}') ?? 0,
      updatedAvailabilityAt: ts is Timestamp ? ts.toDate() : null,
      videoFileName: data['videoFileName'] as String? ??
          '',
      videoStatus: data['videoStatus'] as String? ?? 'pending',
      likes: (data['likes'] ?? 0) as int,
      commentsCount: (data['commentsCount'] ?? 0) as int,
    );
  }
}
