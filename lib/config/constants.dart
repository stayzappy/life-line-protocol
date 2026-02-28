import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get reownProjectId => dotenv.get('REOWN_PROJECT_ID');
  
  static String get s3Endpoint => dotenv.get('IDRIVE_ENDPOINT');
  static String get s3AccessKey => dotenv.get('IDRIVE_ACCESS_KEY');
  static String get s3SecretKey => dotenv.get('IDRIVE_SECRET_KEY');
  static String get s3Bucket => dotenv.get('IDRIVE_BUCKET');
  
  static String get emailServiceId => dotenv.get('EMAILJS_SERVICE_ID');
  static String get emailTemplateId => dotenv.get('EMAILJS_TEMPLATE_ID');
  static String get emailPublicKey => dotenv.get('EMAILJS_PUBLIC_KEY');

  static String get appSecret {
    String key = dotenv.get('APP_SECRET');
    return key.padRight(32, '*').substring(0, 32);
  }
}