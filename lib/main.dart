import 'package:flutter/material.dart';
import 'package:life_line_gm/screens/auth/connect_wallet_screen.dart';
import 'package:life_line_gm/screens/dashboard/home_screen.dart';
import 'package:life_line_gm/screens/onboarding/onboarding_screen.dart';
import 'package:life_line_gm/screens/splash/splash_screen.dart'; // ✅ NEW IMPORT
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'services/navigation_service.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/wallet_provider.dart';
import 'providers/vault_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env'); 
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('[DEBUG] System Boot: Checking local storage for initial route...');
  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
  final savedAddress = prefs.getString('user_wallet_address');

  String initialRoute = AppRoutes.onboarding;

  if (hasSeenOnboarding) {
    if (savedAddress != null && savedAddress.isNotEmpty) {
      print('[DEBUG] User is already logged in. Routing directly to Dashboard.');
      initialRoute = AppRoutes.dashboard;
    } else {
      print('[DEBUG] User has seen onboarding but is logged out. Routing to Connect Wallet.');
      initialRoute = AppRoutes.connectWallet;
    }
  } else {
    print('[DEBUG] First-time user detected. Routing to Onboarding.');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = WalletProvider(navigatorKey: navigatorKey);
            provider.restoreSession();
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => VaultProvider()),
      ],
      child: LifeLineApp(initialRoute: initialRoute),
    ),
  );
}

class LifeLineApp extends StatelessWidget {
  final String initialRoute;

  const LifeLineApp({super.key, required this.initialRoute});

  // ✅ FIX: Determine the target screen, but wrap it in the SplashScreen!
  Widget _getInitialScreen() {
    print('[DEBUG] Target screen: $initialRoute');
    
    Widget targetScreen;
    if (initialRoute == AppRoutes.dashboard) {
      targetScreen = const HomeScreen();
    } else if (initialRoute == AppRoutes.connectWallet) {
      targetScreen = const ConnectWalletScreen();
    } else {
      targetScreen = const OnboardingScreen();
    }

    // Return the SplashScreen, and hand it the target screen to fade into
    return SplashScreen(nextScreen: targetScreen); 
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeLine Protocol',
      navigatorKey: navigatorKey, 
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, 
      onGenerateRoute: AppRoutes.generateRoute,
      home: _getInitialScreen(), 
    );
  }
}