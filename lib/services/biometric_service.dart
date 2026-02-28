import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> authenticate({required String reason}) async {
    final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

    if (!canAuthenticate) {
      // Fallback if the device has no biometrics
      return true; 
    }

    try {
      // FIX: Matching your exact IDE signature
      return await auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // Allows device PIN/Pattern as fallback
        persistAcrossBackgrounding: true, // This is the equivalent of stickyAuth
      );
    } catch (e) {
      print('Biometric Error: $e');
      return false;
    }
  }
}