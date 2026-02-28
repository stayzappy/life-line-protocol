import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/starknet_service.dart';
import '../../config/routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final StarknetService _starknetService = StarknetService();
  

  String _formatAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  void _showDisconnectDialog(BuildContext context, WalletProvider wallet) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2028),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text("Disconnect Wallet", style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            "Are you sure you want to disconnect? You will need to re-authenticate to manage your vaults.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await wallet.disconnect();
              },
              child: const Text("Disconnect", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final vaultProvider = context.read<VaultProvider>();
    final ownerAddress = wallet.userAddress ?? "0x00";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (wallet.isConnected && wallet.userAddress != null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        wallet.network,
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: wallet.userAddress!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Address copied!")));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2D3A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatAddress(wallet.userAddress!),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                label: const Text("Disconnect", style: TextStyle(color: Colors.redAccent)),
                onPressed: () => _showDisconnectDialog(context, wallet),
              ),
            ),
          ],
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: wallet.isConnected ? () => Navigator.pushNamed(context, AppRoutes.createVault) : null,
        backgroundColor: wallet.isConnected ? Theme.of(context).primaryColor : Colors.grey[800],
        icon: Icon(Icons.shield, color: wallet.isConnected ? Colors.white : Colors.white54),
        label: Text('New Vault', style: TextStyle(color: wallet.isConnected ? Colors.white : Colors.white54)),
      ),

      body: RefreshIndicator(
        color: Theme.of(context).primaryColor,
        backgroundColor: const Color(0xFF1E2028),
        onRefresh: () async => await wallet.refreshBalances(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (wallet.isConnected) _buildTokenBalancesSection(wallet),

            if (!wallet.isConnected)
              Container(
                height: MediaQuery.of(context).size.height * 0.5,
                alignment: Alignment.center,
                child: const Text(
                  "Please connect your wallet to manage your vaults.",
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              )
            else
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('vaults')
                    .where('ownerAddress', isEqualTo: ownerAddress)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                  if (snapshot.data!.docs.isEmpty) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: Text("No vaults active. Create one!", style: TextStyle(color: Colors.grey))),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        return LiveVaultCard(
                          doc: doc, 
                          wallet: wallet, 
                          vaultProvider: vaultProvider, 
                          starknetService: _starknetService
                        ).animate().fadeIn(delay: (index * 100).ms);
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenBalancesSection(WalletProvider wallet) {
    if (wallet.hasNetworkError) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        color: Colors.grey[900],
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            const Text("Sync Failed", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            Text("Pull down to retry", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ],
        ),
      ).animate().fadeIn();
    }

    final displayTokens = ['STRK', 'ETH', 'USDC', 'USDT', 'WBTC'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: displayTokens.map((symbol) {
          Color color = Colors.white;
          if (symbol == 'STRK') color = Colors.blue;
          if (symbol == 'USDC') color = Colors.greenAccent;
          if (symbol == 'USDT') color = Colors.tealAccent;
          if (symbol == 'ETH') color = Colors.purpleAccent;
          if (symbol == 'WBTC') color = Colors.orange;

          final balance = wallet.tokenBalances[symbol] ?? 0.0;
          return Expanded(
            child: Column(
              children: [
                Text(symbol, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                wallet.isLoading
                    ? Container(width: 50, height: 15, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1000.ms)
                    : Text(balance.toStringAsFixed(3), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ==============================================================================
// UPDATED LIVE VAULT CARD COMPONENT (Auto-Trigger & UI Sync Fixes)
// ==============================================================================
class LiveVaultCard extends StatefulWidget {
  final DocumentSnapshot doc;
  final WalletProvider wallet;
  final VaultProvider vaultProvider;
  final StarknetService starknetService;

  const LiveVaultCard({
    super.key, 
    required this.doc, 
    required this.wallet, 
    required this.vaultProvider,
    required this.starknetService
  });

  @override
  State<LiveVaultCard> createState() => _LiveVaultCardState();
}

class _LiveVaultCardState extends State<LiveVaultCard> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant LiveVaultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _calculateTime(); 
  }

  void _startTimer() {
    _calculateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTime();
    });
  }

  void _calculateTime() {
    final data = widget.doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? "ACTIVE";
    
    if (status != 'ACTIVE') {
      _timer?.cancel();
      if (mounted) setState(() => _timeLeft = Duration.zero);
      return;
    }

    final Timestamp? rawTimestamp = data['lastActive'] as Timestamp?;
    final DateTime lastActive = rawTimestamp != null ? rawTimestamp.toDate() : DateTime.now();
    final int inactivityDurationSeconds = data['inactivityDurationSeconds'] ?? 7776000;
    
    final unlockTime = lastActive.add(Duration(seconds: inactivityDurationSeconds));
    final diff = unlockTime.difference(DateTime.now());

    if (diff.isNegative) {
      _timer?.cancel();
      if (mounted) setState(() => _timeLeft = Duration.zero);
      
      // ✅ FIX: Safely trigger the email outside the build cycle
      if (!_hasTriggered) {
        _hasTriggered = true;
        print("[DEBUG] Timer hit ZERO. Auto-Triggering Email!");
        
        Future.microtask(() {
          widget.vaultProvider.triggerInheritance(widget.doc.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Timer Exhausted! Automated email triggered."), 
                backgroundColor: Colors.green
              )
            );
          }
        });
      }
    } else {
      if (mounted) setState(() => _timeLeft = diff);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimeLeft(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String days = twoDigits(duration.inDays);
    String hours = twoDigits(duration.inHours.remainder(24));
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$days:$hours:$minutes:$seconds";
  }

  String _formatAmount(String amount) {
    if (amount.isEmpty) return "0";
    double val = double.tryParse(amount) ?? 0.0;
    if (val % 1 == 0) return val.toInt().toString();
    return val.toString();
  }

  // ... (Keep _showAmountDialog, _showCancelConfirmation, and _handlePingVault exactly as they were) ...
  void _showAmountDialog(BuildContext context, String title, Function(double) onConfirm) {
    final TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D3A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Amount', labelStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                onConfirm(val);
              }
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context, Function() onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D3A),
        title: const Text("Cancel Vault?", style: TextStyle(color: Colors.redAccent)),
        content: const Text("This will close the vault and refund all assets immediately.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Keep Vault")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { Navigator.pop(ctx); onConfirm(); },
            child: const Text("Close Vault"),
          ),
        ],
      ),
    );
  }

  Future<bool> _handlePingVault(String firebaseDocId, String onChainVaultId, String contractAddress) async {
    final completer = Completer<bool>();
    widget.wallet.pingVault(
      vaultContractAddress: contractAddress,
      vaultId: onChainVaultId,
      context: context,
      onResult: (txSuccess) async {
        if (txSuccess) {
          final dbSuccess = await widget.vaultProvider.pingVault(firebaseDocId);
          completer.complete(dbSuccess);
        } else {
          completer.complete(false);
        }
      },
    );
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final bool isWeb3 = data['isWeb3Native'] ?? false;
    final String amountStr = data['amount']?.toString() ?? "0";
    final double amountVal = double.tryParse(amountStr) ?? 0.0;
    final String tokenSymbol = data['tokenSymbol'] ?? "STRK";
    final String status = data['status'] ?? "ACTIVE";
    final String? onChainId = data['onChainVaultId'];

    Widget card = Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1E2028),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['heirName'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(isWeb3 ? Icons.wallet : Icons.email, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(isWeb3 ? "Direct Transfer" : "Email Claim", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                if (status == 'ACTIVE' || status == 'UNLOCKED')
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    color: const Color(0xFF2A2D3A),
                    onSelected: (value) async {
                      if (onChainId == null) return;
                      final String? tokenAddr = widget.starknetService.getTokenAddress(tokenSymbol);
                      if (tokenAddr == null) return;

                      if (value == 'add') {
                        _showAmountDialog(context, "Add Funds ($tokenSymbol)", (val) async {
                          final success = await widget.wallet.addFundsToVault(vaultId: onChainId, tokenAddress: tokenAddr, amount: val);
                          if (success && mounted) await widget.vaultProvider.addFunds(widget.doc.id, val);
                        });
                      } else if (value == 'withdraw') {
                        _showAmountDialog(context, "Withdraw Funds", (val) async {
                          final success = await widget.wallet.withdrawFromVault(vaultId: onChainId, amount: val, tokenAddress: tokenAddr);
                          if (success && mounted) await widget.vaultProvider.withdrawFunds(widget.doc.id, val);
                        });
                      } else if (value == 'cancel') {
                        _showCancelConfirmation(context, () async {
                          final success = await widget.wallet.cancelVault(onChainId);
                          if (success && mounted) await widget.vaultProvider.cancelVault(widget.doc.id);
                        });
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      bool isZero = amountVal <= 0;
                      return <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(value: 'add', child: Row(children: [Icon(Icons.add, color: Colors.green, size: 18), SizedBox(width: 8), Text("Add Funds", style: TextStyle(color: Colors.white))])),
                        if (!isZero) const PopupMenuItem<String>(value: 'withdraw', child: Row(children: [Icon(Icons.download, color: Colors.orange, size: 18), SizedBox(width: 8), Text("Withdraw", style: TextStyle(color: Colors.white))])),
                        if (!isZero) const PopupMenuItem<String>(value: 'cancel', child: Row(children: [Icon(Icons.close, color: Colors.red, size: 18), SizedBox(width: 8), Text("Cancel Vault", style: TextStyle(color: Colors.white))])),
                      ];
                    },
                  ),
              ],
            ),
            const SizedBox(height: 15),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${_formatAmount(amountStr)} $tokenSymbol", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.orangeAccent, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          status == 'ACTIVE' ? _formatTimeLeft(_timeLeft) : "00:00:00:00",
                          style: TextStyle(
                            color: _timeLeft.inSeconds < 60 && status == 'ACTIVE' ? Colors.redAccent : Colors.orangeAccent, 
                            fontSize: 14, 
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace' 
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                if (status == 'ACTIVE')
                  Container(
                    decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.blueAccent, size: 20),
                      onPressed: () => widget.vaultProvider.triggerInheritance(widget.doc.id),
                      tooltip: "Force Trigger",
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // ✅ FIX: Dedicated UI state for CLAIMED vs UNLOCKED vs ACTIVE
            if (status == 'ACTIVE')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.fingerprint, size: 20),
                  label: widget.wallet.isLoading
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("I'M ALIVE (Ping)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: widget.wallet.isLoading || onChainId == null
                      ? null
                      : () async {
                          final tokenAddr = widget.starknetService.getTokenAddress(tokenSymbol);
                          if (tokenAddr != null) await _handlePingVault(widget.doc.id, onChainId, tokenAddr);
                        },
                ),
              )
            else if (status == 'CLAIMED')
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withOpacity(0.5))),
                child: const Center(
                  child: Text("VAULT CLAIMED ✓", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Text("VAULT $status", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );

    if (status == 'CANCELLED' || status == 'CLAIMED') {
      return Dismissible(
        key: Key(widget.doc.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (direction) {
          widget.vaultProvider.deleteVault(widget.doc.id);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vault removed")));
        },
        child: card,
      );
    }

    return card;
  }
}