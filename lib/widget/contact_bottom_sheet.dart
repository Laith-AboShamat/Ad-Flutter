import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactBottomSheet extends StatelessWidget {
  const ContactBottomSheet({
    super.key,
    required this.phone,
    required this.chaletName,
  });

  final String phone;
  final String chaletName;

  static const Color _pink = Color(0xFFFE2C55);
  static const Color _cyan = Color(0xFF25F4EE);

  String _normalizePhoneForWhatsApp(String raw) {
    final trimmed = raw.replaceAll(' ', '');
    if (trimmed.startsWith('970')) return trimmed;
    if (trimmed.startsWith('0')) return '970${trimmed.substring(1)}';
    return '970$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    final waPhone = _normalizePhoneForWhatsApp(phone);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 14),
            ShaderMask(
              shaderCallback: (r) =>
                  const LinearGradient(colors: [_pink, _cyan]).createShader(r),
              child: Text(
                chaletName.isEmpty
                    ? 'التواصل مع المعلن'
                    : 'التواصل مع $chaletName',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              phone,
              style: GoogleFonts.cairo(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            _ContactTile(
              text: 'تواصل عبر واتساب  $phone',
              leading: const Icon(
                FontAwesomeIcons.whatsapp,
                color: Color(0xFF25D366),
                size: 24,
              ),
              onTap: () async {
                final uri = Uri.parse('https://wa.me/$waPhone');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 10),
            _ContactTile(
              text: 'اتصال مباشر  $phone',
              leading: const Icon(
                Icons.phone_in_talk_rounded,
                color: Colors.white,
                size: 22,
              ),
              onTap: () async {
                final uri = Uri.parse('tel:$phone');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            const SizedBox(height: 12),
            Text(
              'لن نشارك رقمك مع المعلن.',
              style: GoogleFonts.cairo(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.text,
    required this.leading,
    required this.onTap,
  });

  final String text;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 15),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFE2C55), Color(0xFF25F4EE)],
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
