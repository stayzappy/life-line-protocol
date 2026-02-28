import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart'; // REQUIRED for developer link
import '../../config/routes.dart';
import '../../providers/wallet_provider.dart';

class ConnectWalletScreen extends StatefulWidget {
  const ConnectWalletScreen({super.key});

  @override
  State<ConnectWalletScreen> createState() => _ConnectWalletScreenState();

}

class _ConnectWalletScreenState extends State<ConnectWalletScreen> {
  @override
  void initState() {
    super.initState();
    // WalletProvider now initializes itself in constructor
    // No need to call init() here anymore
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();

    if (walletProvider.isConnected) {
      Future.delayed(Duration.zero, () {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F222A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10),
                ),
                child: walletProvider.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(Icons.account_balance_wallet, size: 60, color: Colors.white),
              ).animate().scale(duration: 500.ms),
              
              const SizedBox(height: 40),
              Text(
                'Link Your Wallet',
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Select your Starknet wallet to authenticate securely and create your vault.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[500], height: 1.5),
              ),
              
              const Spacer(),

              // --- OPEN ARGENT/READY MODAL BUTTON (DISABLED FOR HACKATHON) ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  // onPressed: walletProvider.isLoading
                  //     ? null
                  //     : () => walletProvider.connect(context),
                  onPressed: null, // Hard disabled for now
                  icon: Icon(Icons.wallet_travel, color: Colors.grey[700]),
                  label: Text('Connect Argent / Ready (Soon)', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F222A).withOpacity(0.5),
                    disabledBackgroundColor: const Color(0xFF15171E), 
                    side: BorderSide(color: Colors.white.withOpacity(0.05)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).moveY(begin: 20, end: 0),

              const SizedBox(height: 16),

              // --- SECRET BYPASS BRAAVOS BUTTON (PRIMARY) ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: walletProvider.isLoading
                      ? null
                      : () => walletProvider.connectBraavosNatively(),
                  icon: const Icon(Icons.shield),
                  label: const Text('Connect Braavos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B44F6), // Made it the primary bright blue
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms).moveY(begin: 20, end: 0),

              const SizedBox(height: 20),

              // --- DEVELOPER CREDIT FOOTER ---
              const Spacer(), 
              
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('https://zappythedev.web.app');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: Colors.transparent, // Increases clickable area
                  child: Column(
                    children: [
                      Text(
                        'Built for the Starknet Community by',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ZappyTheDev',
                        style: GoogleFonts.inter(
                          fontSize: 13, 
                          color: const Color(0xFF3B44F6),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 800.ms), 
              ),
            ],
          ),
        ),
      ),
    );
  }
}