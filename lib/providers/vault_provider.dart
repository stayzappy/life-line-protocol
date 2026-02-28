import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/vault_model.dart';
import '../services/encryption_service.dart';
import '../services/email_service.dart';
import '../services/biometric_service.dart';

class VaultProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final _encryption = EncryptionService();
  final _email = EmailService();
  final _biometrics = BiometricService();

  EncryptionService get encryption => _encryption;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // --- CREATE VAULT ---
  Future<String?> createVault({
    required String ownerAddress,
    required String heirName,
    required bool isWeb3Native,
    required String heirWalletAddress, 
    required String heirEmail,         
    required int inactivityDurationSeconds,
    required String encryptedKey, 
    required String heirPubKey,
    required String tokenSymbol,
    required String amount,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final vaultId = "${ownerAddress}_${DateTime.now().millisecondsSinceEpoch}";
      
      final vaultData = VaultModel(
        id: vaultId,
        ownerAddress: ownerAddress,
        contractAddress: dotenv.env['LIFELINE_CONTRACT_ADDRESS'] ?? '',
        heirName: heirName,
        heirEmail: heirEmail,
        isWeb3Native: isWeb3Native,
        heirWalletAddress: heirWalletAddress,
        heirPubKey: heirPubKey,        
        encryptedKey: encryptedKey,    
        inactivityDurationSeconds: inactivityDurationSeconds,
        lastActive: DateTime.now(),
        status: 'ACTIVE',
      );

      final Map<String, dynamic> data = vaultData.toMap();
      data['tokenSymbol'] = tokenSymbol;
      data['amount'] = amount;
      
      await _firestore.collection('vaults').doc(vaultId).set(data);
      _isLoading = false;
      notifyListeners();
      
      return vaultId; 
    } catch (e) {
      print('[DEBUG] CRITICAL ERROR during createVault: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // --- PING (I'M ALIVE) ---
  Future<bool> pingVault(String vaultId) async {
    final isAuthenticated = await _biometrics.authenticate(reason: "Verify LifeLine");
    if (!isAuthenticated) return false;

    try {
      await _firestore.collection('vaults').doc(vaultId).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- ADD FUNDS (SYNC) ---
  Future<bool> addFunds(String vaultId, double addedAmount) async {
    try {
      final doc = await _firestore.collection('vaults').doc(vaultId).get();
      if (!doc.exists) return false;

      String currentStr = doc.data()?['amount'] ?? "0";
      double current = double.tryParse(currentStr) ?? 0.0;
      double newTotal = current + addedAmount;

      await _firestore.collection('vaults').doc(vaultId).update({
        'amount': newTotal.toString(),
      });
      notifyListeners();
      return true;
    } catch (e) {
      print("Error adding funds DB: $e");
      return false;
    }
  }

  // --- WITHDRAW FUNDS (SYNC) ---
  Future<bool> withdrawFunds(String vaultId, double withdrawnAmount) async {
    try {
      final doc = await _firestore.collection('vaults').doc(vaultId).get();
      if (!doc.exists) return false;

      String currentStr = doc.data()?['amount'] ?? "0";
      double current = double.tryParse(currentStr) ?? 0.0;
      double newTotal = current - withdrawnAmount;
      if (newTotal < 0) newTotal = 0;

      await _firestore.collection('vaults').doc(vaultId).update({
        'amount': newTotal.toString(),
      });
      notifyListeners();
      return true;
    } catch (e) {
      print("Error withdrawing funds DB: $e");
      return false;
    }
  }

  // --- CANCEL VAULT (SYNC) ---
  Future<bool> cancelVault(String vaultId) async {
    try {
      await _firestore.collection('vaults').doc(vaultId).update({
        'status': 'CANCELLED',
        'amount': '0', // Funds returned to user
      });
      notifyListeners();
      return true;
    } catch (e) {
      print("Error cancelling vault DB: $e");
      return false;
    }
  }

  // --- DELETE VAULT (Clean up History) ---
  Future<void> deleteVault(String vaultId) async {
    try {
      print("[DEBUG] Deleting vault $vaultId from history...");
      await _firestore.collection('vaults').doc(vaultId).delete();
      notifyListeners();
    } catch (e) {
      print("Error deleting vault: $e");
    }
  }

  // --- TRIGGER INHERITANCE (Test Mode) ---
  Future<void> triggerInheritance(String vaultId) async {
    print('[DEBUG] Triggering inheritance sequence for Vault: $vaultId');
    try {
      final doc = await _firestore.collection('vaults').doc(vaultId).get();
      if (!doc.exists) {
        print('[DEBUG] ERROR: Vault not found.');
        return;
      }
      
      final data = doc.data()!;
      final isWeb3 = data['isWeb3Native'] ?? false;
      
      bool emailSent = false; // ✅ Track the email status
      
      if (isWeb3) {
        print('[DEBUG] Beneficiary is Web3 Native. Sending direct notification email...');
        emailSent = await _email.sendInheritanceEmail(
          heirName: data['heirName'],
          heirEmail: data['heirEmail'] ?? "", 
          ownerName: "A loved one", 
          message: "Your inherited LifeLine Protocol vault is now unlocked. Connect your Starknet wallet to claim your assets.",
          decryptedPrivateKey: "Direct Wallet Claim", 
          amount: data['amount']?.toString() ?? "Assets", 
          tokenSymbol: data['tokenSymbol']?.toString() ?? "",
        );
      } else {
        final claimLink = "https://lifelinereadyconnect.web.app/claim?vaultId=$vaultId";
        print('[DEBUG] Generated Web2 Claim Link: $claimLink');

        emailSent = await _email.sendInheritanceEmail(
          heirName: data['heirName'],
          heirEmail: data['heirEmail'],
          ownerName: "A loved one", 
          message: "You have received a secure digital inheritance. Click the secure link below to unlock the vault using your 6-Digit PIN.",
          decryptedPrivateKey: claimLink, 
          amount: data['amount']?.toString() ?? "Assets", 
          tokenSymbol: data['tokenSymbol']?.toString() ?? "",
        );
      }
      
      // ✅ FIX: Only lock the vault on the UI if the email actually left the device
      if (emailSent) {
        await _firestore.collection('vaults').doc(vaultId).update({'status': 'UNLOCKED'});
        print('[DEBUG] Inheritance triggered and notification dispatched successfully.');
      } else {
        print('[DEBUG] Email failed to send. Vault status remains ACTIVE.');
      }
      
    } catch (e) {
      print("[DEBUG] Trigger Failed: $e");
    }
  }
}