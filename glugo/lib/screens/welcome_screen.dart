import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Animation controllers
  late AnimationController _progressController;
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _rotationController;

  // Animations
  late Animation<double> _progressAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Track Your Health Journey",
      subtitle: "Monitor your glucose levels with precision",
      features: ["Real-time tracking", "Smart insights", "Personalized care"],
      primaryColor: const Color(0xFF8FB8FE),
      secondaryColor: const Color(0xFF6C9EFF),
      gradientColors: [const Color(0xFF8FB8FE), const Color(0xFF6C9EFF)],
    ),
    OnboardingPage(
      title: "Smart Glucose Monitoring",
      subtitle: "AI-powered predictions for better control",
      features: ["Automatic logging", "Trend analysis", "Health predictions"],
      primaryColor: const Color(0xFF7B68EE),
      secondaryColor: const Color(0xFF9370DB),
      gradientColors: [const Color(0xFF7B68EE), const Color(0xFF9370DB)],
    ),
    OnboardingPage(
      title: "Personalized Insights",
      subtitle: "Get recommendations tailored just for you",
      features: ["Custom recommendations", "Progress tracking", "Health tips"],
      primaryColor: const Color(0xFF20B2AA),
      secondaryColor: const Color(0xFF48D1CC),
      gradientColors: [const Color(0xFF20B2AA), const Color(0xFF48D1CC)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.elasticOut),
    );

    _floatingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
  }

  void _startAnimations() {
    _floatingController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _showGetStartedAnimation();
    }
  }

  void _showGetStartedAnimation() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const GetStartedDialog(),
    );
  }

  void _skipOnboarding() {
    HapticFeedback.selectionClick();
    _showGetStartedAnimation();
    Navigator.pushReplacementNamed(context, '/auth');
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _progressController.reset();
    _progressController.forward();
    HapticFeedback.selectionClick();
  }

  void _goToPage(int pageIndex) {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPageData = _pages[_currentPage];
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              currentPageData.gradientColors[0],
              currentPageData.gradientColors[1],
              AppTheme.primaryBlue,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: screenHeight < 600 
            ? SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(child: _buildPageView()),
                        _buildBottomNavigation(),
                      ],
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildPageView()),
                  _buildBottomNavigation(),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          Expanded(child: _buildProgressIndicator()),
          const SizedBox(width: 16),
          _buildSkipButton(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(_pages.length, (index) {
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white.withOpacity(0.3),
            ),
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return FractionallySizedBox(
                  widthFactor: index < _currentPage
                      ? 1.0
                      : index == _currentPage
                          ? _progressAnimation.value
                          : 0.0,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0.8)],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSkipButton() {
    return GestureDetector(
      onTap: _skipOnboarding,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.2),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fast_forward_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            const Text(
              "Skip",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: _pages.length,
      itemBuilder: (context, index) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildPageContent(_pages[index], index),
          ),
        );
      },
    );
  }

  Widget _buildPageContent(OnboardingPage page, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          final isSmallScreen = availableHeight < 500;
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isSmallScreen) const Spacer(flex: 1),
              _buildIllustration(page, index, isSmallScreen),
              SizedBox(height: isSmallScreen ? 30 : 50),
              _buildTitle(page.title, isSmallScreen),
              SizedBox(height: isSmallScreen ? 8 : 16),
              _buildSubtitle(page.subtitle, isSmallScreen),
              SizedBox(height: isSmallScreen ? 20 : 32),
              _buildFeaturesList(page.features, page.primaryColor, isSmallScreen),
              if (!isSmallScreen) const Spacer(flex: 1),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIllustration(OnboardingPage page, int index, [bool isSmallScreen = false]) {
    return SizedBox(
      height: isSmallScreen ? 180 : 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildBackgroundCircles(page, isSmallScreen),
          _buildMainIllustration(index, page, isSmallScreen),
          _buildFloatingElements(page),
        ],
      ),
    );
  }

  Widget _buildBackgroundCircles(OnboardingPage page, [bool isSmallScreen = false]) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = isSmallScreen ? 0.7 : 1.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _pulseAnimation.value * 0.8 * scale,
              child: Container(
                width: 220 * scale,
                height: 220 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: _pulseAnimation.value * 0.6 * scale,
              child: Container(
                width: 160 * scale,
                height: 160 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.primaryColor.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainIllustration(int index, OnboardingPage page, [bool isSmallScreen = false]) {
    switch (index) {
      case 0:
        return _buildHealthTrackingIllustration(page, isSmallScreen);
      case 1:
        return _buildGlucoseMonitorIllustration(page, isSmallScreen);
      case 2:
        return _buildInsightsIllustration(page, isSmallScreen);
      default:
        return Container();
    }
  }

  Widget _buildHealthTrackingIllustration(OnboardingPage page, [bool isSmallScreen = false]) {
    final scale = isSmallScreen ? 0.8 : 1.0;
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120 * scale,
              height: 80 * scale,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16 * scale),
                boxShadow: [
                  BoxShadow(
                    color: page.primaryColor.withOpacity(0.3),
                    blurRadius: 20 * scale,
                    offset: Offset(0, 10 * scale),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 12 * scale,
                    left: 12 * scale,
                    right: 12 * scale,
                    child: Container(
                      height: 6 * scale,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: page.gradientColors),
                        borderRadius: BorderRadius.circular(3 * scale),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 28 * scale,
                    left: 12 * scale,
                    right: 12 * scale,
                    bottom: 12 * scale,
                    child: CustomPaint(
                      painter: ChartPainter(page.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 40 * scale,
              right: 40 * scale,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value * scale,
                    child: Container(
                      width: 16 * scale,
                      height: 16 * scale,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.5),
                            blurRadius: 10 * scale,
                            spreadRadius: 2 * scale,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlucoseMonitorIllustration(OnboardingPage page, [bool isSmallScreen = false]) {
    final scale = isSmallScreen ? 0.8 : 1.0;
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, math.sin(_floatingAnimation.value * math.pi) * 5 * scale),
          child: Container(
            width: 100 * scale,
            height: 60 * scale,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12 * scale),
              boxShadow: [
                BoxShadow(
                  color: page.primaryColor.withOpacity(0.3),
                  blurRadius: 20 * scale,
                  offset: Offset(0, 10 * scale),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 80, end: 120),
                    duration: const Duration(seconds: 2),
                    builder: (context, value, child) {
                      return Text(
                        "$value",
                        style: TextStyle(
                          color: page.primaryColor,
                          fontSize: 24 * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: 8 * scale,
                  right: 8 * scale,
                  child: Text(
                    "mg/dL",
                    style: TextStyle(
                      color: page.primaryColor.withOpacity(0.7),
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInsightsIllustration(OnboardingPage page, [bool isSmallScreen = false]) {
    final scale = isSmallScreen ? 0.8 : 1.0;
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100 * scale,
              height: 100 * scale,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: page.primaryColor.withOpacity(0.3),
                    blurRadius: 20 * scale,
                    offset: Offset(0, 10 * scale),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: (_pulseAnimation.value * 0.8 + 0.2) * scale,
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      color: page.primaryColor,
                      size: 50 * scale,
                    ),
                  );
                },
              ),
            ),
            ...List.generate(6, (index) {
              final angle = (index * math.pi * 2) / 6;
              final radius = 80.0 * scale;
              return Transform.translate(
                offset: Offset(
                  math.cos(angle + _rotationAnimation.value) * radius,
                  math.sin(angle + _rotationAnimation.value) * radius,
                ),
                child: Container(
                  width: 8 * scale,
                  height: 8 * scale,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildFloatingElements(OnboardingPage page) {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: 20 + math.sin(_floatingAnimation.value * math.pi) * 10,
              left: 20,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 30 + math.cos(_floatingAnimation.value * math.pi) * 8,
              right: 30,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: page.secondaryColor.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTitle(String title, [bool isSmallScreen = false]) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: TextStyle(
        fontSize: isSmallScreen ? 26 : 32,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 0.5,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(title, textAlign: TextAlign.center),
    );
  }

  Widget _buildSubtitle(String subtitle, [bool isSmallScreen = false]) {
    return Text(
      subtitle,
      style: TextStyle(
        fontSize: isSmallScreen ? 14 : 16,
        fontWeight: FontWeight.w400,
        color: Colors.white.withOpacity(0.9),
        letterSpacing: 0.3,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildFeaturesList(List<String> features, Color primaryColor, [bool isSmallScreen = false]) {
    return Column(
      children: features.asMap().entries.map((entry) {
        final index = entry.key;
        final feature = entry.value;
        
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOutBack,
          margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 500 + (index * 200)),
                width: isSmallScreen ? 6 : 8,
                height: isSmallScreen ? 6 : 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: isSmallScreen ? 4 : 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              SizedBox(width: isSmallScreen ? 16 : 20),
              Expanded(
                child: Text(
                  feature,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPageIndicators(),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      children: List.generate(_pages.length, (index) {
        final isActive = index == _currentPage;
        return GestureDetector(
          onTap: () => _goToPage(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            width: isActive ? 32 : 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: isActive
                  ? LinearGradient(colors: _pages[_currentPage].gradientColors)
                  : null,
              color: isActive ? null : Colors.white.withOpacity(0.4),
            ),
            child: isActive 
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: _pages[_currentPage].primaryColor.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildNextButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: ElevatedButton(
        onPressed: _nextPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _pages[_currentPage].primaryColor,
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Row(
            key: ValueKey(_currentPage),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentPage == _pages.length - 1 ? "Get Started" : "Next",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                _currentPage == _pages.length - 1 
                    ? Icons.rocket_launch_rounded 
                    : Icons.arrow_forward_rounded,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GetStartedDialog extends StatefulWidget {
  const GetStartedDialog({super.key});

  @override
  State<GetStartedDialog> createState() => _GetStartedDialogState();
}

class _GetStartedDialogState extends State<GetStartedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.pushReplacementNamed(context, '/auth');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value * 0.1,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [Colors.white, Color(0xFF8FB8FE)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8FB8FE).withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.rocket_launch_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Let's Go!",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  final Color color;

  ChartPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.2, size.height * 0.4),
      Offset(size.width * 0.4, size.height * 0.6),
      Offset(size.width * 0.6, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.3),
      Offset(size.width, size.height * 0.1),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);

    // Draw dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final List<String> features;
  final Color primaryColor;
  final Color secondaryColor;
  final List<Color> gradientColors;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.features,
    required this.primaryColor,
    required this.secondaryColor,
    required this.gradientColors,
  });
}