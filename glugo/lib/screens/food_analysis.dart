import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';

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

  // Detected meal values (mock for now, could be parsed dynamically later)
  double carbs = 68; // from Nutrition Summary
  double calories = 620;
  double protein = 28;
  double fat = 22;

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
                      _buildNutritionSummarySection(),
                      const SizedBox(height: 20),
                      _buildGlucoseImpactSection(),
                      const SizedBox(height: 20),
                      _buildItemsPortionsSection(),
                      const SizedBox(height: 20),
                      _buildEstimationSection(),
                      const SizedBox(height: 20),
                      _buildInsulinDoseSection(), // NEW automatic insulin calculator
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
                    'Today',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.access_time_outlined,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '1:15 PM',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildNutritionMetric(
                  'Calories',
                  calories.toStringAsFixed(0),
                  'kcal',
                  'Moderate',
                  AppTheme.warningOrange,
                  Icons.local_fire_department_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutritionMetric(
                  'Carbs',
                  carbs.toStringAsFixed(0),
                  'g',
                  '44%',
                  AppTheme.infoBlue,
                  Icons.grain_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNutritionMetric(
                  'Protein',
                  protein.toStringAsFixed(0),
                  'g',
                  '18%',
                  AppTheme.successGreen,
                  Icons.fitness_center_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutritionMetric(
                  'Fat',
                  fat.toStringAsFixed(0),
                  'g',
                  '38%',
                  AppTheme.errorRed,
                  Icons.opacity_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionMetric(
    String label,
    String value,
    String unit,
    String percentage,
    Color color,
    IconData icon,
  ) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  icon,
                  size: 12,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 22,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                percentage,
                style: AppTheme.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlucoseImpactSection() {
    return _AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Predicted Glucose Impact',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.backgroundLight,
                  AppTheme.backgroundLight.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.borderLight,
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(
                'Glucose curve placeholder',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildGlucoseMetric(
                  'Rise (30-60 min)',
                  '+28',
                  'mg/dL',
                  AppTheme.warningOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGlucoseMetric(
                  'Peak',
                  '154',
                  'mg/dL',
                  AppTheme.errorRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGlucoseMetric(
                  'Return to baseline',
                  '~2',
                  'hrs',
                  AppTheme.infoBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlucoseMetric(
      String label, String value, String unit, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsPortionsSection() {
    return _AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items & Portions',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          _buildFoodItem(
            'Chicken Biryani',
            'Est. 420 kcal • 58g carbs',
            '1',
            'cup',
            'assets/images/biryani_placeholder.png',
          ),
          const SizedBox(height: 12),
          _buildFoodItem(
            'Cucumber Salad',
            'Est. 200 kcal • 10g carbs',
            '1',
            'small bowl',
            'assets/images/salad_placeholder.png',
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(
    String name,
    String nutrition,
    String quantity,
    String unit,
    String imagePath,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue.withOpacity(0.1),
                AppTheme.primaryBlue.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Icon(
            name.contains('Biryani')
                ? Icons.restaurant_rounded
                : Icons.eco_rounded,
            color: AppTheme.primaryBlue.withOpacity(0.7),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                nutrition,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildSmallPortionButton(Icons.remove_rounded, () {}),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  quantity,
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                Text(
                  unit,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            _buildSmallPortionButton(Icons.add_rounded, () {}),
          ],
        ),
      ],
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
                'We use a combination of portion size, food type, and your personal glucose response history to estimate the impact of meals on your glucose.',
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
    return Row(
      children: [
        SharedButton(
          text: 'Log Meal',
          onPressed: () {
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Meal logged successfully!'),
                backgroundColor: AppTheme.successGreen,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
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
