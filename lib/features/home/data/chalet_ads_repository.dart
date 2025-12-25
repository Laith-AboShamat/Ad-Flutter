import 'package:cloud_firestore/cloud_firestore.dart';

import 'chalet_ad_model.dart';

class ChaletAdsRepository {
  ChaletAdsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference get _chaletsCol =>
      _firestore.collection('chalets'); // your collection

  // 🔹 Home feed
  Stream<List<ChaletAd>> watchAds() {
    return _chaletsCol
        .orderBy('updatedAvailabilityAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(ChaletAd.fromDoc)
            // show only chalets that have a video AND that video is approved
            .where(
              (ad) =>
                  ad.videoFileName.isNotEmpty &&
                  (ad.videoStatus.isEmpty || ad.videoStatus == 'approved'),
            )
            .toList());
  }

  // 🔹 Likes
  Future<void> likeOnce(String adId) {
    return _chaletsCol.doc(adId).update({'likes': FieldValue.increment(1)});
  }

  Future<void> toggleLike(String adId, bool isLikedNow) {
    final delta = isLikedNow ? 1 : -1;
    return _chaletsCol.doc(adId).update({'likes': FieldValue.increment(delta)});
  }

  Stream<QuerySnapshot> watchComments(String adId) {
    return _chaletsCol
        .doc(adId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> addComment({
    required String adId,
    required String text,
    required String userName,
  }) async {
    final docRef = _chaletsCol.doc(adId);

    await docRef.collection('comments').add({
      'text': text,
      'userName': userName,
      'likes': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await docRef.update({
      'commentsCount': FieldValue.increment(1),
    });
  }
}
