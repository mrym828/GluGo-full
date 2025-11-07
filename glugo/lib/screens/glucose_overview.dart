import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';
import '../models/glucose_reading.dart';
import '../services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'log_reading_page.dart';

class GlucoseOverviewScreen extends StatefulWidget {
  const GlucoseOverviewScreen({super.key});

  @override
  State<GlucoseOverviewScreen> createState() => _GlucoseOverviewScreenState();
}

class _GlucoseOverviewScreenState extends State<GlucoseOverviewScreen> 
    with TickerProviderStateMixin {
  String _selectedTimeRange = '24h';
  int _selectedTabIndex = 0;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _timeRanges = ['24h', '7d', '30d', '90d'];
  final List<String> _tabTitles = ['Overview', 'Trends', 'Statistics'];

  // API Service
  final ApiService _apiService = ApiService();
  
  // Data state
  List<GlucoseReading> _glucoseReadings = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadGlucoseData();
    _animationController.forward();
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

  // Load glucose data from API with time range filtering
  Future<void> _loadGlucoseData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.init();
      
      // Check if user is logged in
      if (!_apiService.isLoggedIn) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      // Calculate date range based on selection
      final now = DateTime.now();
      DateTime startDate;
      
      switch (_selectedTimeRange) {
        case '7d':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case '90d':
          startDate = now.subtract(const Duration(days: 90));
          break;
        case '24h':
        default:
          startDate = now.subtract(const Duration(days: 1));
          break;
      }

      // Fetch glucose records with date filtering
      final data = await _apiService.getGlucoseRecords(
        startDate: startDate,
        endDate: now,
        limit: 100,
      );
      
      if (mounted) {
        setState(() {
          _glucoseReadings = (data as List)
              .map((json) => GlucoseReading.fromJson(json))
              .where((reading) => reading.value > 0) // Filter invalid readings
              .toList();
          _glucoseReadings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _isLoading = false;
        });
      }
      
      if (_glucoseReadings.isEmpty && mounted) {
        _showSnackBar('No glucose readings found in selected time range.', 
            isSuccess: false);
      }
    } catch (e) {
      print('Error loading glucose data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load glucose data: ${e.toString()}';
        });
        _showSnackBar('Error loading glucose data', isSuccess: false);
      }
      
      // Fallback to sample data for UI testing
      _generateSampleData();
    }
  }

  // Sync data from Libre
  Future<void> _syncLibreData() async {
    try {
      _showSnackBar('Syncing glucose data from Libre...', isSuccess: true);
      
      await _apiService.libreSyncNow();
      
      // Wait a moment for sync to process
      await Future.delayed(const Duration(seconds: 2));
      
      // Reload data
      await _loadGlucoseData();
      
      _showSnackBar('Sync completed successfully!', isSuccess: true);
    } catch (e) {
      _showSnackBar('Failed to sync: ${e.toString()}', isSuccess: false);
    }
  }

  void _generateSampleData() {
    final now = DateTime.now();
    _glucoseReadings = [
      GlucoseReading(
        id: '1',
        timestamp: now.subtract(const Duration(minutes: 15)),
        value: 112,
      ),
      GlucoseReading(
        id: '2',
        timestamp: now.subtract(const Duration(hours: 1)),
        value: 126,
      ),
      GlucoseReading(
        id: '3',
        timestamp: now.subtract(const Duration(hours: 2)),
        value: 98,
      ),
      GlucoseReading(
        id: '4',
        timestamp: now.subtract(const Duration(hours: 3)),
        value: 145,
      ),
      GlucoseReading(
        id: '5',
        timestamp: now.subtract(const Duration(hours: 4)),
        value: 189,
      ),
    ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isSuccess = true}) {
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
                  fontWeight: FontWeight.w500,
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

  void _navigateToLogReading() async {
    HapticFeedback.lightImpact();
    try {
      final result = await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LogReadingPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeInOut)),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      
      if (result == true) {
        _showSnackBar('Glucose reading logged successfully!');
        _loadGlucoseData(); // Reload data from API
      }
    } catch (e) {
      _showSnackBar('Failed to navigate to log reading page', isSuccess: false);
    }
  }

  void _onTimeRangeChanged(String range) {
    setState(() => _selectedTimeRange = range);
    HapticFeedback.selectionClick();
    _loadGlucoseData(); // Reload with new time range filter
  }

  void _onTabChanged(int index) {
    setState(() => _selectedTabIndex = index);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        _TimeRangeSelector(
                          selectedRange: _selectedTimeRange,
                          ranges: _timeRanges,
                          onChanged: _onTimeRangeChanged,
                        ),
                        _TabSelector(
                          selectedIndex: _selectedTabIndex,
                          titles: _tabTitles,
                          onChanged: _onTabChanged,
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadGlucoseData,
                            child: _buildTabContent(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToLogReading,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(
          'Log Reading',
          style: AppTheme.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Unable to Load Data',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: _loadGlucoseData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXL,
                  vertical: AppTheme.spacingL,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return SharedAppBar(
      title: 'Glucose Overview',
      showBackButton: true,
      showConnection: true,
      actions: [
        IconButton(
          onPressed: _syncLibreData,
          icon: const Icon(Icons.sync, color: Colors.white),
          tooltip: 'Sync with Libre',
        ),
        IconButton(
          onPressed: () => _showSnackBar('Export feature coming soon!'),
          icon: const Icon(Icons.file_download_outlined, color: Colors.white),
          tooltip: 'Export Data',
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _getTabContent(),
    );
  }

  Widget _getTabContent() {
    if (_glucoseReadings.isEmpty) {
      return _buildEmptyState();
    }

    switch (_selectedTabIndex) {
      case 0:
        return _OverviewTab(glucoseReadings: _glucoseReadings);
      case 1:
        return _TrendsTab(glucoseReadings: _glucoseReadings);
      case 2:
        return _StatisticsTab(glucoseReadings: _glucoseReadings);
      default:
        return _OverviewTab(glucoseReadings: _glucoseReadings);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bloodtype_rounded,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'No Glucose Readings',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Start logging your glucose readings or sync with your device',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _navigateToLogReading,
                  icon: const Icon(Icons.add),
                  label: const Text('Log Reading'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                OutlinedButton.icon(
                  onPressed: _syncLibreData,
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync Device'),
                ),
              ],
            ),
          ],
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingL),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.radiusM,
        boxShadow: AppTheme.lightShadow,
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
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                  borderRadius: AppTheme.radiusS,
                ),
                child: Text(
                  range,
                  textAlign: TextAlign.center,
                  style: AppTheme.labelMedium.copyWith(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
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

// Tab Selector Widget
class _TabSelector extends StatelessWidget {
  final int selectedIndex;
  final List<String> titles;
  final ValueChanged<int> onChanged;

  const _TabSelector({
    required this.selectedIndex,
    required this.titles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      child: Row(
        children: titles.asMap().entries.map((entry) {
          final index = entry.key;
          final title = entry.value;
          final isSelected = selectedIndex == index;
          
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingL),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTheme.titleSmall.copyWith(
                    color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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

// Overview Tab Widget
class _OverviewTab extends StatelessWidget {
  final List<GlucoseReading> glucoseReadings;

  const _OverviewTab({required this.glucoseReadings});

  @override
  Widget build(BuildContext context) {
    final hasReadings = glucoseReadings.isNotEmpty;
    
    return SingleChildScrollView(
      key: const ValueKey('overview'),
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasReadings) _CurrentGlucoseCard(reading: glucoseReadings.first),
          if (hasReadings) const SizedBox(height: AppTheme.spacingXL),
          if (hasReadings) _GlucoseChart(readings: glucoseReadings),
          if (hasReadings) const SizedBox(height: AppTheme.spacingXL),
          if (hasReadings) _QuickStats(readings: glucoseReadings),
          if (hasReadings) const SizedBox(height: AppTheme.spacingXL),
          _RecentReadings(readings: hasReadings ? glucoseReadings.take(5).toList() : []),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// Current Glucose Card Widget
class _CurrentGlucoseCard extends StatelessWidget {
  final GlucoseReading reading;

  const _CurrentGlucoseCard({required this.reading});

  @override
  Widget build(BuildContext context) {
    final glucoseColor = AppTheme.getGlucoseColor(reading.value);
    final glucoseStatus = AppTheme.getGlucoseStatus(reading.value);
    final timeAgo = _getTimeAgo(reading.timestamp);

    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Reading',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              StatusBadge(
                label: glucoseStatus,
                color: glucoseColor,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                reading.value.toInt().toString(),
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: glucoseColor,
                  height: 1,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'mg/dL',
                  style: AppTheme.titleMedium.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: glucoseColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Updated $timeAgo',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// Glucose Chart Widget
class _GlucoseChart extends StatelessWidget {
  final List<GlucoseReading> readings;

  const _GlucoseChart({required this.readings});

  @override
  Widget build(BuildContext context) {
    final timeInRange = _calculateTimeInRange();

    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Glucose Trend',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              StatusBadge(
                label: '$timeInRange% in range',
                color: timeInRange >= 70 ? AppTheme.successGreen : AppTheme.warningOrange,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) {
                    Color lineColor = AppTheme.borderLight;
                    double strokeWidth = 0.5;
                    List<int>? dashArray;
                    
                    if (value == 70 || value == 180) {
                      lineColor = AppTheme.primaryBlue.withOpacity(0.3);
                      strokeWidth = 1;
                      dashArray = [5, 5];
                    }
                    
                    return FlLine(
                      color: lineColor,
                      strokeWidth: strokeWidth,
                      dashArray: dashArray,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 25,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        final hours = _generateHourLabels(readings.length);
                        final index = value.toInt();
                        if (index >= 0 && index < hours.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              hours[index],
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (readings.length - 1).toDouble(),
                minY: 50,
                maxY: 300,
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppTheme.primaryBlue,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final glucoseValue = spot.y;
                        final color = AppTheme.getGlucoseColor(glucoseValue);
                        return FlDotCirclePainter(
                          radius: 4,
                          color: color,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primaryBlue.withOpacity(0.15),
                          AppTheme.primaryBlue.withOpacity(0.02),
                        ],
                      ),
                    ),
                    spots: readings.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.value,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateTimeInRange() {
    if (readings.isEmpty) return 0;
    final inRange = readings.where((reading) => 
        reading.value >= 70 && reading.value <= 180).length;
    return ((inRange / readings.length) * 100).round();
  }

  List<String> _generateHourLabels(int readingCount) {
    if (readingCount <= 5) {
      return List.generate(readingCount, (index) => '${index + 1}');
    }
    return ['Start', '', 'Mid', '', 'Now'];
  }
}

// Quick Stats Widget
class _QuickStats extends StatelessWidget {
  final List<GlucoseReading> readings;

  const _QuickStats({required this.readings});

  @override
  Widget build(BuildContext context) {
    final avgGlucose = _calculateAverageGlucose();
    final timeInRange = _calculateTimeInRange();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Quick Statistics',
          subtitle: 'Key metrics summary',
        ),
        const SizedBox(height: AppTheme.spacingL),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Average',
                value: avgGlucose.toInt().toString(),
                unit: 'mg/dL',
                icon: Icons.analytics_rounded,
                accentColor: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: MetricCard(
                title: 'Time in Range',
                value: timeInRange.toString(),
                unit: '%',
                subtitle: 'Goal: >70%',
                icon: Icons.timeline_rounded,
                accentColor: timeInRange >= 70 ? AppTheme.successGreen : AppTheme.warningOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingL),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Low Events',
                value: _calculateLowEvents().toString(),
                icon: Icons.trending_down_rounded,
                accentColor: AppTheme.glucoseLow,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: MetricCard(
                title: 'High Events',
                value: _calculateHighEvents().toString(),
                icon: Icons.trending_up_rounded,
                accentColor: AppTheme.glucoseHigh,
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _calculateAverageGlucose() {
    if (readings.isEmpty) return 0;
    final sum = readings.fold(0.0, (sum, reading) => sum + reading.value);
    return sum / readings.length;
  }

  int _calculateTimeInRange() {
    if (readings.isEmpty) return 0;
    final inRange = readings.where((reading) => 
        reading.value >= 70 && reading.value <= 180).length;
    return ((inRange / readings.length) * 100).round();
  }

  int _calculateLowEvents() {
    return readings.where((reading) => reading.value < 70).length;
  }

  int _calculateHighEvents() {
    return readings.where((reading) => reading.value > 180).length;
  }
}

// Recent Readings Widget
class _RecentReadings extends StatelessWidget {
  final List<GlucoseReading> readings;

  const _RecentReadings({required this.readings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent Readings',
          action: TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('View All'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              textStyle: AppTheme.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingL),
        if (readings.isEmpty)
          EmptyState(
            icon: Icons.bloodtype_rounded,
            title: 'No readings yet',
            description: 'Start logging your glucose readings to see them here',
            actionLabel: 'Log Reading',
            onAction: () {},
          )
        else
          BaseCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: readings.asMap().entries.map((entry) {
                final index = entry.key;
                final reading = entry.value;
                final isLast = index == readings.length - 1;
                return _ReadingItem(reading: reading, showDivider: !isLast);
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// Reading Item Widget
class _ReadingItem extends StatelessWidget {
  final GlucoseReading reading;
  final bool showDivider;

  const _ReadingItem({
    required this.reading,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final glucoseColor = AppTheme.getGlucoseColor(reading.value);
    final glucoseStatus = AppTheme.getGlucoseStatus(reading.value);
    final timeAgo = _getTimeAgo(reading.timestamp);

    return CustomListItem(
      icon: Icons.bloodtype_rounded,
      iconColor: glucoseColor,
      title: '${reading.value.toInt()} mg/dL',
      subtitle: timeAgo,
      trailing: StatusBadge(
        label: glucoseStatus,
        color: glucoseColor,
      ),
      showDivider: showDivider,
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// Trends Tab Widget
class _TrendsTab extends StatelessWidget {
  final List<GlucoseReading> glucoseReadings;

  const _TrendsTab({required this.glucoseReadings});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('trends'),
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        children: [
          _DetailedChart(readings: glucoseReadings),
          const SizedBox(height: AppTheme.spacingXL),
          _TrendAnalysis(),
          const SizedBox(height: AppTheme.spacingXL),
          _PatternInsights(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// Detailed Chart Widget
class _DetailedChart extends StatelessWidget {
  final List<GlucoseReading> readings;

  const _DetailedChart({required this.readings});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Detailed Trends',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  _LegendItem('In Range', AppTheme.successGreen),
                  const SizedBox(width: 12),
                  _LegendItem('High', AppTheme.glucoseHigh),
                  const SizedBox(width: 12),
                  _LegendItem('Low', AppTheme.glucoseLow),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  verticalInterval: 4,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) {
                    if (value == 70 || value == 180) {
                      return FlLine(
                        color: AppTheme.primaryBlue.withOpacity(0.4),
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                      );
                    }
                    return FlLine(
                      color: AppTheme.borderLight,
                      strokeWidth: 0.5,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: AppTheme.borderLight,
                      strokeWidth: 0.3,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 25,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        final hours = _generateDetailedHourLabels();
                        final index = value.toInt();
                        if (index >= 0 && index < hours.length && index % 4 == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              hours[index],
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    bottom: BorderSide(color: AppTheme.borderLight),
                    left: BorderSide(color: AppTheme.borderLight),
                  ),
                ),
                minX: 0,
                maxX: 23,
                minY: 50,
                maxY: 300,
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: AppTheme.primaryBlue,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final glucoseValue = spot.y;
                        final color = AppTheme.getGlucoseColor(glucoseValue);
                        return FlDotCirclePainter(
                          radius: 3,
                          color: color,
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                    spots: _generateDetailedChartData(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _generateDetailedHourLabels() {
    final labels = <String>[];
    for (int i = 0; i < 24; i++) {
      labels.add('${i.toString().padLeft(2, '0')}:00');
    }
    return labels;
  }

  List<FlSpot> _generateDetailedChartData() {
    final spots = <FlSpot>[];
    for (int i = 0; i < 24; i++) {
      final value = 100 + (50 * (0.5 - (i - 12).abs() / 24)) + (20 * (i % 3 - 1));
      spots.add(FlSpot(i.toDouble(), value.clamp(60, 250)));
    }
    return spots;
  }
}

// Legend Item Widget
class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Trend Analysis Widget
class _TrendAnalysis extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  Icons.analytics_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Text(
                'Trend Analysis',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          _TrendItem(
            'Overall Trend',
            'Stable with minor fluctuations',
            Icons.trending_flat_rounded,
            AppTheme.successGreen,
          ),
          const SizedBox(height: AppTheme.spacingM),
          _TrendItem(
            'Peak Times',
            'Highest readings around 12 PM',
            Icons.schedule_rounded,
            AppTheme.warningOrange,
          ),
          const SizedBox(height: AppTheme.spacingM),
          _TrendItem(
            'Variability',
            'Low glucose variability (CV: 28%)',
            Icons.timeline_rounded,
            AppTheme.primaryBlue,
          ),
        ],
      ),
    );
  }
}

// Trend Item Widget
class _TrendItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _TrendItem(this.title, this.description, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: AppTheme.radiusS,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Pattern Insights Widget
class _PatternInsights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.mealColor.withOpacity(0.1),
                  borderRadius: AppTheme.radiusS,
                ),
                child: Icon(
                  Icons.lightbulb_rounded,
                  color: AppTheme.mealColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Text(
                'Pattern Insights',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'Based on your recent glucose patterns, here are some key insights:',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          _InsightCard(
            'Morning Pattern',
            'Your glucose tends to rise between 6-8 AM. Consider adjusting breakfast timing.',
            Icons.wb_sunny_rounded,
            AppTheme.mealColor,
          ),
          const SizedBox(height: AppTheme.spacingM),
          _InsightCard(
            'Post-Meal Response',
            'Good control after meals with average peak of 145 mg/dL.',
            Icons.restaurant_rounded,
            AppTheme.successGreen,
          ),
        ],
      ),
    );
  }
}

// Insight Card Widget
class _InsightCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _InsightCard(this.title, this.description, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: AppTheme.radiusM,
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.3,
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

// Statistics Tab Widget
class _StatisticsTab extends StatelessWidget {
  final List<GlucoseReading> glucoseReadings;

  const _StatisticsTab({required this.glucoseReadings});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('statistics'),
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        children: [
          _StatisticsGrid(readings: glucoseReadings),
          const SizedBox(height: AppTheme.spacingXL),
          _TimeInRangeChart(readings: glucoseReadings),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// Statistics Grid Widget
class _StatisticsGrid extends StatelessWidget {
  final List<GlucoseReading> readings;

  const _StatisticsGrid({required this.readings});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppTheme.spacingM,
      mainAxisSpacing: AppTheme.spacingM,
      childAspectRatio: 1.1,
      children: [
        MetricCard(
          title: 'Avg Glucose',
          value: _calculateAverageGlucose().toInt().toString(),
          unit: 'mg/dL',
          icon: Icons.analytics_rounded,
          accentColor: AppTheme.primaryBlue,
        ),
        MetricCard(
          title: 'Time in Range',
          value: _calculateTimeInRange().toString(),
          unit: '%',
          icon: Icons.timeline_rounded,
          accentColor: AppTheme.successGreen,
        ),
        MetricCard(
          title: 'Low Events',
          value: _calculateLowEvents().toString(),
          icon: Icons.trending_down_rounded,
          accentColor: AppTheme.glucoseLow,
        ),
        MetricCard(
          title: 'High Events',
          value: _calculateHighEvents().toString(),
          icon: Icons.trending_up_rounded,
          accentColor: AppTheme.glucoseHigh,
        ),
        MetricCard(
          title: 'Variability',
          value: '28',
          unit: '% CV',
          icon: Icons.show_chart_rounded,
          accentColor: AppTheme.insightsColor,
        ),
        MetricCard(
          title: 'Readings',
          value: readings.length.toString(),
          unit: 'total',
          icon: Icons.data_usage_rounded,
          accentColor: AppTheme.profileColor,
        ),
      ],
    );
  }

  double _calculateAverageGlucose() {
    if (readings.isEmpty) return 0;
    final sum = readings.fold(0.0, (sum, reading) => sum + reading.value);
    return sum / readings.length;
  }

  int _calculateTimeInRange() {
    if (readings.isEmpty) return 0;
    final inRange = readings.where((reading) => 
        reading.value >= 70 && reading.value <= 180).length;
    return ((inRange / readings.length) * 100).round();
  }

  int _calculateLowEvents() {
    return readings.where((reading) => reading.value < 70).length;
  }

  int _calculateHighEvents() {
    return readings.where((reading) => reading.value > 180).length;
  }
}

// Time in Range Chart Widget
class _TimeInRangeChart extends StatelessWidget {
  final List<GlucoseReading> readings;

  const _TimeInRangeChart({required this.readings});

  @override
  Widget build(BuildContext context) {
    final timeInRange = _calculateTimeInRange();
    final highTime = _calculateHighTime();
    final lowTime = 100 - timeInRange - highTime;

    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time in Range Distribution',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: timeInRange.toDouble(),
                    color: AppTheme.successGreen,
                    title: '$timeInRange%\nIn Range',
                    titleStyle: AppTheme.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    radius: 60,
                    titlePositionPercentageOffset: 0.6,
                  ),
                  PieChartSectionData(
                    value: highTime.toDouble(),
                    color: AppTheme.glucoseHigh,
                    title: '$highTime%\nHigh',
                    titleStyle: AppTheme.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    radius: 55,
                    titlePositionPercentageOffset: 0.6,
                  ),
                  PieChartSectionData(
                    value: lowTime.toDouble(),
                    color: AppTheme.glucoseLow,
                    title: '$lowTime%\nLow',
                    titleStyle: AppTheme.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    radius: 50,
                    titlePositionPercentageOffset: 0.6,
                  ),
                ],
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _RangeIndicator('In Range', '70-180 mg/dL', AppTheme.successGreen),
              _RangeIndicator('High', '>180 mg/dL', AppTheme.glucoseHigh),
              _RangeIndicator('Low', '<70 mg/dL', AppTheme.glucoseLow),
            ],
          ),
        ],
      ),
    );
  }

  int _calculateTimeInRange() {
    if (readings.isEmpty) return 0;
    final inRange = readings.where((reading) => 
        reading.value >= 70 && reading.value <= 180).length;
    return ((inRange / readings.length) * 100).round();
  }

  int _calculateHighTime() {
    if (readings.isEmpty) return 0;
    final high = readings.where((reading) => reading.value > 180).length;
    return ((high / readings.length) * 100).round();
  }
}

// Range Indicator Widget
class _RangeIndicator extends StatelessWidget {
  final String label;
  final String range;
  final Color color;

  const _RangeIndicator(this.label, this.range, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTheme.labelSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          range,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }
}