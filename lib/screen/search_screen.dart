import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


const Color kPrimary = Color(0xFFFE2C55);
const Color kAccent = Color(0xFF25F4EE);
const Color kBg = Color(0xFFF9FBFC);
const Color kFieldBorder = Color(0xFFE7EDF1);

class SearchScreen extends StatefulWidget {
  final VoidCallback?
  onBackToHome;
  const SearchScreen({super.key, this.onBackToHome});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _q = TextEditingController();
  String _query = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  Future<void> _runSearch() async {
    final q = _q.text.trim();
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _query = q;
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      // Search in Firestore - get all chalets and filter by name
      final snap = await FirebaseFirestore.instance
          .collection('chalets')
          .get();

      // Filter results by name (case-insensitive, partial match)
      final queryLower = q.toLowerCase();
      final filtered = snap.docs.where((doc) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().toLowerCase();
        final location = (data['location'] ?? '').toString().toLowerCase();
        final description = (data['description'] ?? '').toString().toLowerCase();
        
        // Search in name, location, or description
        return name.contains(queryLower) || 
               location.contains(queryLower) || 
               description.contains(queryLower);
      }).toList();

      if (!mounted) return;

      setState(() {
        _results = filtered;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
      debugPrint('Error searching: $e');
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            'بحث',
            style: GoogleFonts.cairo(
              color: Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        body: Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 180,
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
                    topLeft: Radius.circular(120),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kFieldBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            color: kPrimary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _q,
                            autofocus: true,
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            cursorColor: kPrimary,
                            decoration: InputDecoration(
                              hintText: 'ابحث عن شاليه، موقع، وصف...',
                              hintStyle: GoogleFonts.cairo(
                                color: Colors.black38,
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                            onSubmitted: (_) => _runSearch(),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_q.text.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              _q.clear();
                              setState(() {
                                _query = '';
                                _results = [];
                                _hasSearched = false;
                                _isSearching = false;
                              });
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.black54,
                                size: 18,
                              ),
                            ),
                            tooltip: 'مسح',
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _q.text.trim().isEmpty ? null : _runSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 22,
                            color: _q.text.trim().isEmpty
                                ? Colors.grey[600]
                                : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'بحث',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  if (_hasSearched) ...[
                    if (_isSearching)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
                                strokeWidth: 3,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'جاري البحث...',
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: kPrimary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: kPrimary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'نتائج عن: "$_query" (${_results.length})',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _results.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.search_off_rounded,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'لا توجد نتائج',
                                      style: GoogleFonts.cairo(
                                        fontSize: 18,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'جرب البحث بكلمات مختلفة',
                                      style: GoogleFonts.cairo(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: _results.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final doc = _results[i];
                                  final data = doc.data();
                                  return _ResultCard(
                                    chaletId: doc.id,
                                    chaletData: data,
                                    name: data['name'] as String? ?? 'شاليه',
                                    location: data['location'] as String? ?? '',
                                  );
                                },
                              ),
                      ),
                    ],
                  ] else ...[
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    kPrimary.withOpacity(0.1),
                                    kAccent.withOpacity(0.1),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.search_rounded,
                                size: 64,
                                color: kPrimary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'ابحث عن الشاليهات',
                              style: GoogleFonts.cairo(
                                fontSize: 20,
                                color: Colors.black87,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ابحث بالاسم، الموقع، أو الوصف',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String chaletId;
  final Map<String, dynamic> chaletData;
  final String name;
  final String location;

  const _ResultCard({
    required this.chaletId,
    required this.chaletData,
    required this.name,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/chalet-details',
          arguments: {
            'chaletId': chaletId,
            'chaletData': chaletData,
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kFieldBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kPrimary.withOpacity(0.15),
                    kAccent.withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.home_rounded,
                color: kPrimary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.black54,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
