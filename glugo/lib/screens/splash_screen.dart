import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _startAnimationSequence();
  }

  void _startAnimationSequence() {
    // Step 1 → Scale in logo (centered)
    Timer(const Duration(milliseconds: 500), () {
      setState(() => _step = 1);
    });

    // Step 2 → Move logo left and slide in "GluGo" from right
    Timer(const Duration(milliseconds: 2000), () {
      setState(() => _step = 2);
    });

    // Step 3 → Move logo+text up and show tagline
    Timer(const Duration(milliseconds: 3500), () {
      setState(() => _step = 3);
    });

    // Step 4 → Show loading indicator
    Timer(const Duration(milliseconds: 5000), () {
      setState(() => _step = 4);
    });

    // Step 5 → Navigate to welcome screen
    Timer(const Duration(milliseconds: 7000), () {
      _navigateToWelcome();
    });
  }

  void _navigateToWelcome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const WelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutBack,
              transform: Matrix4.translationValues(
                0,
                _step >= 3 ? -10.0 : 20.0,
                0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    transform: Matrix4.translationValues(
                      _step >= 2 ? -10.0 : 50.0, 
                      0,
                      0,
                    ),
                    child: AnimatedScale(
                      scale: _step >= 1 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutBack,
                      child: Image.asset(
                        "assets/images/logo.png",
                        width: 100,
                        height: 120,
                      ),
                    ),
                  ),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutBack,
                    transform: Matrix4.translationValues(
                      _step >= 2 ? -10.0 : 100.0, 
                      0,
                      0,
                    ),
                    child: AnimatedOpacity(
                      opacity: _step >= 2 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      child: Padding(
                        padding: EdgeInsets.only(top: 19.0),
                        child: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: "Glu",
                                style: TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8FB8FE), 
                                  letterSpacing: 1.5,
                                ),
                              ),
                              TextSpan(
                                text: "Go",
                                style: TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white, 
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tagline with fade in animation
            AnimatedOpacity(
              opacity: _step >= 3 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(
                  0,
                  _step >= 3 ? -8.0 : 0.0, 
                  0,
                ),
                child: Text(
                  "Manage glucose on the go",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),

            // Loading indicator
            AnimatedOpacity(
              opacity: _step >= 4 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(
                  0,
                  _step >= 4 ? 0.0 : 20.0,
                  0,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 40.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}