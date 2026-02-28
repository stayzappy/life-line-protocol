import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:starknet/starknet.dart';
import '../config/constants.dart';

class EncryptionService {

  // 1. Generate Ephemeral Starknet Key Pair for Web2 Users
  ({String privateKeyHex, String publicKeyHex}) generateEphemeralKeyPair() {
    print('[DEBUG] Generating new Ephemeral Starknet Key Pair...');
    
    try {
      // Generate a secure random 252-bit private key for the Starknet curve
      final random = Random.secure();
      final bytes = List<int>.generate(31, (i) => random.nextInt(256));
      final hexString = '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      
      // Use the fromHexString factory based directly on the Felt API reference
      final privateKeyFelt = Felt.fromHexString(hexString);
      
      // THE API-COMPLIANT FIX: Wrap the private key in StarkSigner, then pass to StarkAccountSigner
      final starkSigner = StarkSigner(privateKey: privateKeyFelt);
      final accountSigner = StarkAccountSigner(signer: starkSigner);
      final publicKeyFelt = accountSigner.publicKey;

      final privHex = privateKeyFelt.toHexString();
      final pubHex = publicKeyFelt.toHexString();

      print('[DEBUG] Ephemeral Private Key generated: ***HIDDEN***');
      print('[DEBUG] Ephemeral Public Key derived: $pubHex');
      
      return (privateKeyHex: privHex, publicKeyHex: pubHex);
    } catch (e) {
      print('[DEBUG] CRITICAL ERROR generating Ephemeral Key Pair: $e');
      rethrow;
    }
  }

  // 2. Encrypt Data using the Beneficiary's PIN
  String encryptWithPin(String plainText, String pin) {
    print('[DEBUG] Encrypting payload with 6-digit PIN...');
    
    // Combine PIN and App Secret to create a strong 32-byte AES Key
    final secretRaw = pin + AppConstants.appSecret;
    final keyBytes = sha256.convert(utf8.encode(secretRaw)).bytes;
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    
    // Use a dynamic IV for production-grade security
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    // Return IV and Ciphertext concatenated so we can extract the IV later to decrypt
    final result = '${iv.base64}:${encrypted.base64}';
    print('[DEBUG] Payload encrypted successfully.');
    return result;
  }

  // 3. Decrypt Data using the Beneficiary's PIN
  String decryptWithPin(String encryptedPayload, String pin) {
    print('[DEBUG] Attempting to decrypt payload with PIN...');
    try {
      final parts = encryptedPayload.split(':');
      if (parts.length != 2) throw Exception('Invalid encrypted payload format');
      
      final iv = encrypt.IV.fromBase64(parts[0]);
      final cipherText = parts[1];
      
      final secretRaw = pin + AppConstants.appSecret;
      final keyBytes = sha256.convert(utf8.encode(secretRaw)).bytes;
      final key = encrypt.Key(Uint8List.fromList(keyBytes));
      
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt(encrypt.Encrypted.fromBase64(cipherText), iv: iv);
      
      print('[DEBUG] Payload decrypted successfully.');
      return decrypted;
    } catch (e) {
      print('[DEBUG] Decryption FAILED. Incorrect PIN or corrupted data: $e');
      rethrow;
    }
  }
}