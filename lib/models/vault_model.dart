import 'package:cloud_firestore/cloud_firestore.dart';

class VaultModel {
  final String id;
  final String ownerAddress;
  final String contractAddress;
  final String heirName;
  final String heirEmail;
  final bool isWeb3Native;
  final String heirWalletAddress;
  final String heirPubKey;
  final String encryptedKey;
  final int inactivityDurationSeconds;
  final DateTime lastActive;
  final String status;

  VaultModel({
    required this.id,
    required this.ownerAddress,
    required this.contractAddress,
    required this.heirName,
    required this.heirEmail,
    required this.isWeb3Native,
    required this.heirWalletAddress,
    required this.heirPubKey,
    required this.encryptedKey,
    required this.inactivityDurationSeconds,
    required this.lastActive,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    print('[DEBUG] Serializing VaultModel to Map for Firestore upload...');
    return {
      'ownerAddress': ownerAddress,
      'contractAddress': contractAddress,
      'heirName': heirName,
      'heirEmail': heirEmail,
      'isWeb3Native': isWeb3Native,
      'heirWalletAddress': heirWalletAddress,
      'heirPubKey': heirPubKey,
      'encryptedKey': encryptedKey,
      'inactivityDurationSeconds': inactivityDurationSeconds,
      'lastActive': Timestamp.fromDate(lastActive),
      'status': status,
    };
  }

  factory VaultModel.fromFirestore(DocumentSnapshot doc) {
    print('[DEBUG] Mapping Firestore document to VaultModel: ${doc.id}');
    
    final data = doc.data() as Map<String, dynamic>;
    return VaultModel(
      id: doc.id,
      ownerAddress: data['ownerAddress'] ?? '',
      contractAddress: data['contractAddress'] ?? '',
      heirName: data['heirName'] ?? '',
      heirEmail: data['heirEmail'] ?? '',
      isWeb3Native: data['isWeb3Native'] ?? false,
      heirWalletAddress: data['heirWalletAddress'] ?? '',
      heirPubKey: data['heirPubKey'] ?? '',
      encryptedKey: data['encryptedKey'] ?? '',
      inactivityDurationSeconds: data['inactivityDurationSeconds'] ?? 7776000, // Defaults to 90 days in seconds
      lastActive: (data['lastActive'] as Timestamp).toDate(),
      status: data['status'] ?? 'ACTIVE',
    );
  }
}