import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  NavigationService._();

  /// Clean non-digits from phone number.
  static String sanitizePhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// Launch system phone dialer.
  static Future<bool> callCustomer(String rawPhone) async {
    final phone = sanitizePhone(rawPhone);
    if (phone.isEmpty) return false;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  /// Launch Google Maps navigation for customer.
  /// Prioritizes direct `googleMapLink` if available, otherwise queries by address.
  static Future<bool> openGoogleMaps({
    String? googleMapLink,
    required String address,
  }) async {
    if (googleMapLink != null && googleMapLink.trim().isNotEmpty) {
      final trimmed = googleMapLink.trim();
      final directUri = Uri.tryParse(trimmed);
      if (directUri != null && (directUri.isScheme('http') || directUri.isScheme('https'))) {
        if (await canLaunchUrl(directUri)) {
          return await launchUrl(directUri, mode: LaunchMode.externalApplication);
        }
      }
    }

    if (address.trim().isEmpty) return false;

    // Google Maps universal search URL (launches native Google Maps app on Android/iOS)
    final searchUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address.trim())}',
    );

    if (await canLaunchUrl(searchUri)) {
      return await launchUrl(searchUri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Launch WhatsApp chat with customer.
  static Future<bool> openWhatsApp(String rawPhone, {String? defaultMessage}) async {
    final phone = sanitizePhone(rawPhone);
    if (phone.isEmpty) return false;

    final fullNumber = phone.length == 10 ? '91$phone' : phone;
    final message = defaultMessage != null
        ? '?text=${Uri.encodeComponent(defaultMessage)}'
        : '';
    final waUri = Uri.parse('https://wa.me/$fullNumber$message');

    if (await canLaunchUrl(waUri)) {
      return await launchUrl(waUri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}

