import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';
import '../services/api_service.dart';
import '../models/food_models.dart'; 

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
  
  // State management
  bool _showScannedResult = false;
  bool _tipsExpanded = false;
  bool _isAnalyzing = false;
  bool _isUploading = false;
  int _currentMode = 0; // 0 = camera, 1 = gallery
  
  // Image and analysis data
  File? _capturedImage;
  Map<String, dynamic>? _analysisResult;
  List<FoodComponent> _detectedItems = [];
  String? _errorMessage;
  
  // Gallery state
  List<XFile> _galleryImages = [];
  List<bool> _selectedImages = [];
  int _selectedImageCount = 0;
  
  // Services
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();

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
    super.dispose();
  }

  // Load gallery images
  Future<void> _loadGalleryImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 60,
        maxWidth: 800,
        maxHeight: 800,
      );
      
      if (images.isNotEmpty) {
        setState(() {
          _galleryImages = images;
          _selectedImages = List<bool>.filled(images.length, false);
        });
      }
    } catch (e) {
      print('Error loading gallery images: $e');
    }
  }

  // Camera functionality
  Future<void> _openCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
          _showScannedResult = true;
          _errorMessage = null;
        });
        _showCustomSnackBar('Photo captured successfully!');
      }
    } catch (e) {
      print('Error opening camera: $e');
      _showCustomSnackBar('Failed to open camera: $e', isSuccess: false);
    }
  }

  // Gallery upload functionality
  Future<void> _openGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
          _showScannedResult = true;
          _errorMessage = null;
        });
        _showCustomSnackBar('Photo uploaded successfully!');
      }
    } catch (e) {
      print('Error opening gallery: $e');
      _showCustomSnackBar('Failed to open gallery: $e', isSuccess: false);
    }
  }

  // Analyze selected gallery images
  Future<void> _analyzeSelectedImages() async {
    if (_selectedImageCount == 0) {
      _showCustomSnackBar('Please select at least one image', isSuccess: false);
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      // Get first selected image for analysis
      final selectedIndex = _selectedImages.indexWhere((selected) => selected);
      if (selectedIndex != -1) {
        final selectedImage = _galleryImages[selectedIndex];
        setState(() {
          _capturedImage = File(selectedImage.path);
        });
        
        // Call backend AI service
        final result = await _apiService.analyzeImageAI(_capturedImage!);
        
        if (result != null && result['name'] != null) {
          setState(() {
            _analysisResult = result;
            _detectedItems = _parseComponents(result);
            _isAnalyzing = false;
          });
          
          _showCustomSnackBar('Analysis complete!');
          
          // Navigate to food analysis page with results
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pushNamed(
              context, 
              '/food_analysis',
              arguments: {
                'analysisResult': _analysisResult,
                'detectedItems': _detectedItems,
                'capturedImage': _capturedImage,
              },
            );
          }
        } else {
          setState(() {
            _isAnalyzing = false;
            _errorMessage = 'Unable to analyze image. Please try again.';
          });
          _showCustomSnackBar('Analysis failed', isSuccess: false);
        }
      }
    } catch (e) {
      print('Error analyzing image: $e');
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
      _showCustomSnackBar('Analysis failed: ${e.toString()}', isSuccess: false);
    }
  }

  // Analyze image with backend AI
  Future<void> _analyzeImage() async {
    if (_capturedImage == null) {
      _showCustomSnackBar('Please capture a photo first', isSuccess: false);
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    // Animate the step progression
    _stepAnimationController.forward();

    try {
      // Call backend AI service
      final result = await _apiService.analyzeImageAI(_capturedImage!);
      
      if (result != null && result['name'] != null) {
        setState(() {
          _analysisResult = result;
          _detectedItems = _parseComponents(result);
          _isAnalyzing = false;
        });
        
        _showCustomSnackBar('Analysis complete!');
        
        // Navigate to food analysis page with results
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushNamed(
            context, 
            '/food_analysis',
            arguments: {
              'analysisResult': _analysisResult,
              'detectedItems': _detectedItems,
              'capturedImage': _capturedImage,
            },
          );
        }
      } else {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'Unable to analyze image. Please try again.';
        });
        _showCustomSnackBar('Analysis failed', isSuccess: false);
      }
    } catch (e) {
      print('Error analyzing image: $e');
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
      _showCustomSnackBar('Analysis failed: ${e.toString()}', isSuccess: false);
    } finally {
      _stepAnimationController.reset();
    }
  }

  // Parse components from API response
  List<FoodComponent> _parseComponents(Map<String, dynamic> result) {
    final components = <FoodComponent>[];
    
    if (result['components'] != null && result['components'] is List) {
      for (var component in result['components']) {
        components.add(FoodComponent(
          name: component['name'] ?? 'Unknown',
          carbsG: (component['carbs_g'] ?? 0).toDouble(),
          quantity: 1,
          unit: 'serving',
        ));
      }
    }
    
    return components;
  }

  void _showCustomSnackBar(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 18,
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
        backgroundColor: isSuccess ? AppTheme.successGreen : AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusM),
        margin: const EdgeInsets.all(AppTheme.spacingL),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
      _showScannedResult = false;
      _analysisResult = null;
      _detectedItems.clear();
      _errorMessage = null;
      _selectedImages = List<bool>.filled(_galleryImages.length, false);
      _selectedImageCount = 0;
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
                          const SizedBox(height: 16),
                          
                
                            _buildCameraSection(isSmallScreen),
                  
                          
                          // Show results after photo is captured
                          if (_showScannedResult) ...[
                            const SizedBox(height: 20),
                            _buildCompactReviewSection(),
                            const SizedBox(height: 20),
                            if (_detectedItems.isNotEmpty)
                              _buildDetectedItemsSection(isSmallScreen),
                            if (_detectedItems.isNotEmpty)
                              const SizedBox(height: 20),
                            _buildRetakeSection(),
                            const SizedBox(height: 16),
                            _buildEnhancedTipsSection(),
                          ],
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Sticky Analyze Button (only show when photo is captured or images are selected)
          if ((_showScannedResult || _selectedImageCount > 0) && !_isAnalyzing)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: _buildStickyAnalyzeButton(),
            ),
          
          // Enhanced loading overlay during analysis
          if (_isAnalyzing)
            _buildEnhancedAnalyzingOverlay(),
        ],
      ),
      bottomNavigationBar: _currentMode == 1 && _galleryImages.isNotEmpty 
          ? _buildGalleryBottomBar() 
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return const SharedAppBar(
      title: 'Food Scanner',
      showBackButton: false,
      showConnection: false,
    );
  }

 
  Widget _buildCameraSection(bool isSmallScreen) {
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
          
          // Show captured image or camera placeholder
          _capturedImage != null
              ? _buildCapturedImagePreview(isSmallScreen)
              : _buildCameraPlaceholder(isSmallScreen),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Column(
            children: [
              _MobileActionButton(
                label: 'Use Camera',
                icon: Icons.camera_alt_rounded,
                onPressed: _openCamera,
                isPrimary: true,
              ),
              const SizedBox(height: 12),
              _MobileActionButton(
                label: 'Upload Photo',
                icon: Icons.photo_library_rounded,
                onPressed: _openGallery,
                isPrimary: false,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Tips
          Column(
            children: [
              _buildMobileTip('Clear plate view works best'),
              const SizedBox(height: 8),
              _buildMobileTip('Good lighting improves accuracy'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPlaceholder(bool isSmallScreen) {
    return GestureDetector(
      onTapDown: (_) => _imageInteractionController.forward(),
      onTapUp: (_) => _imageInteractionController.reverse(),
      onTapCancel: () => _imageInteractionController.reverse(),
      onTap: _openCamera,
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
    );
  }

  Widget _buildCapturedImagePreview(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      height: isSmallScreen ? 200 : 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          _capturedImage!,
          fit: BoxFit.cover,
        ),
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
                  '${_showScannedResult || _selectedImageCount > 0 ? "50" : "0"}% Complete',
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
          Row(
            children: [
              _buildStepIndicator(
                stepNumber: 1,
                stepLabel: 'Photo ID',
                isActive: !_showScannedResult && _selectedImageCount == 0,
                isCompleted: _showScannedResult || _selectedImageCount > 0,
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
                            _showScannedResult || _selectedImageCount > 0
                              ? AppTheme.successGreen
                              : AppTheme.borderLight.withOpacity(0.3),
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

  Widget _buildCompactReviewSection() {
    return _MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Captured Photo',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          if (_capturedImage != null)
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(
                  _capturedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.errorRed.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppTheme.errorRed,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.errorRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                'Detected Items',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_detectedItems.length} items',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.successGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: _detectedItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MobileFoodChip(
                  name: item.name,
                  carbs: '${item.carbsG.toStringAsFixed(1)}g',
                  icon: Icons.restaurant_rounded,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRetakeSection() {
    return _MobileActionButton(
      label: 'Retake Photo',
      icon: Icons.refresh_rounded,
      onPressed: _retakePhoto,
      isPrimary: false,
    );
  }

  Widget _buildStickyAnalyzeButton() {
    final buttonText = _currentMode == 0 
        ? 'Analyze Nutrition' 
        : 'Analyze Selected ($_selectedImageCount)';
        
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
            if (_currentMode == 0) {
              _analyzeImage();
            } else {
              _analyzeSelectedImages();
            }
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
                buttonText,
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

  Widget _buildEnhancedAnalyzingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryBlue.withOpacity(0.3),
                      ),
                    ),
                    CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                    ),
                    Icon(
                      Icons.analytics_rounded,
                      color: AppTheme.primaryBlue,
                      size: 30,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Analyzing your meal...',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 12),
              _buildProgressIndicatorWithTime(),
              const SizedBox(height: 8),
              Text(
                'This may take 10-15 seconds',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicatorWithTime() {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          LinearProgressIndicator(
            backgroundColor: AppTheme.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Processing image...',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '≈15s',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTipsSection() {
    return Column(
      children: [
        _EnhancedTipCard(
          title: 'Capture Tips',
          icon: Icons.photo_camera_rounded,
          tips: [
            'Good lighting and top-down angle improve detection.',
            'Make sure all food items are visible in the frame.',
            'Avoid glare and shadows for best results.',
          ],
        ),
        const SizedBox(height: 12),
        _EnhancedTipCard(
          title: 'Analysis Tips',
          icon: Icons.analytics_rounded,
          tips: [
            'AI estimates glucose impact based on your profile.',
            'Multiple images can improve accuracy.',
            'Review detected items before confirming.',
          ],
        ),
      ],
    );
  }

  Widget _buildGalleryBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(
            color: AppTheme.borderLight.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$_selectedImageCount image${_selectedImageCount == 1 ? '' : 's'} selected',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_selectedImageCount > 0)
            InkWell(
              onTap: () {
                setState(() {
                  _selectedImages = List<bool>.filled(_galleryImages.length, false);
                  _selectedImageCount = 0;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Clear',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Enhanced Tip Card with collapsible functionality
class _EnhancedTipCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<String> tips;

  const _EnhancedTipCard({
    required this.title,
    required this.icon,
    required this.tips,
  });

  @override
  State<_EnhancedTipCard> createState() => _EnhancedTipCardState();
}

class _EnhancedTipCardState extends State<_EnhancedTipCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return _MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.infoBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: AppTheme.infoBlue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTheme.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.infoBlue,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
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
            height: _isExpanded ? null : 0,
            child: _isExpanded
                ? Column(
                    children: [
                      const SizedBox(height: 12),
                      ...widget.tips.map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildTipItem(tip),
                      )).toList(),
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

// Mode Selector Button
class _ModeSelectorButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeSelectorButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withOpacity(0.1),
                      AppTheme.primaryBlue.withOpacity(0.05),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Gallery Image Item with selection animation
class _GalleryImageItem extends StatelessWidget {
  final XFile imageFile;
  final bool isSelected;
  final VoidCallback onTap;

  const _GalleryImageItem({
    required this.imageFile,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            FutureBuilder<File>(
              future: _getImageFile(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            ),
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue : Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<File> _getImageFile() async {
    return File(imageFile.path);
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
  final String carbs;
  final IconData icon;

  const _MobileFoodChip({
    required this.name,
    required this.carbs,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Carbs: $carbs',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}