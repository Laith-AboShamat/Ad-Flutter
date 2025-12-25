import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/home/data/chalet_ad_model.dart';
import '../features/home/data/chalet_ads_repository.dart';
import 'comments_bottom_sheet.dart';
import 'contact_bottom_sheet.dart';
import 'reel_video_background.dart';

class HomeReel extends StatefulWidget {
  const HomeReel({
    super.key,
    required this.ad,
    required this.repository,
  });

  final ChaletAd ad;
  final ChaletAdsRepository repository;

  @override
  State<HomeReel> createState() => _HomeReelState();
}

class _HomeReelState extends State<HomeReel> {
  static const Color _pink = Color(0xFFFE2C55);

  static const String _defaultAvatarUrl =
      'assets/images/chalet.jpg';

  bool _isLiked = false;
  bool _heartVisible = false;

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadOwner() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.ad.ownerId)
        .get();
  }

  Future<void> _onDoubleTapLike() async {
    if (_heartVisible) return;
    setState(() {
      _heartVisible = true;
      _isLiked = true;
    });
    await widget.repository.likeOnce(widget.ad.id);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _heartVisible = false);
    });
  }

  Future<void> _toggleLike() async {
    final newValue = !_isLiked;
    setState(() => _isLiked = newValue);
    await widget.repository.toggleLike(widget.ad.id, newValue);
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => CommentsBottomSheet(
        adId: widget.ad.id,
        repository: widget.repository,
      ),
    );
  }

  void _openContact(String phone, String chaletName) {
    if (phone.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E0E),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => ContactBottomSheet(
        phone: phone,
        chaletName: chaletName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultChaletName =
        widget.ad.chaletName.isNotEmpty ? widget.ad.chaletName : 'شالية';
    final defaultPhone = widget.ad.phone;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _loadOwner(),
      builder: (context, snap) {
        String chaletName = defaultChaletName;
        String phone = defaultPhone;
        String avatarUrl = _defaultAvatarUrl;

        if (snap.hasData && snap.data!.data() != null) {
          final data = snap.data!.data()!;
          final ownerChaletName = (data['chaletName'] as String?) ?? '';
          final ownerPhone = (data['phone'] as String?) ?? '';
          if (chaletName.isEmpty && ownerChaletName.isNotEmpty) {
            chaletName = ownerChaletName;
          }
          if (phone.isEmpty && ownerPhone.isNotEmpty) {
            phone = ownerPhone;
          }
          // if later you store profile image:
          avatarUrl = (data['profileImage'] as String?) ?? _defaultAvatarUrl;
        }

        return GestureDetector(
          onDoubleTap: _onDoubleTapLike,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ReelVideoBackground(videoFileName: widget.ad.videoFileName),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.black.withOpacity(0.72),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // chalet name + description / price
              Positioned(
                left: 16,
                bottom: 88,
                right: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chaletName,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.ad.description.isEmpty
                          ? 'السعر: ${widget.ad.price} شيكل'
                          : widget.ad.description,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // actions column
              Positioned(
                right: 10,
                bottom: 88,
                child: Column(
                  children: [
                    _iconButton(
                      Icons.favorite,
                      count: '${widget.ad.likes}',
                      color: _isLiked ? _pink : Colors.white,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(height: 18),
                    _iconButton(
                      Icons.comment_outlined,
                      count: '${widget.ad.commentsCount}',
                      onTap: _openComments,
                    ),
                    const SizedBox(height: 18),
                    _iconButton(
                      Icons.chat_bubble_outline,
                      count: 'تواصل',
                      onTap: () => _openContact(phone, chaletName),
                    ),
                    const SizedBox(height: 18),
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: NetworkImage(avatarUrl),
                    ),
                  ],
                ),
              ),
              // big heart animation
              IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _heartVisible ? 1 : 0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 350),
                      scale: _heartVisible ? 1.0 : 0.4,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.redAccent,
                        size: 110,
                      ),
                    ),
                  ),
                ),
              ),
              // top title
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'اعلاناتي',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconButton(
      IconData icon, {
        String count = '',
        Color color = Colors.white,
        VoidCallback? onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            count,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
