import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glugo/services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';
import '../models/food_models.dart';

class FoodAnalysisPage extends StatefulWidget {
  const FoodAnalysisPage({super.key});

  @override
  State<FoodAnalysisPage> createState() => _FoodAnalysisPageState();
}

class _FoodAnalysisPageState extends State<FoodAnalysisPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _showEstimationDetails = false;

  // Data from API
  Map<String, dynamic>? analysisResult;
  List<FoodComponent> detectedItems = [];
  File? capturedImage;
  String mealName = 'Unknown Meal';
  
  // Calculated nutrition values from API
  double carbs = 0;
  double calories = 0;
  double protein = 0;
  double fat = 0;

  // Example profile values (replace with user settings or API later)
  double carbRatio = 10; // g per 1U
  double currentGlucose = 154; // mg/dL (could come from CGM)
  double targetGlucose = 110;
  double isf = 50; // mg/dL per 1U

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get the arguments passed from food_scan page
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null) {
      setState(() {
        analysisResult = args['analysisResult'] as Map<String, dynamic>?;
        detectedItems = (args['detectedItems'] as List<dynamic>?)
            ?.cast<FoodComponent>() ?? [];
        capturedImage = args['capturedImage'] as File?;
        
        // Extract data from analysis result
        if (analysisResult != null) {
          mealName = analysisResult!['name'] ?? 'Unknown Meal';
          carbs = (analysisResult!['total_carbs_g'] ?? 0).toDouble();
          calories = (analysisResult!['calories_estimate'] ?? 0).toDouble();
          
          // Estimate protein and fat based on carbs (rough approximation)
          // You can improve this by adding these fields to your API response
          if (calories > 0) {
            // Rough estimation: carbs provide ~4 cal/g
            double carbCalories = carbs * 4;
            double remainingCalories = calories - carbCalories;
            // Assume 30% protein, 70% fat from remaining calories
            protein = (remainingCalories * 0.3) / 4; // 4 cal/g for protein
            fat = (remainingCalories * 0.7) / 9; // 9 cal/g for fat
          } else {
            // If no calories estimate, use rough ratios
            protein = carbs * 0.4; // rough estimate
            fat = carbs * 0.3; // rough estimate
            calories = (carbs * 4) + (protein * 4) + (fat * 9);
          }
        }
      });
      
      print('Food Analysis - Loaded data:');
      print('Meal: $mealName');
      print('Carbs: ${carbs}g');
      print('Calories: ${calories}');
      print('Components: ${detectedItems.length}');
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getMealTypeFromTime() {
  final hour = DateTime.now().hour;
  
  if (hour >= 5 && hour < 11) {
    return 'breakfast';
  } else if (hour >= 11 && hour < 16) {
    return 'lunch';
  } else if (hour >= 16 && hour < 22) {
    return 'dinner';
  } else {
    return 'snack';
  }
}

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildProgressHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (capturedImage != null) 
                        _buildMealImageSection(),
                      if (capturedImage != null)
                        const SizedBox(height: 20),
                      _buildNutritionSummarySection(),
                      const SizedBox(height: 20),
                      _buildGlucoseImpactSection(),
                      const SizedBox(height: 20),
                      _buildItemsPortionsSection(),
                      const SizedBox(height: 20),
                      _buildEstimationSection(),
                      const SizedBox(height: 20),
                      _buildInsulinDoseSection(),
                      const SizedBox(height: 20),
                      _buildBottomActions(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return const SharedAppBar(
      title: 'GluGo',
      showBackButton: true,
      showConnection: true,
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(
              color: AppTheme.borderLight.withOpacity(0.3), width: 0.5),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.successGreen.withOpacity(0.1),
                      AppTheme.successGreen.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.successGreen.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  'Complete',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.successGreen,
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
              _buildCompletedStepIndicator(1, 'Photo ID'),
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.successGreen,
                        AppTheme.successGreen,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              _buildCompletedStepIndicator(2, 'Analysis'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedStepIndicator(int stepNumber, String stepLabel) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.successGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.successGreen.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          stepLabel,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.successGreen,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // NEW: Display the captured meal image
  Widget _buildMealImageSection() {
    return _AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Meal',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              capturedImage!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mealName,
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSummarySection() {
    return _AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nutrition Summary',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildNutrientCard(
                  'Carbs',
                  '${carbs.toStringAsFixed(1)}g',
                  Icons.grain_outlined,
                  AppTheme.primaryBlue,
                  highlight: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientCard(
                  'Calories',
                  '${calories.toStringAsFixed(0)}',
                  Icons.local_fire_department_outlined,
                  AppTheme.warningOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNutrientCard(
                  'Protein',
                  '${protein.toStringAsFixed(1)}g',
                  Icons.fitness_center_outlined,
                  AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientCard(
                  'Fat',
                  '${fat.toStringAsFixed(1)}g',
                  Icons.opacity_outlined,
                  AppTheme.errorRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: highlight
              ? [
                  color.withOpacity(0.08),
                  color.withOpacity(0.03),
                ]
              : [
                  color.withOpacity(0.04),
                  color.withOpacity(0.01),
                ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(highlight ? 0.3 : 0.15),
          width: highlight ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color.withOpacity(0.8)),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: highlight ? 22 : 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlucoseImpactSection() {
    double predictedRise = carbs * 3; // Rough estimate: 1g carb raises ~3 mg/dL

    return _AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart,
                size: 18,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Predicted Glucose Impact',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.infoBlue.withOpacity(0.06),
                  AppTheme.infoBlue.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.infoBlue.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Rise',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+${predictedRise.toStringAsFixed(0)} mg/dL',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.infoBlue,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.trending_up,
                  size: 32,
                  color: AppTheme.infoBlue.withOpacity(0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Based on ${carbs.toStringAsFixed(1)}g of carbohydrates',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsPortionsSection() {
    if (detectedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return _AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detected Items',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          ...detectedItems.map((item) => _buildFoodItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildFoodItemRow(FoodComponent item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.restaurant,
              size: 20,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.carbsG.toStringAsFixed(1)}g carbs',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.borderLight,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${item.quantity}',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.unit,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          _buildSmallPortionButton(Icons.add_rounded, () {}),
        ],
      ),
    );
  }

  Widget _buildSmallPortionButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppTheme.borderLight,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppTheme.primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildEstimationSection() {
    return _AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _showEstimationDetails = !_showEstimationDetails;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'How we estimate',
                    style: AppTheme.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _showEstimationDetails ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'We use advanced AI vision technology to analyze your meal image and identify individual food components. Each component\'s carbohydrates are estimated based on portion size and food type, then summed for total meal impact.',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            crossFadeState: _showEstimationDetails
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  // ✅ Automatic Insulin Dose Estimator
  Widget _buildInsulinDoseSection() {
    // Calculate insulin automatically
    double carbDose = carbs / carbRatio;
    double correctionDose = (currentGlucose - targetGlucose) / isf;
    double totalDose = carbDose + correctionDose;

    return _AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insulin Dose Estimator',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.medical_services_outlined,
                  color: AppTheme.primaryBlue, size: 22),
              const SizedBox(width: 8),
              Text(
                'Recommended Dose: ${totalDose.toStringAsFixed(1)} U',
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDoseCard('Carb Dose',
                    '${carbDose.toStringAsFixed(1)} U', AppTheme.infoBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDoseCard('Correction',
                    '${correctionDose.toStringAsFixed(1)} U', AppTheme.errorRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoseCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.05),
            color.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildBottomActions() {
  return Column(
    children: [
      SharedButton(
        text: 'Log Meal',
        onPressed: () async {
          HapticFeedback.mediumImpact();
          
          // Show loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
          
          try {
            // Get the API service instance
            final apiService = ApiService();
            await apiService.init();
            
            // Prepare nutritional info
            final nutritionalInfoMap = {
              'carbs': carbs,
              'calories': calories.round(),
              'protein': protein.round(),
              'fat': fat.round(),
            };
            
            // Create food entry
            final result = await apiService.createFoodEntry(
              foodName: mealName,
              description: detectedItems.map((item) => 
                '${item.name}: ${item.carbsG.toStringAsFixed(1)}g carbs'
              ).join(', '),
              mealType: _getMealTypeFromTime(),
              imageFile: capturedImage,
              nutritionalInfo: nutritionalInfoMap,
              totalCarbsG: carbs,
            );
            
            // Close loading dialog
            if (mounted) {
              Navigator.pop(context);
            }
            
            print('Meal logged successfully: $result');
            
            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Meal logged successfully!',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (result?['insulin_rounded'] != null)
                              Text(
                                'Recommended insulin: ${result?['insulin_rounded']}U',
                                style: const TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.successGreen,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
              
              // Navigate back after a short delay
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                Navigator.pop(context);
              }
            }
          } catch (e) {
            // Close loading dialog
            if (mounted) {
              Navigator.pop(context);
            }
            
            print('Error logging meal: $e');
            
            // Show error message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Failed to log meal: ${e.toString().replaceAll('Exception: ', '')}',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.errorRed,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        },
        icon: Icons.save_rounded,
      ),
      const SizedBox(height: 12),
      SharedButton.secondary(
        text: 'Discard Meal',
        onPressed: () {
          Navigator.pop(context);
        },
        icon: Icons.delete_outline_rounded,
      ),
    ],
  );
}
    }

// Shared Analysis Card Wrapper
class _AnalysisCard extends StatelessWidget {
  final Widget child;

  const _AnalysisCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderLight,
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}