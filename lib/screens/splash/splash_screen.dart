import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/life_line_logo.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _transitionToNextScreen();
  }

  void _transitionToNextScreen() {
    // Hold the splash screen for 2.5 seconds to let the animation play out
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        // Use a smooth fade transition to the next screen
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
              opacity: animation,
              child: widget.nextScreen,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep premium dark background
      body: Center(
        child: const LifeLineLogo(size: 140)
            .animate()
            .fade(duration: 1000.ms)
            .scale(begin: const Offset(0.8, 0.8), duration: 1000.ms, curve: Curves.easeOutBack)
            .then(delay: 200.ms)
            .shimmer(duration: 1200.ms, color: Colors.white24),
      ),
    );
  }
}