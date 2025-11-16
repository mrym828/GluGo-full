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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
    _apiService.init(); 
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
    _showSnackBar('Showing data for ${_getTimeRangeLabel(range)}');
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

  Map<String, dynamic> _getDataForTimeRange() {
    // This simulates different data based on time range
    // In a real app, you'd fetch this from your backend/database
    switch (_selectedTimeRange) {
      case '7d':
        return {
          'avgGlucose': '115',
          'timeInRange': '82',
          'highLowEvents': '1 / 0',
          'gmi': '5.9',
          'chartSpots': const [
            FlSpot(0, 125),
            FlSpot(1, 130),
            FlSpot(2, 115),
            FlSpot(3, 140),
            FlSpot(4, 120),
            FlSpot(5, 110),
            FlSpot(6, 115),
          ],
        };
      case '14d':
        return {
          'avgGlucose': '118',
          'timeInRange': '74',
          'highLowEvents': '3 / 1',
          'gmi': '6.1',
          'chartSpots': const [
            FlSpot(0, 120),
            FlSpot(2, 135),
            FlSpot(4, 110),
            FlSpot(6, 145),
            FlSpot(8, 125),
            FlSpot(10, 115),
            FlSpot(12, 130),
            FlSpot(14, 118),
          ],
        };
      case '1m':
        return {
          'avgGlucose': '122',
          'timeInRange': '68',
          'highLowEvents': '8 / 3',
          'gmi': '6.3',
          'chartSpots': const [
            FlSpot(0, 125),
            FlSpot(4, 140),
            FlSpot(8, 115),
            FlSpot(12, 150),
            FlSpot(16, 130),
            FlSpot(20, 120),
            FlSpot(24, 135),
            FlSpot(28, 122),
          ],
        };
      case '3m':
        return {
          'avgGlucose': '120',
          'timeInRange': '71',
          'highLowEvents': '18 / 7',
          'gmi': '6.2',
          'chartSpots': const [
            FlSpot(0, 122),
            FlSpot(10, 130),
            FlSpot(20, 118),
            FlSpot(30, 145),
            FlSpot(40, 125),
            FlSpot(50, 115),
            FlSpot(60, 128),
            FlSpot(70, 135),
            FlSpot(80, 120),
            FlSpot(90, 120),
          ],
        };
      default:
        return _getDataForTimeRange();
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
                _buildDataSourceInfo(),
                const SizedBox(height: AppTheme.spacingXL),
                _build14DaySummary(),
                const SizedBox(height: AppTheme.spacingXL),
                _buildMealImpact(),
                const SizedBox(height: AppTheme.spacingXL),
                _buildPatternsAlerts(),
                const SizedBox(height: AppTheme.spacingXL),
                _buildRecommendations(),
                const SizedBox(height: AppTheme.spacingXXL),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return SharedAppBar(
      title: 'GluGo',
      showBackButton: false,
      showConnection: true,
      actions: [
        IconButton(
          onPressed: () => _showSnackBar('Export insights coming soon'),
          icon: const Icon(Icons.file_download_outlined, color: Colors.white),
          tooltip: 'Export',
        ),
      ],
    );
  }

  Widget _build14DaySummary() {
    final data = _getDataForTimeRange();
    final timeRangeLabel = _getTimeRangeLabel(_selectedTimeRange);
    
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
                      Icons.calendar_month_rounded,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Text(
                    '$timeRangeLabel Summary',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              StatusBadge(
                label: 'Updated today',
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXL),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Average Glucose',
                  value: data['avgGlucose'],
                  unit: 'mg/dL',
                  color: AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _SummaryMetric(
                  label: 'Time in Range',
                  value: data['timeInRange'],
                  unit: '%',
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'High / Low Events',
                  value: data['highLowEvents'],
                  unit: '',
                  color: AppTheme.warningOrange,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _SummaryMetric(
                  label: 'GMI',
                  value: data['gmi'],
                  unit: '%',
                  color: AppTheme.insightsColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXL),
          Container(
            height: 140,
            padding: const EdgeInsets.all(AppTheme.spacingL),
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
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: 80,
                maxY: 160,
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
                    spots: data['chartSpots'] as List<FlSpot>,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealImpact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Meal Impact',
          subtitle: 'Predicted glucose response',
        ),
        const SizedBox(height: AppTheme.spacingL),
        BaseCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MealImpactTile(
                meal: 'Chicken Shawarma',
                impact: '+24 mg/dL',
                timeRange: '60-90m',
                color: AppTheme.warningOrange,
                icon: Icons.restaurant_rounded,
              ),
              _MealImpactTile(
                meal: 'Sweet Karak Tea',
                impact: '+32 mg/dL',
                timeRange: '30-45m',
                color: AppTheme.glucoseHigh,
                icon: Icons.local_cafe_rounded,
              ),
              _MealImpactTile(
                meal: 'Fattoush',
                impact: '+10 mg/dL',
                timeRange: '45-60m',
                color: AppTheme.successGreen,
                icon: Icons.eco_rounded,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPatternsAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Patterns & Alerts',
          subtitle: 'Last 14 days',
        ),
        const SizedBox(height: AppTheme.spacingL),
        BaseCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _PatternTile(
                title: 'Morning highs',
                subtitle: '3 days between 7-9am above range',
                status: 'Review',
                statusColor: AppTheme.warningOrange,
                icon: Icons.wb_sunny_rounded,
              ),
              _PatternTile(
                title: 'Stable nights',
                subtitle: '87% time in range 12-6am',
                status: 'Good',
                statusColor: AppTheme.successGreen,
                icon: Icons.nightlight_rounded,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recommendations',
          subtitle: 'Personalized for you',
        ),
        const SizedBox(height: AppTheme.spacingL),
        BaseCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _RecommendationTile(
                title: 'Pre-breakfast check',
                subtitle: 'Add a quick 10g protein snack if fasting >12h',
                action: 'Try it',
                icon: Icons.breakfast_dining_rounded,
              ),
              _RecommendationTile(
                title: 'Post-meal walk',
                subtitle: '10-15 min after higher-carb meals',
                action: 'Start',
                icon: Icons.directions_walk_rounded,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
  // Add after time range selector
Widget _buildDataSourceInfo() {
  return FutureBuilder<Map<String, dynamic>>(
    future: _apiService.getLibreStatus(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      
      final isConnected = snapshot.data?['is_connected'] ?? false;
      final totalRecords = snapshot.data?['total_records'] ?? 0;
      
      if (!isConnected) {
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingL,
            vertical: AppTheme.spacingM,
          ),
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: AppTheme.infoBlue.withOpacity(0.1),
            borderRadius: AppTheme.radiusM,
            border: Border.all(color: AppTheme.infoBlue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.infoBlue, size: 20),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  'Connect LibreView for more accurate insights',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.infoBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/device'),
                child: Text('Connect', style: TextStyle(color: AppTheme.infoBlue)),
              ),
            ],
          ),
        );
      }
      
      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingL,
          vertical: AppTheme.spacingM,
        ),
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withOpacity(0.1),
          borderRadius: AppTheme.radiusM,
          border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: AppTheme.successGreen, size: 20),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LibreView Connected',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$totalRecords readings synced',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
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

// Meal Impact Tile Widget
class _MealImpactTile extends StatelessWidget {
  final String meal;
  final String impact;
  final String timeRange;
  final Color color;
  final IconData icon;
  final bool showDivider;

  const _MealImpactTile({
    required this.meal,
    required this.impact,
    required this.timeRange,
    required this.color,
    required this.icon,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListItem(
      icon: icon,
      iconColor: color,
      title: meal,
      subtitle: '$impact • $timeRange',
      trailing: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      showDivider: showDivider,
      onTap: () {
        HapticFeedback.lightImpact();
      },
    );
  }
}

// Pattern Tile Widget
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