import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

class EmailService {
  final String _url = 'https://api.emailjs.com/api/v1.0/email/send';

  Future<bool> sendInheritanceEmail({
    required String heirName,
    required String heirEmail,
    required String ownerName,
    required String message,
    required String decryptedPrivateKey,
    required String amount,
    required String tokenSymbol,
  }) async {
    try {
      print('DEBUG: Attempting to send EmailJS payload...');
      
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // CRITICAL FIX: Spoofing the origin prevents the EmailJS firewall 
          // from abruptly dropping the mobile connection.
          'origin': 'http://localhost', 
        },
        body: json.encode({
          'service_id': AppConstants.emailServiceId,
          'template_id': AppConstants.emailTemplateId,
          'user_id': AppConstants.emailPublicKey,
          // NOTE: If you checked "Require Private Key" in your EmailJS Security settings,
          // you MUST uncomment the line below and add your private key to your constants.
          // 'accessToken': AppConstants.emailPrivateKey, 
          'template_params': {
            'to_name': heirName,
            'to_email': heirEmail, 
            'from_name': ownerName,
            'message': message,
            'private_key': decryptedPrivateKey,
            'amount': amount,
            'token_symbol': tokenSymbol,
          }
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Email Sent Successfully');
        return true;
      } else {
        print('❌ Email Failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Email Error: $e');
      return false;
    }
  }
}