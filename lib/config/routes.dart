import 'package:flutter/material.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/connect_wallet_screen.dart';
import '../screens/dashboard/home_screen.dart';
import '../screens/vault/create_vault_screen.dart';

class AppRoutes {
  static const String onboarding = '/';
  static const String connectWallet = '/connect_wallet';
  static const String dashboard = '/dashboard';
  static const String createVault = '/create_vault';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case connectWallet:
        return MaterialPageRoute(builder: (_) => const ConnectWalletScreen());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case createVault:
        return MaterialPageRoute(builder: (_) => const CreateVaultScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}