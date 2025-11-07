import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';
import 'package:fl_chart/fl_chart.dart';
import 'log_reading_page.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Backend data
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, dynamic>? _userProfile;
  List<dynamic> _glucoseRecords = [];
  List<dynamic> _foodEntries = [];
  Map<String, dynamic>? _glucoseStats;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
    _loadData();
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

  Future<void> _loadData() async {
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await _apiService.init();
      
      // Check if user is logged in
      if (!_apiService.isLoggedIn) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/auth');
        }
        return;
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
      
      final profile = await _apiService.getProfile();
      final glucoseRecords = await _apiService.getGlucoseRecords(startDate: startOfDay, endDate: endOfDay, limit: 50);
      final foodEntries = await _apiService.getFoodEntries(startDate: startOfDay, endDate: endOfDay);

      Map<String, dynamic> glucoseStats = {};
      try {
        glucoseStats = await _apiService.getGlucoseStatistics(
            startDate: startOfDay, endDate: endOfDay);
      } catch (e) {
        print('⚠️ Failed to load stats, continuing without them: $e');
      }
      setState(() {
        _userProfile = profile;
        _glucoseRecords = glucoseRecords;
        _foodEntries = foodEntries;
        _glucoseStats = glucoseStats;
        _isLoading = false;
        _hasError = false;
      });

    } catch (e) {
      print('Error loading data: $e');
      
      // Try to use cached profile if available
      if (_apiService.cachedProfile != null) {
        if (mounted) {
          setState(() {
            _userProfile = _apiService.cachedProfile;
            _isLoading = false;
            _hasError = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      }
    }
  }
  Map<String, dynamic>? getLatestGlucoseReading(List<dynamic> records) {
    if (records.isEmpty) return null;

    records.sort((a, b) {
      final aTime = DateTime.parse(a['timestamp']);
      final bTime = DateTime.parse(b['timestamp']);
      return bTime.compareTo(aTime); // descending
    });

    return records.first;
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
                Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeInOut)),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      
      if (result == true) {
        _showSnackBar('Reading logged successfully!');
        _loadData(); // Reload data after logging
      }
    } catch (e) {
      _showSnackBar('Failed to navigate', isSuccess: false);
    }
  }

  void _navigateToLogMeal() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, '/scanner').then((_) => _loadData());
  }

  String _getUserName() {
    if (_userProfile != null) {
      final fullName = _userProfile!['full_name'];
      if (fullName != null && fullName.isNotEmpty) {
        return fullName.split(' ').first;
      }
      final username = _userProfile!['username'];
      return username ?? 'User';
    }
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryBlue),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                'Loading your health data...',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.primaryBlue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show error banner if data failed to load
                  if (_hasError)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppTheme.spacingL),
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange.withOpacity(0.1),
                        borderRadius: AppTheme.radiusM,
                        border: Border.all(color: AppTheme.warningOrange),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off, color: AppTheme.warningOrange, size: 20),
                          const SizedBox(width: AppTheme.spacingM),
                          Expanded(
                            child: Text(
                              'Using cached data. Pull to refresh.',
                              style: AppTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _WelcomeSection(
                    userName: _getUserName(),
                    readingsCount: _glucoseRecords.length,
                    timeInRange: _glucoseStats?['time_in_range'] is num 
                        ? (_glucoseStats!['time_in_range'] as num).toInt() 
                        : 0,
                    avgGlucose: _glucoseStats?['avg_glucose'] is num
                        ? (_glucoseStats!['avg_glucose'] as num).toInt()
                        : 0,
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  _CurrentGlucoseSection(
                    onLogReading: _navigateToLogReading,
                    onLogMeal: _navigateToLogMeal,
                    latestReading: getLatestGlucoseReading(_glucoseRecords),
                    glucoseRecords: _glucoseRecords,
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  _QuickStatsSection(
                    timeInRange: _glucoseStats?['time_in_range'] is num 
                        ? (_glucoseStats!['time_in_range'] as num).toInt() 
                        : 0,
                    variability: _glucoseStats?['coefficient_of_variation'] is num
                        ? (_glucoseStats!['coefficient_of_variation'] as num).toInt()
                        : 0,
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  _QuickActionsSection(onShowSnackBar: _showSnackBar),
                  const SizedBox(height: AppTheme.spacingXL),
                  _RecentActivitySection(
                    onShowSnackBar: _showSnackBar,
                    glucoseRecords: _glucoseRecords.take(3).toList(),
                    foodEntries: _foodEntries.take(3).toList(),
                  ),
                  const SizedBox(height: AppTheme.spacingXXL),
                ],
              ),
            ),
          ),
        ),
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
}


class _WelcomeSection extends StatelessWidget {
  final String userName;
  final int readingsCount;
  final int timeInRange;
  final int avgGlucose;

  const _WelcomeSection({
    required this.userName,
    required this.readingsCount,
    required this.timeInRange,
    required this.avgGlucose,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting = 'Good morning';
    if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
    } else if (hour >= 17) {
      greeting = 'Good evening';
    }

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
                  Icons.waving_hand_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $userName',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Here\'s your glucose summary for today',
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Readings',
                  value: readingsCount.toString(),
                  accentColor: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: MetricCard(
                  title: 'In Range',
                  value: timeInRange > 0 ? timeInRange.toString() : '--',
                  unit: timeInRange > 0 ? '%' : '',
                  accentColor: AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: MetricCard(
                  title: 'Average',
                  value: avgGlucose > 0 ? avgGlucose.toString() : '--',
                  unit: avgGlucose > 0 ? 'mg' : '',
                  accentColor: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _CurrentGlucoseSection extends StatelessWidget {
  final VoidCallback onLogReading;
  final VoidCallback onLogMeal;
  final Map<String, dynamic>? latestReading;
  final List<dynamic> glucoseRecords;

  const _CurrentGlucoseSection({
    required this.onLogReading,
    required this.onLogMeal,
    this.latestReading,
    required this.glucoseRecords,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = latestReading != null;
    final glucoseValue = latestReading?['glucose_level']?.toDouble() ?? 0.0;
    final timestamp = latestReading?['timestamp'];
    
    String timeAgo = 'No data';
    if (hasData && timestamp != null) {
      try {
        final dateTime = DateTime.parse(timestamp);
        final difference = DateTime.now().difference(dateTime);
        if (difference.inMinutes < 1) {
          timeAgo = 'Just now';
        } else if (difference.inMinutes < 60) {
          timeAgo = '${difference.inMinutes} min ago';
        } else if (difference.inHours < 24) {
          timeAgo = '${difference.inHours} hr ago';
        } else {
          timeAgo = '${difference.inDays} day${difference.inDays > 1 ? "s" : ""} ago';
        }
      } catch (e) {
        timeAgo = 'Recently';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Current Glucose'),
        const SizedBox(height: AppTheme.spacingS),
        BaseCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              hasData && glucoseValue > 0 ? glucoseValue.toInt().toString() : '--',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: hasData && glucoseValue > 0
                                    ? AppTheme.getGlucoseColor(glucoseValue)
                                    : AppTheme.textSecondary,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                hasData && glucoseValue > 0 ? 'mg/dL' : '',
                                style: AppTheme.bodyLarge.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeAgo,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (hasData && glucoseValue > 0) ...[
                              const SizedBox(width: AppTheme.spacingS),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.getGlucoseColor(glucoseValue)
                                      .withOpacity(0.1),
                                  borderRadius: AppTheme.radiusS,
                                ),
                                child: Text(
                                  AppTheme.getGlucoseStatus(glucoseValue),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.getGlucoseColor(glucoseValue),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: hasData && glucoseValue > 0
                          ? AppTheme.getGlucoseColor(glucoseValue).withOpacity(0.1)
                          : AppTheme.textSecondary.withOpacity(0.1),
                      borderRadius: AppTheme.radiusM,
                    ),
                    child: Icon(
                      Icons.bloodtype_rounded,
                      size: 32,
                      color: hasData && glucoseValue > 0
                          ? AppTheme.getGlucoseColor(glucoseValue)
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onLogReading,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Log Reading'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.radiusM,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onLogMeal,
                      icon: const Icon(Icons.restaurant, size: 18),
                      label: const Text('Log Meal'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.radiusM,
                        ),
                        side: BorderSide(color: AppTheme.primaryBlue),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),
              SizedBox(
                height: 120,
                child: _buildChart(glucoseRecords),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChart(List<dynamic> records) {
    final validRecords = records.where((record) {
      final glucose = record['glucose_level']?.toDouble();
      final timestamp = record['timestamp'];
      return glucose != null && glucose > 0 && timestamp != null;
    }).toList();

    if (validRecords.isEmpty) {
      return Center(
        child: Text(
          'No data to display',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
      );
    }

    // Prepare chart data from real records
    final sortedRecords = List.from(validRecords)
      ..sort((a, b) {
        final aTime = DateTime.parse(a['timestamp']);
        final bTime = DateTime.parse(b['timestamp']);
        return aTime.compareTo(bTime);
      });

    final spots = <FlSpot>[];
    for (var i = 0; i < sortedRecords.length && i < 10; i++) {
      final record = sortedRecords[i];
      final glucose = record['glucose_level']?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), glucose));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 40,
        maxY: 250,
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppTheme.primaryBlue,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: AppTheme.primaryBlue,
                  strokeWidth: 1,
                  strokeColor: AppTheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.1),
                  AppTheme.primaryBlue.withOpacity(0.02),
                ],
              ),
            ),
            spots: spots,
          ),
        ],
      ),
    );
  }
}

// Quick Stats Section - Uses real backend data
class _QuickStatsSection extends StatelessWidget {
  final int timeInRange;
  final int variability;

  const _QuickStatsSection({
    required this.timeInRange,
    required this.variability,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Today\'s Summary',
        ),
        const SizedBox(height: AppTheme.spacingS),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Time in Range',
                value: timeInRange > 0 ? timeInRange.toString() : '--',
                unit: timeInRange > 0 ? '%' : '',
                subtitle: 'Goal: >70%',
                icon: Icons.timeline_rounded,
                accentColor: AppTheme.successGreen,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: MetricCard(
                title: 'Variability',
                value: variability > 0 ? variability.toString() : '--',
                unit: variability > 0 ? '% CV' : '',
                subtitle: variability > 0 && variability <= 36 ? 'Low variation' : 'Monitor',
                icon: Icons.analytics_rounded,
                accentColor: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final Function(String, {bool isSuccess}) onShowSnackBar;

  const _QuickActionsSection({required this.onShowSnackBar});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Quick Actions',
        ),
        const SizedBox(height: AppTheme.spacingS),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Connect Sensor',
                subtitle: 'Scan your device',
                onTap: () => onShowSnackBar('Sensor scan coming soon!'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: _ActionCard(
                icon: Icons.camera_alt_rounded,
                title: 'Food Scanner',
                subtitle: 'Identify nutrition',
                onTap: () => onShowSnackBar('Food scanner coming soon!'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: BaseCard(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.08),
                borderRadius: AppTheme.radiusM,
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryBlue,
                size: 28,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              title,
              style: AppTheme.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Recent Activity Section - Uses real backend data
class _RecentActivitySection extends StatelessWidget {
  final Function(String, {bool isSuccess}) onShowSnackBar;
  final List<dynamic> glucoseRecords;
  final List<dynamic> foodEntries;

  const _RecentActivitySection({
    required this.onShowSnackBar,
    required this.glucoseRecords,
    required this.foodEntries,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = glucoseRecords.isNotEmpty || foodEntries.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent Activity',
          action: TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/glucose-overview'),
            label: const Text('View All'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              textStyle: AppTheme.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        BaseCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: hasData 
                ? _buildRealActivity()
                : [
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingXL),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: AppTheme.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          Text(
                            'No recent activity',
                            style: AppTheme.titleSmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            'Start logging to see your activity here',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRealActivity() {
    final activities = <Widget>[];
    
    // Add glucose readings
    for (var i = 0; i < glucoseRecords.length && i < 2; i++) {
      final record = glucoseRecords[i];
      final glucose = record['glucose_level']?.toDouble() ?? 0.0;
      final timestampStr = record['timestamp'];
      
      if (timestampStr == null || glucose <= 0) continue;
      
      try {
        final timestamp = DateTime.parse(timestampStr);
        final timeStr = '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')} ${timestamp.hour >= 12 ? 'PM' : 'AM'}';
        
        activities.add(
          CustomListItem(
            icon: Icons.bloodtype_rounded,
            iconColor: AppTheme.getGlucoseColor(glucose),
            title: 'Glucose Reading',
            subtitle: '${glucose.toInt()} mg/dL • $timeStr',
            trailing: StatusBadge(
              label: AppTheme.getGlucoseStatus(glucose),
              color: AppTheme.getGlucoseColor(glucose),
            ),
            showDivider: i < glucoseRecords.length - 1 && i < 1,
          ),
        );
      } catch (e) {
        print('Error parsing timestamp: $e');
        continue;
      }
    }

    // Add food entries
    for (var i = 0; i < foodEntries.length && i < 2; i++) {
      final entry = foodEntries[i];
      final foodName = entry['food_name'] ?? 'Meal';
      final timestampStr = entry['timestamp'];
      
      if (timestampStr == null) continue;
      
      try {
        final timestamp = DateTime.parse(timestampStr);
        final timeStr = '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')} ${timestamp.hour >= 12 ? 'PM' : 'AM'}';
        final carbs = entry['nutritional_info']?['carbs']?.toInt() ?? 0;
        
        activities.add(
          CustomListItem(
            icon: Icons.restaurant_rounded,
            iconColor: AppTheme.mealColor,
            title: '${entry['meal_type'] ?? 'Meal'} Logged',
            subtitle: '$foodName${carbs > 0 ? ' • ${carbs}g carbs' : ''} • $timeStr',
            trailing: StatusBadge(
              label: 'Logged',
              color: AppTheme.successGreen,
            ),
            showDivider: i < foodEntries.length - 1 && i < 1,
          ),
        );
      } catch (e) {
        print('Error parsing food entry timestamp: $e');
        continue;
      }
    }

    // If no activities were added due to invalid data, show empty state
    if (activities.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: AppTheme.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'No valid activity data',
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'Recent entries contain invalid data',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }

    // Remove divider from last item
    if (activities.isNotEmpty) {
      final lastActivity = activities.last;
      // Assuming CustomListItem has a way to update showDivider, you might need to reconstruct it
      // For now, we'll just ensure the last item doesn't show a divider
      activities[activities.length - 1] = CustomListItem(
        icon: lastActivity is CustomListItem ? _getIconFromListItem(lastActivity) : Icons.error,
        iconColor: lastActivity is CustomListItem ? _getIconColorFromListItem(lastActivity) : AppTheme.errorRed,
        title: lastActivity is CustomListItem ? _getTitleFromListItem(lastActivity) : 'Error',
        subtitle: lastActivity is CustomListItem ? _getSubtitleFromListItem(lastActivity) : 'Invalid data',
        trailing: lastActivity is CustomListItem ? _getTrailingFromListItem(lastActivity) : null,
        showDivider: false,
      );
    }

    return activities;
  }

  // Helper methods to extract data from existing CustomListItem (these would need to be implemented based on your CustomListItem class)
  IconData _getIconFromListItem(CustomListItem item) => Icons.error; // Placeholder
  Color _getIconColorFromListItem(CustomListItem item) => AppTheme.errorRed; // Placeholder
  String _getTitleFromListItem(CustomListItem item) => 'Error'; // Placeholder
  String _getSubtitleFromListItem(CustomListItem item) => 'Invalid data'; // Placeholder
  Widget? _getTrailingFromListItem(CustomListItem item) => null; // Placeholder
}

// Placeholder helper methods - you'll need to implement these based on your CustomListItem implementation
IconData _getIconFromListItem(CustomListItem item) => Icons.error;
Color _getIconColorFromListItem(CustomListItem item) => AppTheme.errorRed;
String _getTitleFromListItem(CustomListItem item) => 'Error';
String _getSubtitleFromListItem(CustomListItem item) => 'Invalid data';
Widget? _getTrailingFromListItem(CustomListItem item) => null;