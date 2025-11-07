import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';

class FoodScanPage extends StatefulWidget {
  const FoodScanPage({super.key});

  @override
  State<FoodScanPage> createState() => _FoodScanPageState();
}

class _FoodScanPageState extends State<FoodScanPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _imageInteractionController;
  late AnimationController _stepAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _imageScaleAnimation;
  
  bool _showScannedResult = true;
  bool _tipsExpanded = false;
  String? _highlightedFoodItem;
  OverlayEntry? _tooltipOverlay;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _imageInteractionController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _stepAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _imageScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _imageInteractionController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _imageInteractionController.dispose();
    _stepAnimationController.dispose();
    _tooltipOverlay?.remove();
    super.dispose();
  }

  void _showCustomSnackBar(String message, {bool isSuccess = true}) {
    _tooltipOverlay?.remove();
    
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 300),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSuccess 
                          ? [AppTheme.successGreen, AppTheme.successGreen.withOpacity(0.8)]
                          : [AppTheme.errorRed, AppTheme.errorRed.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isSuccess ? AppTheme.successGreen : AppTheme.errorRed).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  void _showFoodTooltip(String foodName, GlobalKey chipKey) {
    _tooltipOverlay?.remove();
    
    final RenderBox? renderBox = chipKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final position = renderBox.localToGlobal(Offset.zero);
    final overlay = Overlay.of(context);
    
    _tooltipOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: position.dy - 60,
        left: position.dx,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '~${foodName == "Chicken Biryani" ? "180" : "25"} cal',
              style: AppTheme.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(_tooltipOverlay!);
    
    Future.delayed(const Duration(seconds: 2), () {
      _tooltipOverlay?.remove();
      _tooltipOverlay = null;
    });
  }

  void _highlightFoodItem(String foodName) {
    setState(() {
      _highlightedFoodItem = foodName;
    });
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _highlightedFoodItem = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  _buildCompactProgressHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPhotoIdentifySection(isSmallScreen),
                          if (_showScannedResult) ...[
                            const SizedBox(height: 20),
                            _buildCompactReviewSection(),
                            const SizedBox(height: 20),
                            _buildDetectedItemsSection(isSmallScreen),
                            const SizedBox(height: 20),
                            _buildPortionsSection(isSmallScreen),
                            const SizedBox(height: 20),
                            _buildRetakeSection(),
                            const SizedBox(height: 16),
                            _buildExpandableTipsSection(),
                          ],
                          const SizedBox(height: 100), // Space for sticky button
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Sticky Analyze Button with safe area
          if (_showScannedResult)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: _buildStickyAnalyzeButton(),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return const SharedAppBar(
      title: 'GluGo',
      showBackButton: false,
      showConnection: true,
    );
  }

  Widget _buildCompactProgressHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderLight.withOpacity(0.3), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meal Logging',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withOpacity(0.1),
                      AppTheme.primaryBlue.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '50% Complete',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Enhanced step indicator
          Row(
            children: [
              _buildStepIndicator(
                stepNumber: 1,
                stepLabel: 'Photo ID',
                isActive: false,
                isCompleted: true,
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _stepAnimationController,
                  builder: (context, child) {
                    return Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.successGreen,
                            _isAnalyzing 
                              ? AppTheme.primaryBlue
                              : AppTheme.borderLight.withOpacity(0.3),
                          ],
                          stops: [
                            0.5, 
                            _isAnalyzing 
                              ? _stepAnimationController.value.clamp(0.5, 1.0)
                              : 0.5
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    );
                  },
                ),
              ),
              _buildStepIndicator(
                stepNumber: 2,
                stepLabel: 'Analysis',
                isActive: _isAnalyzing,
                isCompleted: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator({
    required int stepNumber,
    required String stepLabel,
    required bool isActive,
    required bool isCompleted,
  }) {
    Color circleColor;
    Color textColor;
    Widget circleChild;

    if (isCompleted) {
      circleColor = AppTheme.successGreen;
      textColor = AppTheme.successGreen;
      circleChild = const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 16,
      );
    } else if (isActive) {
      circleColor = AppTheme.primaryBlue;
      textColor = AppTheme.primaryBlue;
      circleChild = Text(
        stepNumber.toString(),
        style: AppTheme.labelSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      circleColor = AppTheme.borderLight;
      textColor = AppTheme.textTertiary;
      circleChild = Text(
        stepNumber.toString(),
        style: AppTheme.labelSmall.copyWith(
          color: AppTheme.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppTheme.primaryBlue.withOpacity(0.3) : Colors.transparent,
              width: 2,
            ),
            boxShadow: isActive || isCompleted
                ? [
                    BoxShadow(
                      color: circleColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(child: circleChild),
        ),
        const SizedBox(height: 6),
        Text(
          stepLabel,
          style: AppTheme.bodySmall.copyWith(
            color: textColor,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoIdentifySection(bool isSmallScreen) {
    return _MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photo Identify',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload or take a photo of your meal',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTapDown: (_) => _imageInteractionController.forward(),
            onTapUp: (_) => _imageInteractionController.reverse(),
            onTapCancel: () => _imageInteractionController.reverse(),
            onTap: () => _showCustomSnackBar('Camera opening...'),
            child: AnimatedBuilder(
              animation: _imageScaleAnimation,
              builder: (context, child) => Transform.scale(
                scale: _imageScaleAnimation.value,
                child: Container(
                  width: double.infinity,
                  height: isSmallScreen ? 120 : 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryBlue.withOpacity(0.05),
                        AppTheme.primaryBlue.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.3),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: isSmallScreen ? 40 : 48,
                        color: AppTheme.primaryBlue.withOpacity(0.7),
                      ),
                      Positioned(
                        bottom: 12,
                        child: Text(
                          'Tap to capture',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Mobile-optimized button layout
          Column(
            children: [
              _MobileActionButton(
                label: 'Use Camera',
                icon: Icons.camera_alt_rounded,
                onPressed: () => _showCustomSnackBar('Camera opening...'),
                isPrimary: true,
              ),
              const SizedBox(height: 12),
              _MobileActionButton(
                label: 'Upload Photo',
                icon: Icons.photo_library_rounded,
                onPressed: () => _showCustomSnackBar('Gallery opening...'),
                isPrimary: false,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mobile-friendly tips
          Column(
            children: [
              _buildMobileTip('Clear plate view works best'),
              const SizedBox(height: 8),
              _buildMobileTip('Halal-friendly suggestions'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTip(String text) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.successGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactReviewSection() {
    return _MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Detected',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.surfaceVariant.withOpacity(0.3),
                  AppTheme.surfaceVariant.withOpacity(0.6),
                ],
              ),
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2), width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.restaurant_rounded,
                    size: 40,
                    color: AppTheme.primaryBlue.withOpacity(0.7),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Photo captured',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedItemsSection(bool isSmallScreen) {
    return _MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Detected items',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Icon(
                Icons.touch_app_rounded,
                size: 16,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap for nutrition preview',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          // Mobile-optimized chips layout
          Column(
            children: [
              _MobileFoodChip(
                name: 'Chicken Biryani',
                icon: Icons.restaurant_rounded,
                onTap: () {
                  _highlightFoodItem('Chicken Biryani');
                  _showFoodTooltip('Chicken Biryani', GlobalKey());
                },
                onRemove: () => _showCustomSnackBar('Chicken Biryani removed'),
              ),
              const SizedBox(height: 8),
              _MobileFoodChip(
                name: 'Cucumber Salad',
                icon: Icons.eco_rounded,
                onTap: () {
                  _highlightFoodItem('Cucumber Salad');
                  _showFoodTooltip('Cucumber Salad', GlobalKey());
                },
                onRemove: () => _showCustomSnackBar('Cucumber Salad removed'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortionsSection(bool isSmallScreen) {
    return _MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adjust Portions',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fine-tune serving sizes',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.infoBlue.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calculate_outlined,
                      size: 12,
                      color: AppTheme.infoBlue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Auto-estimated',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.infoBlue,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _EnhancedPortionAdjuster(
            foodName: 'Chicken Biryani',
            quantity: '1',
            unit: 'cup',
            calories: '180',
            carbs: '35g',
            isHighlighted: _highlightedFoodItem == 'Chicken Biryani',
            onDecrease: () => _showCustomSnackBar('Portion decreased'),
            onIncrease: () => _showCustomSnackBar('Portion increased'),
            onPortionPresets: () => _showPortionPresets('Chicken Biryani'),
          ),
          const SizedBox(height: 12),
          _EnhancedPortionAdjuster(
            foodName: 'Cucumber Salad',
            quantity: '1',
            unit: 'small bowl',
            calories: '25',
            carbs: '6g',
            isHighlighted: _highlightedFoodItem == 'Cucumber Salad',
            onDecrease: () => _showCustomSnackBar('Portion decreased'),
            onIncrease: () => _showCustomSnackBar('Portion increased'),
            onPortionPresets: () => _showPortionPresets('Cucumber Salad'),
          ),
          const SizedBox(height: 16),
          _buildPortionTips(),
        ],
      ),
    );
  }

  Widget _buildPortionTips() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.successGreen.withOpacity(0.05),
            AppTheme.successGreen.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.successGreen.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.tips_and_updates_outlined,
              size: 14,
              color: AppTheme.successGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tap portion amounts for quick size presets',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.successGreen.withOpacity(0.8),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPortionPresets(String foodName) {
    final presets = foodName == 'Chicken Biryani' 
        ? ['½ cup', '¾ cup', '1 cup', '1¼ cups', '1½ cups']
        : ['Small bowl', 'Medium bowl', 'Large bowl', '2 bowls'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Portion Sizes',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    foodName,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...presets.map((preset) => _buildPresetOption(preset)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetOption(String preset) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            _showCustomSnackBar('Portion updated to $preset');
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.borderLight,
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              preset,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRetakeSection() {
    return _MobileActionButton(
      label: 'Retake Photo',
      icon: Icons.refresh_rounded,
      onPressed: () => _showCustomSnackBar('Retaking photo...'),
      isPrimary: false,
    );
  }

  Widget _buildStickyAnalyzeButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            _animateToAnalysis();
          },
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Analyze Nutrition',
                style: AppTheme.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _animateToAnalysis() async {
    // Start the analysis state
    setState(() {
      _isAnalyzing = true;
    });
    
    // Animate the step progression
    _stepAnimationController.forward();
    
    // Wait for step animation to complete
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Navigate to food analysis route
    Navigator.pushNamed(context, '/food_analysis').then((_) {
      // Reset animation state when returning
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        _stepAnimationController.reset();
      }
    });
  }

  Widget _buildExpandableTipsSection() {
    return _MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _tipsExpanded = !_tipsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.infoBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppTheme.infoBlue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pro Tips',
                    style: AppTheme.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.infoBlue,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _tipsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.infoBlue,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _tipsExpanded ? null : 0,
            child: _tipsExpanded
                ? Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildTipItem('Good lighting and top-down angle improve detection.'),
                      const SizedBox(height: 8),
                      _buildTipItem('Edit items or portions before analysis.'),
                      const SizedBox(height: 8),
                      _buildTipItem('We estimate glucose impact for your profile.'),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.infoBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// Mobile-optimized Card Widget
class _MobileCard extends StatelessWidget {
  final Widget child;

  const _MobileCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Mobile-optimized Action Button
class _MobileActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _MobileActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: isPrimary
          ? LinearGradient(
              colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.9)],
            )
          : null,
        color: isPrimary ? null : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary 
            ? Colors.transparent
            : AppTheme.primaryBlue.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPrimary ? AppTheme.primaryBlue : Colors.black).withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onPressed();
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isPrimary ? Colors.white : AppTheme.primaryBlue).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isPrimary ? Colors.white : AppTheme.primaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTheme.titleSmall.copyWith(
                  color: isPrimary ? Colors.white : AppTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Mobile-optimized Food Chip
class _MobileFoodChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _MobileFoodChip({
    required this.name,
    required this.icon,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withOpacity(0.06),
              AppTheme.primaryBlue.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onRemove();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppTheme.errorRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced Mobile Portion Adjuster
class _EnhancedPortionAdjuster extends StatelessWidget {
  final String foodName;
  final String quantity;
  final String unit;
  final String calories;
  final String carbs;
  final bool isHighlighted;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onPortionPresets;

  const _EnhancedPortionAdjuster({
    required this.foodName,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.carbs,
    required this.isHighlighted,
    required this.onDecrease,
    required this.onIncrease,
    required this.onPortionPresets,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHighlighted 
            ? [
                AppTheme.primaryBlue.withOpacity(0.08),
                AppTheme.primaryBlue.withOpacity(0.04),
              ]
            : [
                AppTheme.backgroundLight,
                AppTheme.backgroundLight.withOpacity(0.5),
              ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted 
            ? AppTheme.primaryBlue.withOpacity(0.3)
            : AppTheme.borderLight,
          width: isHighlighted ? 1.5 : 1,
        ),
        boxShadow: isHighlighted 
          ? [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
      ),
      child: Column(
        children: [
          // Food name and selection indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  foodName,
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isHighlighted ? AppTheme.primaryBlue : AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isHighlighted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'SELECTED',
                    style: AppTheme.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
          
          // Nutritional info
          const SizedBox(height: 12),
          Row(
            children: [
              _buildNutritionBadge('Cal', calories, AppTheme.warningOrange),
              const SizedBox(width: 8),
              _buildNutritionBadge('Carbs', carbs, AppTheme.infoBlue),
              const Spacer(),
              _EnhancedPresetButton(
                onTap: onPortionPresets,
              ),
            ],
          ),
          
          // Portion controls
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Portion Size',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MobilePortionButton(
                    icon: Icons.remove_rounded,
                    onPressed: onDecrease,
                    isEnabled: quantity != '0',
                  ),
                  const SizedBox(width: 16),
                  _InteractivePortionDisplay(
                    quantity: quantity,
                    unit: unit,
                    onTap: onPortionPresets,
                  ),
                  const SizedBox(width: 16),
                  _MobilePortionButton(
                    icon: Icons.add_rounded,
                    onPressed: onIncrease,
                    isEnabled: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTheme.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// Simplified and cleaner Mobile Portion Button
class _MobilePortionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isEnabled;

  const _MobilePortionButton({
    required this.icon,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? () {
          HapticFeedback.lightImpact();
          onPressed();
        } : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEnabled 
              ? AppTheme.surface
              : AppTheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isEnabled 
                ? AppTheme.borderLight
                : AppTheme.borderLight.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isEnabled 
              ? AppTheme.primaryBlue
              : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}

// Cleaner Preset Button
class _EnhancedPresetButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EnhancedPresetButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 14,
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(width: 4),
            Text(
              'Presets',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simplified Interactive Portion Display
class _InteractivePortionDisplay extends StatelessWidget {
  final String quantity;
  final String unit;
  final VoidCallback onTap;

  const _InteractivePortionDisplay({
    required this.quantity,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.9)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              quantity,
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            Text(
              unit,
              style: AppTheme.bodySmall.copyWith(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}