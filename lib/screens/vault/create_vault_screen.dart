import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/vault_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/responsive_wrapper.dart';

class CreateVaultScreen extends StatefulWidget {
  const CreateVaultScreen({super.key});

  @override
  State<CreateVaultScreen> createState() => _CreateVaultScreenState();
}

class _CreateVaultScreenState extends State<CreateVaultScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Basic Info
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _walletAddressCtrl = TextEditingController();
  
  // Token Info
  final _amountCtrl = TextEditingController();
  String _selectedToken = 'STRK';
  
  // State
  bool _isDirectWallet = false; 
  bool _isApproving = false; 

  // --- NEW: Time Lock Controls ---
  final _durationCtrl = TextEditingController(text: "30");
  String _durationUnit = 'Seconds'; 

  // Sepolia Testnet Addresses
  final Map<String, String> _tokenAddresses = {
    'STRK': '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d', 
    'ETH': '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7',
    'USDC': '0x0512feac6339ff7889822cb5aa2a86c848e9d392bb0e3e237c008674feed8343',
  };

  void _showInfoModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Beneficiary Setup'),
        content: Text(
          _isDirectWallet 
            ? 'Use this if your beneficiary already has a Starknet wallet (Braavos or Argent). Funds will be sent directly to their address.'
            : 'A secure, hidden wallet will be created for your beneficiary. They will be able to claim it via email using the 6-digit PIN you set here.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Understood'))
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final wallet = context.read<WalletProvider>();
    final double userBalance = wallet.tokenBalances[_selectedToken] ?? 0.0;
    final double amountToLock = double.parse(_amountCtrl.text);

    if (userBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Action Denied: You have 0 $_selectedToken."), backgroundColor: Colors.red)
      );
      return;
    }

    if (amountToLock > userBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Insufficient Funds: You only have $userBalance $_selectedToken"), backgroundColor: Colors.red)
      );
      return;
    }

    // --- NEW: Calculate precise seconds based on UI selection ---
    int multiplier = 1;
    if (_durationUnit == 'Days') multiplier = 86400;
    else if (_durationUnit == 'Hours') multiplier = 3600;
    else if (_durationUnit == 'Minutes') multiplier = 60;
    else if (_durationUnit == 'Seconds') multiplier = 1;
    
    final int totalSeconds = (int.tryParse(_durationCtrl.text) ?? 30) * multiplier;

    setState(() => _isApproving = true);
    
    try {
      final vault = context.read<VaultProvider>();
      
      String heirPubKey = "0x0";
      String encryptedKey = "";
      
      if (!_isDirectWallet) {
        final keyPair = vault.encryption.generateEphemeralKeyPair();
        heirPubKey = keyPair.publicKeyHex;
        encryptedKey = vault.encryption.encryptWithPin(keyPair.privateKeyHex, _pinCtrl.text);
      }

      print('[DEBUG] Launching Wallet for Approval...');
      final success = await wallet.sendCreateVaultTransaction(
        tokenAddress: _tokenAddresses[_selectedToken]!,
        heirAddress: _isDirectWallet ? _walletAddressCtrl.text : "0x0",
        heirPubKey: heirPubKey,
        tokenAmount: amountToLock,
        inactivityDurationSeconds: totalSeconds, // Updated logic
      );

      if (!success) throw Exception("Transaction Rejected or Failed");

      print('[DEBUG] Transaction successful. Fetching On-Chain Vault ID...');
      await Future.delayed(const Duration(milliseconds: 1000));

      final sessionQuery = await FirebaseFirestore.instance
          .collection('transaction_sessions')
          .where('status', isEqualTo: 'success')
          .get();

      if (sessionQuery.docs.isEmpty) throw Exception("Indexer Error: Could not retrieve Vault ID.");

      final docs = sessionQuery.docs;
      docs.sort((a, b) {
        Timestamp? tA = a.data().containsKey('timestamp') ? a.get('timestamp') : null;
        Timestamp? tB = b.data().containsKey('timestamp') ? b.get('timestamp') : null;
        if (tA == null) return 1; 
        if (tB == null) return -1;
        return tB.compareTo(tA); 
      });

      final latestDoc = docs.first;
      final String onChainVaultId = latestDoc.get('onChainVaultId').toString();

      final newVaultId = await vault.createVault(
        ownerAddress: wallet.userAddress!,
        heirName: _nameCtrl.text,
        isWeb3Native: _isDirectWallet,
        heirWalletAddress: _walletAddressCtrl.text,
        heirEmail: _emailCtrl.text,
        inactivityDurationSeconds: totalSeconds, // Updated Logic
        encryptedKey: encryptedKey, 
        heirPubKey: heirPubKey,
        tokenSymbol: _selectedToken,
        amount: _amountCtrl.text,
      );
      
      if (newVaultId != null) {
        await FirebaseFirestore.instance
            .collection('vaults')
            .doc(newVaultId)
            .update({'onChainVaultId': onChainVaultId});
            
        await wallet.refreshBalances(); 

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vault Created Successfully!'), backgroundColor: Colors.green)
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception("Failed to save vault to database");
      }

    } catch (e) {
      print('[ERROR] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Legacy Vault'), elevation: 0),
      body: ResponsiveWrapper(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Who is this vault for?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 20),
                
                Container(
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.2))),
                  child: SwitchListTile(
                    title: const Text("Use Direct Wallet Address"),
                    subtitle: Text(_isDirectWallet ? "Sending to existing wallet" : "Creating new secure access"),
                    value: _isDirectWallet,
                    secondary: IconButton(icon: const Icon(Icons.info_outline, color: Colors.blue), onPressed: _showInfoModal),
                    onChanged: (val) => setState(() => _isDirectWallet = val),
                  ),
                ),
                const SizedBox(height: 20),

                if (_isDirectWallet)
                  TextFormField(
                    controller: _walletAddressCtrl,
                    decoration: const InputDecoration(labelText: 'Starknet Wallet Address', hintText: '0x0...', prefixIcon: Icon(Icons.account_balance_wallet_outlined), border: OutlineInputBorder()),
                    validator: (v) => (v == null || !v.startsWith('0x')) ? 'Invalid Starknet address' : null,
                  )
                else ...[
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Beneficiary Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Email is required' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: '6-Digit Security PIN', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder(), helperText: 'They will need this PIN to claim the vault'),
                    validator: (v) => v!.length != 6 ? 'Enter a 6-digit PIN' : null,
                  ),
                ],

                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 20),

                const Text("Lock Assets", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedToken,
                        decoration: const InputDecoration(labelText: 'Token', border: OutlineInputBorder()),
                        items: _tokenAddresses.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _selectedToken = v!),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount', hintText: '0.00', border: OutlineInputBorder()),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 20),
                
                const Text("Release Inactivity Timer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                const Text("Select how long the vault should wait before unlocking for the beneficiary.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 15),
                
                // --- NEW UI: Manual Time Entry ---
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _durationCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _durationUnit,
                        decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                        items: ['Days', 'Hours', 'Minutes', 'Seconds']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _durationUnit = v!),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _isApproving ? null : _submit,
                    child: _isApproving 
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 15),
                            Text("Waiting for Wallet..."),
                          ],
                        )
                      : const Text('Initialize & Lock Vault', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}