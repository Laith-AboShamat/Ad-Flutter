import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppSupportButton extends StatelessWidget {
  const WhatsAppSupportButton({
    super.key,
    this.phone = '+970 592 835 008',
    this.message,
    this.fullWidth = true,
  });
//ssss
  final String phone;
  final String? message;
  final bool fullWidth;

  String _normalizePhoneForWhatsApp(String raw) {
    final trimmed = raw.replaceAll(' ', '').replaceAll('+', '');
    if (trimmed.startsWith('970')) return trimmed;
    if (trimmed.startsWith('0')) return '970${trimmed.substring(1)}';
    return '970$trimmed';
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final waPhone = _normalizePhoneForWhatsApp(phone);
    final text = (message ?? '').trim();
    final uri = text.isEmpty
        ? Uri.parse('https://wa.me/$waPhone')
        : Uri.parse('https://wa.me/$waPhone?text=${Uri.encodeComponent(text)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح واتساب', style: GoogleFonts.cairo())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ElevatedButton.icon(
      onPressed: () => _openWhatsApp(context),
      icon: const Icon(FontAwesomeIcons.whatsapp, size: 18),
      label: Text(
        'تواصل مع الفريق عبر واتساب',
        style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    if (!fullWidth) return child;
    return SizedBox(width: double.infinity, height: 48, child: child);
  }
}
