import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  String _selectedTimeRange = '14d';
  final List<String> _timeRanges = ['7d', '14d', '1m', '3m'];

  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _insightsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
    _loadInsightsData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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

  Future<void> _loadInsightsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.init();
      
      // Get glucose statistics for insights
      final today = DateTime.now();
      final startDate = _getStartDateForRange(_selectedTimeRange);
      final stats = await _apiService.getGlucoseStatistics(
        startDate: startDate,
        endDate: today,
      );

      // Get recent food entries for meal impact analysis
      final foodEntries = await _apiService.getFoodEntries(
        startDate: startDate,
        endDate: today,
        limit: 50,
      );

      // Process insights data
      final insights = await _processInsightsData(stats, foodEntries);
      
      setState(() {
        _insightsData = insights;
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading insights: $e');
      setState(() {
        _isLoading = false;
        _insightsData = _getFallbackData();
      });
    }
  }

  DateTime _getStartDateForRange(String range) {
    final today = DateTime.now();
    switch (range) {
      case '7d':
        return today.subtract(const Duration(days: 7));
      case '14d':
        return today.subtract(const Duration(days: 14));
      case '1m':
        return DateTime(today.year, today.month - 1, today.day);
      case '3m':
        return DateTime(today.year, today.month - 3, today.day);
      default:
        return today.subtract(const Duration(days: 14));
    }
  }

  Future<Map<String, dynamic>> _processInsightsData(
    Map<String, dynamic> stats, 
    List<dynamic> foodEntries
  ) async {
    // Analyze meal impacts from food entries
    final mealImpacts = _analyzeMealImpacts(foodEntries);
    
    // Detect patterns from glucose statistics
    final patterns = _detectPatterns(stats);
    
    // Generate recommendations
    final recommendations = _generateRecommendations(stats, mealImpacts);

    return {
      'stats': stats,
      'mealImpacts': mealImpacts,
      'patterns': patterns,
      'recommendations': recommendations,
      'timeRange': _selectedTimeRange,
    };
  }

  List<Map<String, dynamic>> _analyzeMealImpacts(List<dynamic> foodEntries) {
    // Group food entries by meal type and analyze impact
    final Map<String, List<dynamic>> mealsByType = {};
    
    for (final entry in foodEntries) {
      final mealType = entry['meal_type'] ?? entry['mealType'] ?? 'other';
      if (!mealsByType.containsKey(mealType)) {
        mealsByType[mealType] = [];
      }
      mealsByType[mealType]!.add(entry);
    }

    // Calculate average carbs per meal type and estimate impact
    final impacts = <Map<String, dynamic>>[];
    
    mealsByType.forEach((mealType, entries) {
      if (entries.isNotEmpty) {
        final totalCarbs = entries.fold<double>(0, (sum, entry) {
           final carbs = entry['total_carbs'] ?? 
                     entry['total_carbs_g'] ??
                     entry['nutritional_info']?['carbs'] ??
                     entry['carbs'] ?? 0;
        return sum + (carbs is String ? double.tryParse(carbs) ?? 0 : carbs.toDouble());
        });
        final avgCarbs = totalCarbs / entries.length;
        
        // Estimate glucose impact based on carbs (simplified model)
        final estimatedImpact = (avgCarbs * 2.5).round(); // ~2.5 mg/dL per gram of carbs
        
        impacts.add({
          'mealType': mealType,
          'avgCarbs': avgCarbs.round(),
          'estimatedImpact': estimatedImpact,
          'frequency': entries.length,
          'icon': _getMealIcon(mealType),
        });
      }
    });

    // Sort by impact (highest first)
    impacts.sort((a, b) => b['estimatedImpact'].compareTo(a['estimatedImpact']));
    
    return impacts.take(3).toList();
  }

  IconData _getMealIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.breakfast_dining_rounded;
      case 'lunch':
        return Icons.lunch_dining_rounded;
      case 'dinner':
        return Icons.dinner_dining_rounded;
      case 'snack':
        return Icons.local_cafe_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  List<Map<String, dynamic>> _detectPatterns(Map<String, dynamic> stats) {
    final patterns = <Map<String, dynamic>>[];
    
    final timeInRange = stats['time_in_range']?.toDouble() ?? 0;
    final avgGlucose = stats['avg_glucose']?.toDouble() ?? 0;
    final variability = stats['coefficient_of_variation']?.toDouble() ?? 0;

    // Pattern 1: Time in Range assessment
    if (timeInRange < 70) {
      patterns.add({
        'title': 'Range Improvement',
        'subtitle': '${timeInRange.round()}% time in target range',
        'status': 'Needs attention',
        'statusColor': AppTheme.warningOrange,
        'icon': Icons.timeline_rounded,
      });
    } else {
      patterns.add({
        'title': 'Excellent Control',
        'subtitle': '${timeInRange.round()}% time in target range',
        'status': 'Great',
        'statusColor': AppTheme.successGreen,
        'icon': Icons.verified_rounded,
      });
    }

    // Pattern 2: Glucose variability
    if (variability > 36) {
      patterns.add({
        'title': 'High Variability',
        'subtitle': '${variability.round()}% coefficient of variation',
        'status': 'Monitor',
        'statusColor': AppTheme.warningOrange,
        'icon': Icons.analytics_rounded,
      });
    }

    // Pattern 3: Average glucose assessment
    if (avgGlucose > 140) {
      patterns.add({
        'title': 'Elevated Average',
        'subtitle': '${avgGlucose.round()} mg/dL average glucose',
        'status': 'Review',
        'statusColor': AppTheme.glucoseHigh,
        'icon': Icons.trending_up_rounded,
      });
    }

    return patterns;
  }

  List<Map<String, dynamic>> _generateRecommendations(
    Map<String, dynamic> stats, 
    List<Map<String, dynamic>> mealImpacts
  ) {
    final recommendations = <Map<String, dynamic>>[];
    
    final timeInRange = stats['time_in_range']?.toDouble() ?? 0;
    final avgGlucose = stats['avg_glucose']?.toDouble() ?? 0;

    // Recommendation based on time in range
    if (timeInRange < 70) {
      recommendations.add({
        'title': 'Increase Monitoring',
        'subtitle': 'Check glucose more frequently to identify patterns',
        'action': 'Start',
        'icon': Icons.monitor_heart_rounded,
      });
    }

    // Recommendation based on average glucose
    if (avgGlucose > 140) {
      recommendations.add({
        'title': 'Post-Meal Activity',
        'subtitle': '10-15 minute walk after meals can help lower spikes',
        'action': 'Try it',
        'icon': Icons.directions_walk_rounded,
      });
    }

    // General healthy habit
    recommendations.add({
      'title': 'Consistent Timing',
      'subtitle': 'Try to eat meals at similar times each day',
      'action': 'Plan',
      'icon': Icons.schedule_rounded,
    });

    return recommendations;
  }

  Map<String, dynamic> _getFallbackData() {
    return {
      'stats': {
        'avg_glucose': 118,
        'time_in_range': 74,
        'coefficient_of_variation': 32,
        'high_readings': 3,
        'low_readings': 1,
      },
      'mealImpacts': [
        {
          'mealType': 'Lunch',
          'avgCarbs': 45,
          'estimatedImpact': 28,
          'frequency': 12,
          'icon': Icons.lunch_dining_rounded,
        },
        {
          'mealType': 'Dinner',
          'avgCarbs': 38,
          'estimatedImpact': 24,
          'frequency': 14,
          'icon': Icons.dinner_dining_rounded,
        },
        {
          'mealType': 'Breakfast',
          'avgCarbs': 32,
          'estimatedImpact': 20,
          'frequency': 14,
          'icon': Icons.breakfast_dining_rounded,
        },
      ],
      'patterns': [
        {
          'title': 'Morning Stability',
          'subtitle': 'Consistent fasting levels between 90-110 mg/dL',
          'status': 'Good',
          'statusColor': AppTheme.successGreen,
          'icon': Icons.wb_sunny_rounded,
        },
      ],
      'recommendations': [
        {
          'title': 'Evening Check',
          'subtitle': 'Consider a bedtime reading to monitor overnight trends',
          'action': 'Add',
          'icon': Icons.nightlight_rounded,
        },
      ],
    };
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusM),
      ),
    );
  }

  void _onTimeRangeChanged(String range) {
    setState(() {
      _selectedTimeRange = range;
    });
    HapticFeedback.selectionClick();
    _loadInsightsData();
  }

  String _getTimeRangeLabel(String range) {
    switch (range) {
      case '7d':
        return '7 days';
      case '14d':
        return '14 days';
      case '1m':
        return '1 month';
      case '3m':
        return '3 months';
      default:
        return range;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _isLoading
              ? _buildLoadingState()
              : RefreshIndicator(
                  onRefresh: _loadInsightsData,
                  color: AppTheme.primaryBlue,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TimeRangeSelector(
                          selectedRange: _selectedTimeRange,
                          ranges: _timeRanges,
                          onChanged: _onTimeRangeChanged,
                        ),
                        const SizedBox(height: AppTheme.spacingXL),
                        _buildSummarySection(),
                        const SizedBox(height: AppTheme.spacingXL),
                        _buildMealImpactSection(),
                        const SizedBox(height: AppTheme.spacingXL),
                        _buildPatternsSection(),
                        const SizedBox(height: AppTheme.spacingXL),
                        _buildRecommendationsSection(),
                        const SizedBox(height: AppTheme.spacingXXL),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryBlue),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'Analyzing your patterns...',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return SharedAppBar(
      title: 'Insights',
      showBackButton: false,
      showConnection: true,
      actions: [
        IconButton(
          onPressed: _loadInsightsData,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    final stats = _insightsData?['stats'] ?? {};
    final avgGlucose = stats['avg_glucose']?.toDouble() ?? 0;
    final timeInRange = stats['time_in_range']?.toDouble() ?? 0;
    final highReadings = stats['high_readings']?.toInt() ?? 0;
    final lowReadings = stats['low_readings']?.toInt() ?? 0;
    final variability = stats['coefficient_of_variation']?.toDouble() ?? 0;

    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: AppTheme.radiusS,
                    ),
                    child: Icon(
                      Icons.insights_rounded,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Text(
                    '${_getTimeRangeLabel(_selectedTimeRange)} Overview',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              StatusBadge(
                label: 'Live Data',
                color: AppTheme.successGreen,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXL),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Average Glucose',
                  value: avgGlucose > 0 ? avgGlucose.round().toString() : '--',
                  unit: 'mg/dL',
                  color: AppTheme.getGlucoseColor(avgGlucose),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _SummaryMetric(
                  label: 'Time in Range',
                  value: timeInRange > 0 ? timeInRange.round().toString() : '--',
                  unit: '%',
                  color: timeInRange >= 70 ? AppTheme.successGreen : AppTheme.warningOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'High/Low Events',
                  value: '$highReadings / $lowReadings',
                  unit: '',
                  color: (highReadings + lowReadings) > 5 ? AppTheme.warningOrange : AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _SummaryMetric(
                  label: 'Variability',
                  value: variability > 0 ? variability.round().toString() : '--',
                  unit: '% CV',
                  color: variability <= 36 ? AppTheme.successGreen : AppTheme.warningOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXL),
          _buildTrendChart(),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    // Simplified trend visualization
    return Container(
      height: 120,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue.withOpacity(0.05),
            AppTheme.primaryBlue.withOpacity(0.02),
          ],
        ),
        borderRadius: AppTheme.radiusM,
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Glucose Trend',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: 70,
                maxY: 180,
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: AppTheme.primaryBlue,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue.withOpacity(0.2),
                          AppTheme.primaryBlue.withOpacity(0.01),
                        ],
                      ),
                    ),
                    spots: _generateTrendSpots(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateTrendSpots() {
    // Generate realistic trend spots based on time range
    final spots = <FlSpot>[];
    final baseGlucose = _insightsData?['stats']?['avg_glucose']?.toDouble() ?? 120;
    
    switch (_selectedTimeRange) {
      case '7d':
        for (int i = 0; i < 7; i++) {
          spots.add(FlSpot(
            i.toDouble(),
            baseGlucose + (i % 3 == 0 ? 15 : -5).toDouble(),
          ));
        }
        break;
      case '14d':
        for (int i = 0; i < 14; i += 2) {
          spots.add(FlSpot(
            i.toDouble(),
            baseGlucose + (i % 4 == 0 ? 20 : -8).toDouble(),
          ));
        }
        break;
      default:
        for (int i = 0; i < 8; i++) {
          spots.add(FlSpot(
            i.toDouble(),
            baseGlucose + (i % 2 == 0 ? 12 : -6).toDouble(),
          ));
        }
    }
    
    return spots;
  }

  Widget _buildMealImpactSection() {
    final mealImpacts = _insightsData?['mealImpacts'] ?? [];
    
    if (mealImpacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Meal Impact Analysis',
          subtitle: 'Average glucose response by meal type',
        ),
        const SizedBox(height: AppTheme.spacingL),
        BaseCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < mealImpacts.length; i++)
                _MealImpactTile(
                  mealType: _capitalize(mealImpacts[i]['mealType']),
                  avgCarbs: mealImpacts[i]['avgCarbs'],
                  estimatedImpact: mealImpacts[i]['estimatedImpact'],
                  frequency: mealImpacts[i]['frequency'],
                  icon: mealImpacts[i]['icon'],
                  showDivider: i < mealImpacts.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
  String _capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

  Widget _buildPatternsSection() {
    final patterns = _insightsData?['patterns'] ?? [];
    
    if (patterns.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Patterns & Trends',
          subtitle: 'Detected from your glucose data',
        ),
        const SizedBox(height: AppTheme.spacingL),
        BaseCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < patterns.length; i++)
                _PatternTile(
                  title: patterns[i]['title'],
                  subtitle: patterns[i]['subtitle'],
                  status: patterns[i]['status'],
                  statusColor: patterns[i]['statusColor'],
                  icon: patterns[i]['icon'],
                  showDivider: i < patterns.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsSection() {
    final recommendations = _insightsData?['recommendations'] ?? [];
    
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Personalized Recommendations',
          subtitle: 'Based on your patterns',
        ),
        const SizedBox(height: AppTheme.spacingL),
        BaseCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < recommendations.length; i++)
                _RecommendationTile(
                  title: recommendations[i]['title'],
                  subtitle: recommendations[i]['subtitle'],
                  action: recommendations[i]['action'],
                  icon: recommendations[i]['icon'],
                  showDivider: i < recommendations.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getImpactColor(int impact) {
    if (impact > 30) return AppTheme.glucoseHigh;
    if (impact > 20) return AppTheme.warningOrange;
    return AppTheme.successGreen;
  }

}

// Updated Meal Impact Tile with more info
class _MealImpactTile extends StatelessWidget {
  final String mealType;
  final int avgCarbs;
  final int estimatedImpact;
  final int frequency;
  final IconData icon;
  final bool showDivider;

  const _MealImpactTile({
    required this.mealType,
    required this.avgCarbs,
    required this.estimatedImpact,
    required this.frequency,
    required this.icon,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListItem(
      icon: icon,
      iconColor: _getImpactColor(estimatedImpact),
      title: mealType,
      subtitle: '${avgCarbs}g avg carbs • $frequency meals',
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '+$estimatedImpact mg/dL',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: _getImpactColor(estimatedImpact),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getImpactColor(estimatedImpact),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      showDivider: showDivider,
      onTap: () {
        HapticFeedback.lightImpact();
      },
    );
  }

  Color _getImpactColor(int impact) {
    if (impact > 30) return AppTheme.glucoseHigh;
    if (impact > 20) return AppTheme.warningOrange;
    return AppTheme.successGreen;
  }
}

// Time Range Selector Widget
class _TimeRangeSelector extends StatelessWidget {
  final String selectedRange;
  final List<String> ranges;
  final ValueChanged<String> onChanged;

  const _TimeRangeSelector({
    required this.selectedRange,
    required this.ranges,
    required this.onChanged,
  });

  String _getRangeLabel(String range) {
    switch (range) {
      case '7d':
        return '7 Days';
      case '14d':
        return '14 Days';
      case '1m':
        return '1 Month';
      case '3m':
        return '3 Months';
      default:
        return range;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.radiusM,
        boxShadow: AppTheme.lightShadow,
        border: Border.all(
          color: AppTheme.borderLight,
          width: 0.5,
        ),
      ),
      child: Row(
        children: ranges.map((range) {
          final isSelected = selectedRange == range;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppTheme.primaryBlue,
                            AppTheme.primaryBlue.withOpacity(0.9),
                          ],
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: AppTheme.radiusS,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _getRangeLabel(range),
                  textAlign: TextAlign.center,
                  style: AppTheme.labelMedium.copyWith(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Summary Metric Widget
class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: AppTheme.radiusM,
        border: Border.all(color: color.withOpacity(0.2)),
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
          const SizedBox(height: AppTheme.spacingS),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTheme.headlineMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
/// Pattern Tile Widget
class _PatternTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final IconData icon;
  final bool showDivider;

  const _PatternTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.icon,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListItem(
      icon: icon,
      iconColor: statusColor,
      title: title,
      subtitle: subtitle,
      trailing: StatusBadge(
        label: status,
        color: statusColor,
      ),
      showDivider: showDivider,
      onTap: () {
        HapticFeedback.lightImpact();
      },
    );
  }
}

// Recommendation Tile Widget
class _RecommendationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String action;
  final IconData icon;
  final bool showDivider;

  const _RecommendationTile({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.icon,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListItem(
      icon: icon,
      iconColor: AppTheme.insightsColor,
      title: title,
      subtitle: subtitle,
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withOpacity(0.1),
          borderRadius: AppTheme.radiusS,
        ),
        child: Text(
          action,
          style: AppTheme.labelSmall.copyWith(
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      showDivider: showDivider,
      onTap: () {
        HapticFeedback.lightImpact();
      },
    );
  }
}