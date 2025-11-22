import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glugo/services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';
import '../models/food_models.dart';
import 'dart:math' as math;

class FoodAnalysisPage extends StatefulWidget {
  const FoodAnalysisPage({super.key});

  @override
  State<FoodAnalysisPage> createState() => _FoodAnalysisPageState();
}

class _FoodAnalysisPageState extends State<FoodAnalysisPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _chartAnimationController;
  late AnimationController _revealAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _chartAnimation;
  late Animation<double> _revealAnimation;

  bool _showEstimationDetails = false;
  bool _showImageOverlay = true;
  
  // Chart interaction
  double _chartScale = 1.0;
  double _chartOffset = 0.0;
  final TransformationController _chartController = TransformationController();

  // Logging progress
  bool _isLogging = false;
  int _loggingStep = 0;

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

  // Example profile values
  double carbRatio = 10;
  double currentGlucose = 154;
  double targetGlucose = 110;
  double isf = 50;

// Prediction state
  bool _isPredicting = false;
  Map<String, dynamic>? _predictionResult;
  double? _predictedGlucose;
  double? _currentGlucose;
  String? _predictionRiskLevel;
  List<dynamic> _predictionTimeline = [];

// Add these methods to _FoodAnalysisPageState class

Future<void> _getGlucosePrediction() async {
  if (_isPredicting) return;
  
  setState(() {
    _isPredicting = true;
  });

  try {
    HapticFeedback.lightImpact();
    
    // Calculate insulin dose for prediction
    double carbDose = carbs / carbRatio;
    double correctionDose = (currentGlucose - targetGlucose) / isf;
    double totalDose = carbDose + correctionDose;

    final apiService = ApiService();
    await apiService.init();

    final prediction = await apiService.predictGlucoseAfterMeal(
      carbs: carbs,
      insulin: totalDose,
      model: 'ensemble',
      lookback: 240,
    );
    
    if (prediction != null && prediction['success'] == true) {
      setState(() {
        _predictionResult = prediction;
        _predictedGlucose = prediction['prediction']['glucose_mg_dl']?.toDouble();
        _currentGlucose = prediction['prediction']['current_glucose']?.toDouble();
        _predictionRiskLevel = prediction['prediction']['risk_assessment']?['level'];
        _predictionTimeline = prediction['prediction']['timeline'] ?? [];
      });
      
      // Show prediction in a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _predictionRiskLevel == 'normal' ? Icons.check_circle : Icons.warning,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Predicted glucose: ${_predictedGlucose?.toStringAsFixed(1)} mg/dL',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: _getRiskColor(_predictionRiskLevel),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    print('Prediction error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Prediction failed: ${e.toString()}'),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } finally {
    setState(() {
      _isPredicting = false;
    });
  }
}

Color _getRiskColor(String? riskLevel) {
  switch (riskLevel) {
    case 'low':
      return AppTheme.warningOrange;
    case 'high':
      return AppTheme.errorRed;
    case 'normal':
    default:
      return AppTheme.successGreen;
  }
}

String _getRiskMessage(String? riskLevel, double? glucose) {
  switch (riskLevel) {
    case 'low':
      return 'Low glucose predicted. Consider reducing insulin or having a snack.';
    case 'high':
      return 'High glucose predicted. You may need additional insulin.';
    case 'normal':
    default:
      return 'Glucose predicted to remain in target range.';
  }
}

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
    
    // Delay reveal animation for staggered effect
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _revealAnimationController.forward();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null) {
      setState(() {
        analysisResult = args['analysisResult'] as Map<String, dynamic>?;
        detectedItems = (args['detectedItems'] as List<dynamic>?)
            ?.cast<FoodComponent>() ?? [];
        capturedImage = args['capturedImage'] as File?;
        
        if (analysisResult != null) {
          mealName = analysisResult!['name'] ?? 'Unknown Meal';
          carbs = (analysisResult!['total_carbs_g'] ?? 0).toDouble();
          calories = (analysisResult!['calories_estimate'] ?? 0).toDouble();
          protein = (analysisResult!['total_protein_g'] ?? 0).toDouble();
          fat = (analysisResult!['total_fat_g'] ?? 0).toDouble();
          
        }
      });
      
      // Start chart animation
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _chartAnimationController.forward();
        }
      });
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _revealAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _chartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _chartAnimationController, curve: Curves.easeOutCubic),
    );

    _revealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _revealAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _chartAnimationController.dispose();
    _revealAnimationController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  double _calculateCalories(double carbs) {
  return carbs * 4;
}

void _adjustServing(int index, double adjustment) {
  HapticFeedback.lightImpact();
  setState(() {
    final item = detectedItems[index];
    final carbsPerUnit = item.carbsG / item.quantity;
    final newQuantity = (item.quantity + adjustment.round()).clamp(1, 10.0);
    final newCarbs = carbsPerUnit * newQuantity;
    
    final updatedItem = FoodComponent(
      name: item.name,
      quantity: newQuantity.round(),
      unit: item.unit,
      carbsG: newCarbs 
    );
    
    detectedItems[index] = updatedItem;
    
    // Recalculate total nutrition
    _recalculateTotalNutrition();
  });
}

void _editItem(int index) {
  HapticFeedback.lightImpact();
  // Show edit dialog
  _showEditItemDialog(index);
}

void _deleteItem(int index) {
  HapticFeedback.mediumImpact();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Delete Item?',
        style: AppTheme.titleMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        'Are you sure you want to remove "${detectedItems[index].name}" from your meal?',
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            HapticFeedback.lightImpact();
          },
          child: Text(
            'Cancel',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            HapticFeedback.heavyImpact();
            setState(() {
              detectedItems.removeAt(index);
              _recalculateTotalNutrition();
            });
          },
          child: Text(
            'Delete',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.errorRed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

void _addNewItem() {
  HapticFeedback.lightImpact();
  _showAddItemDialog();
}

void _recalculateTotalNutrition() {
  // Recalculate total carbs from all items
  final totalCarbs = detectedItems.fold(0.0, (sum, item) => sum + item.carbsG);
  
  setState(() {
    carbs = totalCarbs;
    protein = carbs * 0.4;
    fat = carbs * 0.3;

    calories = (carbs * 4) + (protein * 4) + (fat *9);
  });
}

  String _getMealTypeFromTime() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'breakfast';
    if (hour >= 11 && hour < 16) return 'lunch';
    if (hour >= 16 && hour < 22) return 'dinner';
    return 'snack';
  }

  void _showAddItemDialog() {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(text: '1.0');
  final TextEditingController carbsController = TextEditingController();
  String selectedUnit = 'serving';

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Add Food Item',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Food Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: selectedUnit,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: ['serving', 'cup', 'piece', 'gram', 'ounce', 'tablespoon']
                          .map((unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedUnit = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: carbsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Carbs (grams)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              HapticFeedback.lightImpact();
            },
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final quantity = int.tryParse(quantityController.text) ?? 1;
              final carbs = double.tryParse(carbsController.text) ?? 0.0;
              
              if (name.isNotEmpty && carbs > 0) {
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
                
                setState(() {
                  detectedItems.add(FoodComponent(
                    name: name,
                    quantity: quantity,
                    unit: selectedUnit,
                    carbsG: carbs,
                  ));
                  _recalculateTotalNutrition();
                });
              } else {
                HapticFeedback.heavyImpact();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Item'),
          ),
        ],
      ),
    ),
  );
}

void _showEditItemDialog(int index) {
  final item = detectedItems[index];
  final TextEditingController nameController = TextEditingController(text: item.name);
  final TextEditingController quantityController = TextEditingController(text: item.quantity.toString());
  final TextEditingController carbsController = TextEditingController(text: item.carbsG.toStringAsFixed(1));
  String selectedUnit = item.unit;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Edit Food Item',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Food Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: selectedUnit,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: ['serving', 'cup', 'piece', 'gram', 'ounce', 'tablespoon']
                          .map((unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedUnit = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: carbsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Carbs (grams)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              HapticFeedback.lightImpact();
            },
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final quantity = int.tryParse(quantityController.text) ?? 1;
              final carbs = double.tryParse(carbsController.text) ?? 0.0;
              
              if (name.isNotEmpty && carbs > 0) {
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
                
                setState(() {
                  detectedItems[index] = FoodComponent(
                    name: name,
                    quantity: quantity,
                    unit: selectedUnit,
                    carbsG: carbs,
                  );
                  _recalculateTotalNutrition();
                });
              } else {
                HapticFeedback.heavyImpact();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    ),
  );
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
                      if (capturedImage != null) _buildMealImageSection(),
                      if (capturedImage != null) const SizedBox(height: 20),
                      _buildAnimatedNutritionSummary(),
                      const SizedBox(height: 20),
                      _buildItemsPortionsSection(),
                      const SizedBox(height: 20),
                      _buildInteractiveGlucoseChart(),
                      const SizedBox(height: 20),
                      _buildInsulinDoseSection(),
                      const SizedBox(height: 20),
                      _buildEstimationSection(),
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
            color: AppTheme.borderLight.withOpacity(0.3),
            width: 0.5,
          ),
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
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildCompletedStepIndicator(1, 'Photo ID'),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.successGreen,
                            AppTheme.successGreen,
                          ],
                          stops: [0, value],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    );
                  },
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (stepNumber * 200)),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Column(
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
      ),
    );
  }

  Widget _buildMealImageSection() {
    return _AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Meal',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showImageOverlay = !_showImageOverlay;
                    });
                    HapticFeedback.lightImpact();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showImageOverlay ? Icons.visibility : Icons.visibility_off,
                          size: 14,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Overlay',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  capturedImage!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              if (_showImageOverlay && detectedItems.isNotEmpty)
                _buildImageOverlay(),
            ],
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

  Widget _buildImageOverlay() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.0),
              Colors.black.withOpacity(0.6),
            ],
          ),
        ),
        child: CustomPaint(
          painter: _FoodItemOverlayPainter(
            items: detectedItems,
            animation: _revealAnimation,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...detectedItems.take(3).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.name} • ${item.carbsG.toStringAsFixed(1)}g carbs',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedNutritionSummary() {
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
                child: _buildAnimatedNutrientCard(
                  'Carbs',
                  carbs,
                  'g',
                  Icons.grain_outlined,
                  AppTheme.primaryBlue,
                  delay: 0,
                  highlight: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnimatedNutrientCard(
                  'Calories',
                  calories,
                  '',
                  Icons.local_fire_department_outlined,
                  AppTheme.warningOrange,
                  delay: 100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAnimatedNutrientCard(
                  'Protein',
                  protein,
                  'g',
                  Icons.fitness_center_outlined,
                  AppTheme.successGreen,
                  delay: 200,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnimatedNutrientCard(
                  'Fat',
                  fat,
                  'g',
                  Icons.opacity_outlined,
                  AppTheme.errorRed,
                  delay: 300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedNutrientCard(
    String label,
    double value,
    String unit,
    IconData icon,
    Color color, {
    bool highlight = false,
    int delay = 0, 
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * animValue),
          child: Opacity(
            opacity: animValue,
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
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
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: value),
                  duration: Duration(milliseconds: 1000 + delay),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedValue, child) {
                    return Text(
                      '${animatedValue.toStringAsFixed(1)}$unit',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: highlight ? 22 : 20,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveGlucoseChart() {
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
              'Glucose Impact Timeline',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
              ),
            ),
            if (_predictedGlucose != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'AI Predicted',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.infoBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Pinch to zoom • Drag to pan',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: AnimatedBuilder(
            animation: _chartAnimation,
            builder: (context, child) {
              return InteractiveViewer(
                transformationController: _chartController,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 3.0,
                onInteractionUpdate: (details) {
                  HapticFeedback.selectionClick();
                },
                child: CustomPaint(
                  size: const Size(double.infinity, 200),
                  painter: _GlucoseChartPainter(
                    carbs: carbs,
                    currentGlucose: currentGlucose,
                    animation: _chartAnimation,
                    context: context,
                    predictedGlucose: _predictedGlucose,
                    predictionTimeline: _predictionTimeline,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildChartLegend(),
      ],
    ),
  );
}

  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLegendItem('Current', AppTheme.primaryBlue),
        _buildLegendItem('Peak', AppTheme.errorRed),
        _buildLegendItem('Return', AppTheme.successGreen),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsPortionsSection() {
  return _AnalysisCard(
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
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _addNewItem,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.successGreen.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: AppTheme.successGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add Item',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (detectedItems.isEmpty)
          _buildEmptyItemsState()
        else
          ...detectedItems.asMap().entries.map((entry) {
            return _buildFoodItemRow(entry.value, entry.key);
          }),
      ],
    ),
  );
}

Widget _buildEmptyItemsState() {
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppTheme.backgroundLight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppTheme.borderLight.withOpacity(0.5),
        width: 1,
        style: BorderStyle.none,
      ),
    ),
    child: Column(
      children: [
        Icon(
          Icons.fastfood_outlined,
          size: 48,
          color: AppTheme.textTertiary.withOpacity(0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'No items detected',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add food items manually or retake the photo',
          textAlign: TextAlign.center,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 16),
        SharedButton.secondary(
          text: 'Add First Item',
          onPressed: _addNewItem,
          icon: Icons.add_rounded,
        ),
      ],
    ),
  );
}

  Widget _buildFoodItemRow(FoodComponent item, int index) {
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: Duration(milliseconds: 400 + (index * 100)),
    curve: Curves.easeOut,
    builder: (context, value, child) {
      return Transform.translate(
        offset: Offset(20 * (1 - value), 0),
        child: Opacity(
          opacity: value,
          child: child,
        ),
      );
    },
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.borderLight.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              // Main item content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Food icon
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
                    
                    // Food details
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
                            '${item.carbsG.toStringAsFixed(1)}g carbs • ${_calculateCalories(item.carbsG).toStringAsFixed(0)} cal',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Serving controls
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.borderLight,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Decrease serving button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _adjustServing(index, -1.0),
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(8),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Icon(
                                  Icons.remove_rounded,
                                  size: 16,
                                  color: AppTheme.errorRed,
                                ),
                              ),
                            ),
                          ),
                          
                          // Serving display
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                vertical: BorderSide(
                                  color: AppTheme.borderLight,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.quantity.toStringAsFixed(1),
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  item.unit,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Increase serving button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _adjustServing(index, 1.0),
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(8),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: AppTheme.successGreen,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action buttons divider
              Container(
                height: 1,
                color: AppTheme.borderLight.withOpacity(0.3),
              ),
              
              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    // Edit button
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _editItem(index),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: AppTheme.infoBlue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.infoBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Vertical divider
                    Container(
                      width: 1,
                      height: 20,
                      color: AppTheme.borderLight.withOpacity(0.3),
                    ),
                    
                    // Delete button
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _deleteItem(index),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 14,
                                  color: AppTheme.errorRed,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Delete',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.errorRed,
                                    fontWeight: FontWeight.w500,
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
            ],
          ),
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
              HapticFeedback.lightImpact();
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

 Widget _buildInsulinDoseSection() {
  double carbDose = carbs / carbRatio;
  double correctionDose = (currentGlucose - targetGlucose) / isf;
  double totalDose = carbDose + correctionDose;

  return _AnalysisCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Insulin Dose Estimator',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
              ),
            ),
            if (_predictedGlucose != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRiskColor(_predictionRiskLevel).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getRiskColor(_predictionRiskLevel).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '${_predictedGlucose!.toStringAsFixed(0)} mg/dL',
                  style: AppTheme.bodySmall.copyWith(
                    color: _getRiskColor(_predictionRiskLevel),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withOpacity(0.1),
                AppTheme.primaryBlue.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.medical_services_outlined,
                color: AppTheme.primaryBlue,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended Dose',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: totalDose),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Text(
                          '${value.toStringAsFixed(1)} U',
                          style: AppTheme.titleLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue,
                            fontSize: 28,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (!_isPredicting)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _getGlucosePrediction,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.infoBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.infoBlue.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            size: 16,
                            color: AppTheme.infoBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Predict',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.infoBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.infoBlue),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Show prediction details if available
        if (_predictionResult != null) ...[
          _buildPredictionDetails(),
          const SizedBox(height: 12),
        ],
        
        Row(
          children: [
            Expanded(
              child: _buildDoseCard(
                'Carb Dose',
                carbDose,
                AppTheme.infoBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDoseCard(
                'Correction',
                correctionDose,
                AppTheme.errorRed,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildPredictionDetails() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _getRiskColor(_predictionRiskLevel).withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: _getRiskColor(_predictionRiskLevel).withOpacity(0.2),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _predictionRiskLevel == 'normal' 
                ? Icons.check_circle_outline
                : Icons.warning_amber_outlined,
              size: 16,
              color: _getRiskColor(_predictionRiskLevel),
            ),
            const SizedBox(width: 8),
            Text(
              '30-min Prediction',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: _getRiskColor(_predictionRiskLevel),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _getRiskMessage(_predictionRiskLevel, _predictedGlucose),
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        if (_predictionTimeline.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Timeline: ${_predictionTimeline.map((t) => '${t['minutes']}m: ${t['glucose']}').join(' → ')}',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ],
    ),
  );
}
  Widget _buildDoseCard(String label, double value, Color color) {
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
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: value),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, animValue, child) {
              return Text(
                '${animValue.toStringAsFixed(1)} U',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 18,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

 Widget _buildBottomActions() {
  if (_isLogging) {
    return _buildLoggingProgress();
  }

  return Column(
    children: [
      if (_predictedGlucose == null && !_isPredicting)
        SharedButton.secondary(
          text: 'Predict Glucose',
          onPressed: _getGlucosePrediction,
          icon: Icons.psychology_outlined,
        )
      else if (_isPredicting)
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.infoBlue),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Predicting glucose...',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      SharedButton(
        text: 'Log Meal',
        onPressed: _handleLogMeal,
        icon: Icons.save_rounded,
      ),
      const SizedBox(height: 12),
      SharedButton.secondary(
        text: 'Discard Meal',
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
        },
        icon: Icons.delete_outline_rounded,
      ),
    ],
  );
}

  Widget _buildLoggingProgress() {
    final steps = ['Uploading image', 'Saving data', 'Calculating insulin'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderLight,
          width: 0.6,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Logging your meal...',
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (index) {
            return _buildProgressStep(
              steps[index],
              index + 1,
              _loggingStep > index,
              _loggingStep == index,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProgressStep(String label, int step, bool completed, bool active) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: completed
                  ? AppTheme.successGreen
                  : active
                      ? AppTheme.primaryBlue.withOpacity(0.1)
                      : AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: completed
                    ? AppTheme.successGreen
                    : active
                        ? AppTheme.primaryBlue
                        : AppTheme.borderLight,
                width: 2,
              ),
            ),
            child: Center(
              child: completed
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : active
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryBlue,
                            ),
                          ),
                        )
                      : Text(
                          '$step',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: completed || active
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogMeal() async {
    setState(() {
      _isLogging = true;
      _loggingStep = 0;
    });

    HapticFeedback.mediumImpact();

    try {
      // Step 1: Uploading image
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() => _loggingStep = 1);
      
      final apiService = ApiService();
      await apiService.init();

      // Step 2: Saving data
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _loggingStep = 2);

      final nutritionalInfoMap = {
        'carbs': carbs.round(),
        'calories': calories.round(),
        'protein': protein.round(),
        'fat': fat.round(),
      };

      final result = await apiService.createFoodEntry(
        foodName: mealName,
        description: detectedItems
            .map((item) => '${item.name}: ${item.carbsG.toStringAsFixed(1)}g carbs')
            .join(', '),
        mealType: _getMealTypeFromTime(),
        imageFile: capturedImage,
        nutritionalInfo: nutritionalInfoMap,
        totalCarbsG: carbs,
        totalProteinG: protein,
        totalFatG: fat,
        totalCal: calories,
      );

      // Step 3: Calculating insulin
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _loggingStep = 3);
      
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        HapticFeedback.heavyImpact();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Meal logged successfully!',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (result?['insulin_rounded'] != null)
                        Text(
                          'Recommended insulin: ${result?['insulin_rounded']}U',
                          style: const TextStyle(fontSize: 12),
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

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() {
        _isLogging = false;
        _loggingStep = 0;
      });

      print('Error logging meal: $e');

      if (mounted) {
        HapticFeedback.heavyImpact();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
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

// Custom painter for glucose chart
class _GlucoseChartPainter extends CustomPainter {
  final double carbs;
  final double currentGlucose;
  final Animation<double> animation;
  final BuildContext context;
  final double? predictedGlucose;
  final List<dynamic> predictionTimeline;

  _GlucoseChartPainter({
    required this.carbs,
    required this.currentGlucose,
    required this.animation,
    required this.context,
    this.predictedGlucose,
    this.predictionTimeline = const [],
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final gridPaint = Paint()
      ..color = AppTheme.borderLight.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw grid
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Calculate glucose curve points
    final peakGlucose = currentGlucose + (carbs * 3); // Estimated peak
    final points = <Offset>[];
    final timePoints = 24; // 2 hours in 5-min intervals

    for (int i = 0; i <= timePoints; i++) {
      final x = size.width * i / timePoints;
      final t = i / timePoints;
      
      // Simulate glucose curve (rise and fall)
      double glucose;
      if (t < 0.25) {
        // Rising phase (0-30 min)
        glucose = currentGlucose + (peakGlucose - currentGlucose) * (t / 0.25);
      } else if (t < 0.5) {
        // Peak phase (30-60 min)
        glucose = peakGlucose;
      } else {
        // Falling phase (60-120 min)
        final fallProgress = (t - 0.5) / 0.5;
        glucose = peakGlucose - (peakGlucose - currentGlucose) * fallProgress;
      }

      final normalizedY = 1 - ((glucose - 70) / (peakGlucose - 70 + 50));
      final y = size.height * normalizedY.clamp(0.0, 1.0);
      
      points.add(Offset(x, y));
    }

    // Draw animated curve
    final animatedPoints = points.take((points.length * animation.value).round()).toList();
    
    if (animatedPoints.length > 1) {
      // Draw gradient under curve
      final path = Path();
      path.moveTo(animatedPoints.first.dx, size.height);
      for (final point in animatedPoints) {
        path.lineTo(point.dx, point.dy);
      }
      path.lineTo(animatedPoints.last.dx, size.height);
      path.close();

      final gradient = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [
          AppTheme.primaryBlue.withOpacity(0.2),
          AppTheme.primaryBlue.withOpacity(0.05),
        ],
      );

      canvas.drawPath(
        path,
        Paint()..shader = gradient,
      );

      // Draw line
      paint.color = AppTheme.primaryBlue;
      for (int i = 0; i < animatedPoints.length - 1; i++) {
        canvas.drawLine(animatedPoints[i], animatedPoints[i + 1], paint);
      }

      // Draw current point indicator
      if (animation.value > 0.1) {
        final currentPoint = animatedPoints.first;
        canvas.drawCircle(
          currentPoint,
          5,
          Paint()
            ..color = AppTheme.primaryBlue
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          currentPoint,
          8,
          Paint()
            ..color = AppTheme.primaryBlue.withOpacity(0.3)
            ..style = PaintingStyle.fill,
        );
      }

      // Draw peak indicator
      if (animation.value > 0.4) {
        final peakIndex = (animatedPoints.length * 0.375).round();
        if (peakIndex < animatedPoints.length) {
          final peakPoint = animatedPoints[peakIndex];
          canvas.drawCircle(
            peakPoint,
            5,
            Paint()
              ..color = AppTheme.errorRed
              ..style = PaintingStyle.fill,
          );
        }
      }
    }

        // Add prediction point if available
    if (predictedGlucose != null && animation.value > 0.8) {
      final predictedX = size.width * 0.5; // 30 minutes at position 0.5
      final normalizedPredictedY = 1 - ((predictedGlucose! - 70) / (peakGlucose - 70 + 50));
      final predictedY = size.height * normalizedPredictedY.clamp(0.0, 1.0);
      final predictedPoint = Offset(predictedX, predictedY);
      
      // Draw prediction point
      canvas.drawCircle(
        predictedPoint,
        6,
        Paint()
          ..color = AppTheme.infoBlue
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        predictedPoint,
        10,
        Paint()
          ..color = AppTheme.infoBlue.withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );
      
      // Draw prediction line from current to predicted
      final currentPoint = animatedPoints.isNotEmpty ? animatedPoints.last : Offset(0, size.height * 0.5);
      canvas.drawLine(
        currentPoint,
        predictedPoint,
        Paint()
          ..color = AppTheme.infoBlue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }


    // Draw time labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final timeLabels = ['0', '30m', '1h', '1.5h', '2h'];
    for (int i = 0; i < timeLabels.length; i++) {
      final x = size.width * i / (timeLabels.length - 1);
      textPainter.text = TextSpan(
        text: timeLabels[i],
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.textSecondary,
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height + 8),
      );
    }
  }

  @override
  bool shouldRepaint(_GlucoseChartPainter oldDelegate) {
    return oldDelegate.carbs != carbs ||
        oldDelegate.currentGlucose != currentGlucose ||
        oldDelegate.predictedGlucose != predictedGlucose;
  }
}

// Custom painter for food item overlays
class _FoodItemOverlayPainter extends CustomPainter {
  final List<FoodComponent> items;
  final Animation<double> animation;

  _FoodItemOverlayPainter({
    required this.items,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppTheme.primaryBlue.withOpacity(animation.value);

    final random = math.Random(42); // Fixed seed for consistency

    // Draw bounding boxes for detected items
    for (int i = 0; i < math.min(items.length, 3); i++) {
      final item = items[i];
      
      // Generate pseudo-random positions
      final left = size.width * (0.1 + random.nextDouble() * 0.3);
      final top = size.height * (0.1 + random.nextDouble() * 0.5);
      final width = size.width * (0.3 + random.nextDouble() * 0.2);
      final height = size.height * (0.2 + random.nextDouble() * 0.2);

      final rect = Rect.fromLTWH(left, top, width, height);
      
      // Draw rounded rectangle
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rrect, paint);

      // Draw corner accents
      final accentPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = AppTheme.primaryBlue.withOpacity(animation.value * 0.8);

      final cornerSize = 8.0;
      // Top-left corner
      canvas.drawCircle(
        Offset(left, top),
        cornerSize * animation.value,
        accentPaint,
      );
      // Top-right corner
      canvas.drawCircle(
        Offset(left + width, top),
        cornerSize * animation.value,
        accentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_FoodItemOverlayPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}