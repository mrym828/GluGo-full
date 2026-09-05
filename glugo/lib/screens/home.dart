import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glugo/screens/recent_activity_page.dart';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';
import 'package:fl_chart/fl_chart.dart';
import 'log_reading_page.dart';
import '../services/api_service.dart';
import '../utils/glucose_utils.dart';

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';


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
  // null while the status hasn't been checked yet, so the app bar badge can
  // show a neutral "checking" state instead of falsely claiming Connected.
  bool? _isLibreConnected;

  // Quick prediction data
  Map<String, dynamic>? _quickPrediction;
  bool _predictionLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
    _loadData();
    _checkLibreStatus();
    _setupPeriodicRefresh();
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

  void _setupPeriodicRefresh() {
    Future.delayed(const Duration(minutes: 2), () {
      if (mounted && !_isLoading) {
        _loadData();
      }
      _setupPeriodicRefresh(); // Reschedule
    });
  }

  /// The Libre status endpoint returns `connected`, not `is_connected` —
  /// every other call site in the app (home badge, sync action, glucose
  /// overview, profile) had been reading the wrong key and so always saw
  /// `null ?? false`, i.e. permanently "disconnected" regardless of the
  /// real state. Fixed here; see SESSION_SUMMARY.md for the other sites.
  Future<void> _checkLibreStatus() async {
    try {
      final status = await _apiService.getLibreStatus();
      final isConnected = status['connected'] ?? false;
      if (mounted) {
        setState(() {
          _isLibreConnected = isConnected;
        });
      }
    } catch (e) {
      print('Error checking Libre connection: $e');
      if (mounted) {
        setState(() {
          _isLibreConnected = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      await _apiService.init();
      
      if (!_apiService.isLoggedIn) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/auth');
        }
        return;
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
      
      // Load data in parallel for better performance
      final results = await Future.wait([
        _loadGlucoseRecordsWithDebug(startOfDay, endOfDay),
        _apiService.getFoodEntries(startDate: startOfDay, endDate: endOfDay),
        _loadGlucoseStatsWithFallback(startOfDay, endOfDay),
      ], eagerError: false);

      final profile = await _apiService.getProfile();
      final glucoseRecords = results[0] as List<dynamic>;

      // Same-day only — a record from any time in the last 24h used to also
      // qualify, which could pull in yesterday's readings (e.g. an 11pm
      // reading) into what's supposed to be "today's" chart/summary.
      final filteredRecords = glucoseRecords.where((record) {
      try{
      final timestamp = DateTime.parse(record['timestamp']).toLocal();
      return timestamp.isAfter(startOfDay) && timestamp.isBefore(endOfDay);
       } catch(e){
          print('Error parsing timestamp for record: $e');
          return false;
      }}).toList();

      filteredRecords.sort((a, b) {
      final aTime = DateTime.parse(a['timestamp']);
      final bTime = DateTime.parse(b['timestamp']);
      return bTime.compareTo(aTime);
       });

      final foodEntries = results[1] as List<dynamic>;

      final filteredFoodEntries = foodEntries.where((entry){
      try {
        final timestamp = DateTime.parse(entry['timestamp']).toLocal();
        return timestamp.isAfter(startOfDay) && timestamp.isBefore(endOfDay);
      } catch (e) {
        return false;
      }
    }).toList();

      final glucoseStats = results[2] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _glucoseRecords = filteredRecords;
          _foodEntries = filteredFoodEntries;
          _glucoseStats = glucoseStats;
          _isLoading = false;
          _hasError = false;
        });
        
        // Debug logging
        _debugDataState();
        
        // Load quick prediction after successful data load
        _loadQuickPrediction();
      }

    } catch (e) {
      print('Error loading home data: $e');
      
      print('Error details:');
    print('  - Glucose records length: ${_glucoseRecords.length}');
    if (_glucoseRecords.isNotEmpty) {
      print('  - First record: ${_glucoseRecords.first}');
    }
    
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

  Future<void> _loadQuickPrediction() async {
    setState(() {
      _predictionLoading = true;
    });
    
    try {
      final prediction = await _apiService.getQuickGlucosePrediction();
      
      if (mounted && prediction != null && prediction['success'] == true) {
        setState(() {
          _quickPrediction = prediction;
          _predictionLoading = false;
        });
      } else {
        setState(() {
          _quickPrediction = null;
          _predictionLoading = false;
        });
      }
    } catch (e) {
      print('Error loading quick prediction: $e');
      if (mounted) {
        setState(() {
          _quickPrediction = null;
          _predictionLoading = false;
        });
      }
    }
  }

  Future<List<dynamic>> _loadGlucoseRecordsWithDebug(DateTime start, DateTime end) async {
    try {
      final records = await _apiService.getGlucoseRecords(
        startDate: start,
        endDate: end,
        limit: 50,
      );
      
      print('📊 HomeScreen: Loaded ${records.length} total glucose records');
      
      final manualCount = records.where((r) => r['source'] == 'manual').length;
      final libreCount = records.where((r) => r['source'] == 'libre').length;
      final otherCount = records.length - manualCount - libreCount;
      
      print('📊 Sources - Manual: $manualCount, Libre: $libreCount, Other: $otherCount');
      
      records.sort((a, b) {
        final aTime = DateTime.parse(a['timestamp']);
        final bTime = DateTime.parse(b['timestamp']);
        return bTime.compareTo(aTime);
      });
      
      return records;
    } catch (e) {
      print('❌ Failed to load glucose records: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _loadGlucoseStatsWithFallback(DateTime start, DateTime end) async {
    try {
      return await _apiService.getGlucoseStatistics(
        startDate: start, 
        endDate: end
      );
    } catch (e) {
      print('⚠️ Failed to load stats, using empty: $e');
      return {};
    }
  }

  void _debugDataState() {
    print('🏠 HomeScreen Data State:');
    print('  - Glucose records: ${_glucoseRecords.length}');
    print('  - Food entries: ${_foodEntries.length}');
    print('  - User profile: ${_userProfile != null ? "loaded" : "null"}');
    print('  - Glucose stats: ${_glucoseStats?.keys.join(", ")}');
    
    if (_glucoseRecords.isNotEmpty) {
      final latest = _glucoseRecords.first;
      print('  - Latest reading: ${latest['glucose_level']} mg/dL at ${latest['timestamp']} (source: ${latest['source']})');
    }
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
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              await Future.wait([_loadData(), _checkLibreStatus()]);
            },
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
                    hasGlucoseData: _glucoseRecords.isNotEmpty,
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  _QuickPredictionSection(
                    prediction: _quickPrediction,
                    isLoading: _predictionLoading,
                    onRefresh: _loadQuickPrediction,
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  _QuickActionsSection(onShowSnackBar: _showSnackBar, onRefreshData: _loadData),
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
    return SharedAppBar(
      title: 'GluGo',
      showBackButton: false,
      showConnection: true,
      connectionState: _isLibreConnected == null
          ? LibreConnectionState.checking
          : (_isLibreConnected!
              ? LibreConnectionState.connected
              : LibreConnectionState.disconnected),
      onConnectionTap: () => Navigator.pushNamed(context, '/device').then((_) {
        _checkLibreStatus();
      }),
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
                  unit: avgGlucose > 0 ? 'mg\n/dl' : '',
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
    final source = latestReading?['source'] ?? 'manual';
    
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppTheme.getGlucoseStatus(glucoseValue),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.getGlucoseColor(glucoseValue),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      source == 'libre' 
                                          ? Icons.cloud_sync_rounded 
                                          : Icons.bloodtype_rounded,
                                      size: 12,
                                      color: AppTheme.getGlucoseColor(glucoseValue),
                                    ),
                                  ],
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
                      source == 'libre' ? Icons.cloud_sync_rounded : Icons.bloodtype_rounded,
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
                    child: ActionButton(
                      label: 'Log Reading',
                      icon: Icons.add_rounded,
                      onPressed: onLogReading,
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: ActionButton(
                      label: 'Log Meal',
                      icon: Icons.restaurant_rounded,
                      onPressed: onLogMeal,
                      isPrimary: false,
                      customColor: AppTheme.mealColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),
              _buildChart(glucoseRecords),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChart(List<dynamic> records) {
    // `records` is already same-day only (filtered upstream in HomeScreen),
    // so every point here belongs to today.
    final validRecords = records.where((record) {
      final glucose = record['glucose_level']?.toDouble();
      final timestamp = record['timestamp'];
      return glucose != null && glucose > 0 && timestamp != null;
    }).toList();

    if (validRecords.length < 2) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            validRecords.isEmpty
                ? 'No readings yet today'
                : 'Log another reading to see today\'s trend',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    // Chart data, oldest to newest so the line reads left-to-right in time.
    final sortedRecords = List.from(validRecords)
      ..sort((a, b) {
        final aTime = DateTime.parse(a['timestamp']);
        final bTime = DateTime.parse(b['timestamp']);
        return aTime.compareTo(bTime);
      });

    final spots = <FlSpot>[
      for (var i = 0; i < sortedRecords.length; i++)
        FlSpot(i.toDouble(), (sortedRecords[i]['glucose_level'] as num).toDouble()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Today\'s Trend',
              style: AppTheme.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              '${sortedRecords.length} reading${sortedRecords.length == 1 ? '' : 's'}',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 50,
                getDrawingHorizontalLine: (value) {
                  final isTargetLine = value == 70 || value == 180;
                  return FlLine(
                    color: isTargetLine
                        ? AppTheme.primaryBlue.withOpacity(0.3)
                        : AppTheme.borderLight,
                    strokeWidth: isTargetLine ? 1 : 0.5,
                    dashArray: isTargetLine ? [5, 5] : null,
                  );
                },
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: _chartLabelInterval(sortedRecords.length),
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= sortedRecords.length) {
                        return const SizedBox.shrink();
                      }
                      final time = DateTime.parse(sortedRecords[index]['timestamp']).toLocal();
                      final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
                      final period = time.hour >= 12 ? 'PM' : 'AM';
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '$hour$period',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 100,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (spots.length - 1).toDouble(),
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
                    show: spots.length <= 20,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 3,
                        color: AppTheme.getGlucoseColor(spot.y),
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
          ),
        ),
      ],
    );
  }

  double _chartLabelInterval(int count) {
    if (count <= 4) return 1;
    if (count <= 8) return 2;
    if (count <= 16) return 4;
    if (count <= 30) return 6;
    return 12;
  }
}

// Quick Stats Section - Uses real backend data
class _QuickStatsSection extends StatelessWidget {
  final int timeInRange;
  final int variability;
  final bool hasGlucoseData;

  const _QuickStatsSection({
    required this.timeInRange,
    required this.variability,
    required this.hasGlucoseData,
  });

  void _showInfoSheet(BuildContext context, String title, String description) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              description,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingL),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Today\'s Summary',
          subtitle: 'How steady your glucose has been today',
        ),
        const SizedBox(height: AppTheme.spacingS),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Time in Range',
                value: timeInRange > 0 ? timeInRange.toString() : '--',
                unit: timeInRange > 0 ? '%' : '',
                subtitle: hasGlucoseData ? 'Goal: >70%' : 'No readings yet',
                icon: Icons.timeline_rounded,
                accentColor: AppTheme.successGreen,
                onTap: () => _showInfoSheet(
                  context,
                  'Time in Range',
                  'The share of today\'s glucose readings that fell within the '
                      'target range of 70–180 mg/dL. Diabetes guidelines '
                      'generally recommend aiming for more than 70% of '
                      'readings in range.',
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: MetricCard(
                title: 'Variability',
                value: hasGlucoseData ? variability.toString() : '--',
                unit: hasGlucoseData ? '% CV' : '',
                subtitle: !hasGlucoseData
                    ? 'No readings yet'
                    : (variability <= 36 ? 'Low variation' : 'High variation'),
                icon: Icons.analytics_rounded,
                accentColor: AppTheme.primaryBlue,
                onTap: () => _showInfoSheet(
                  context,
                  'Glucose Variability',
                  'The coefficient of variation (%CV) measures how much your '
                      'glucose swings up and down today, not just its average. '
                      'A lower number means steadier levels — 36% or below is '
                      'generally considered good control.',
                ),
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
  final VoidCallback onRefreshData;

  const _QuickActionsSection({
    required this.onShowSnackBar,
    required this.onRefreshData,
  });

  Future<void> _syncLibreView(BuildContext context) async {
    final apiService = ApiService();
    await apiService.init();

    try {
      final status = await apiService.getLibreStatus();
      if (!(status['connected'] ?? false)){
        onShowSnackBar('Please connect LibreView first', isSuccess: false);
        Navigator.pushNamed(context, '/device');
        return;
      }

      onShowSnackBar('Syncing glucose data...', isSuccess: true);

      final result = await apiService.libreSyncNow();
      final recordsCount = result['records_synced'] ?? 0;

      // Add a small delay to ensure backend has processed the sync
      await Future.delayed(const Duration(seconds: 1));
      
      // Force refresh the data
      onRefreshData();

      onShowSnackBar(
        recordsCount > 0
        ? 'Synced $recordsCount new readings! Refreshing data...'
        : 'Already up to date.',
        isSuccess: true,
      );

    } catch (e) {
      print('❌ Sync error: $e');
      onShowSnackBar(
        'Sync failed: ${e.toString().replaceAll('Exception: ', '')}',
        isSuccess: false,
      );
    }
  }

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
                icon: Icons.sync_rounded,
                title: 'Sync LibreView',
                subtitle: 'Update readings',
                onTap: () => _syncLibreView(context),
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: _ActionCard(
                icon: Icons.camera_alt_rounded,
                title: 'Food Scanner',
                subtitle: 'Identify nutrition',
                onTap: () => Navigator.pushNamed(context, '/scanner'),
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
          onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecentActivityPage()),
              ),            label: const Text('View All'),
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
    // Collect glucose + food entries into one timestamped list so "recent"
    // actually means recent — previously this showed the first 2 glucose
    // readings then the first 2 food entries regardless of which set was
    // more recent, which could bury a just-logged meal under older readings.
    final entries = <_ActivityEntry>[];

    for (final record in glucoseRecords) {
      final glucose = record['glucose_level']?.toDouble() ?? 0.0;
      final timestampStr = record['timestamp'];
      final source = record['source'] ?? 'manual';

      if (timestampStr == null || glucose <= 0) continue;

      try {
        final timestamp = DateTime.parse(timestampStr).toLocal();
        final timeStr = _formatTime(timestamp);

        entries.add(_ActivityEntry(
          time: timestamp,
          icon: source == 'libre' ? Icons.cloud_sync_rounded : Icons.bloodtype_rounded,
          iconColor: AppTheme.getGlucoseColor(glucose),
          title: 'Glucose Reading',
          subtitle: '${glucose.toInt()} mg/dL • $timeStr • ${source == 'libre' ? 'Libre' : 'Manual'}',
          trailing: StatusBadge(
            label: AppTheme.getGlucoseStatus(glucose),
            color: AppTheme.getGlucoseColor(glucose),
          ),
        ));
      } catch (e) {
        print('Error parsing timestamp: $e');
        continue;
      }
    }

    for (final entry in foodEntries) {
      final foodName = entry['food_name'] ?? 'Meal';
      final timestampStr = entry['timestamp'];

      if (timestampStr == null) continue;

      try {
        final timestamp = DateTime.parse(timestampStr).toLocal();
        final timeStr = _formatTime(timestamp);
        // The API rarely populates the nested `nutritional_info` object (it's
        // only set when the client sends one at creation time); the carb
        // total that's actually saved lives on `total_carbs` directly.
        final carbs = (entry['total_carbs'] ?? entry['nutritional_info']?['carbs'])?.toInt() ?? 0;
        final mealType = entry['meal_type'] as String?;

        entries.add(_ActivityEntry(
          time: timestamp,
          icon: Icons.restaurant_rounded,
          iconColor: AppTheme.mealColor,
          title: '${_capitalize(mealType ?? 'Meal')} Logged',
          subtitle: '$foodName${carbs > 0 ? ' • ${carbs}g carbs' : ''} • $timeStr',
          trailing: StatusBadge(
            label: 'Logged',
            color: AppTheme.successGreen,
          ),
        ));
      } catch (e) {
        print('Error parsing food entry timestamp: $e');
        continue;
      }
    }

    if (entries.isEmpty) {
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

    entries.sort((a, b) => b.time.compareTo(a.time));
    final topEntries = entries.take(4).toList();

    return [
      for (var i = 0; i < topEntries.length; i++)
        CustomListItem(
          icon: topEntries[i].icon,
          iconColor: topEntries[i].iconColor,
          title: topEntries[i].title,
          subtitle: topEntries[i].subtitle,
          trailing: topEntries[i].trailing,
          showDivider: i < topEntries.length - 1,
        ),
    ];
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _ActivityEntry {
  final DateTime time;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  _ActivityEntry({
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
}

// Quick Prediction Section - Shows ML-based glucose prediction
class _QuickPredictionSection extends StatelessWidget {
  final Map<String, dynamic>? prediction;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _QuickPredictionSection({
    required this.prediction,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Glucose Forecast',
          subtitle: 'AI prediction for next 30 minutes',
          action: IconButton(
            onPressed: onRefresh,
            icon: Icon(
              isLoading ? Icons.hourglass_empty : Icons.refresh,
              size: 20,
              color: AppTheme.primaryBlue,
            ),
            tooltip: 'Refresh prediction',
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        BaseCard(
          child: isLoading
              ? _buildLoadingState()
              : prediction != null && prediction!['success'] == true
                  ? _buildPredictionContent()
                  : _buildErrorState(),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryBlue,
            strokeWidth: 2,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Analyzing glucose patterns...',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Prediction Unavailable',
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Need more glucose readings for accurate predictions',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionContent() {
    final pred = prediction!['prediction'];
    final currentGlucose = (pred['current_glucose'] ?? 0).toDouble();
    final predictedGlucose = (pred['glucose_mg_dl'] ?? 0).toDouble();
    final change = (pred['change'] ?? 0).toDouble();
    final trend = pred['trend'] ?? 'stable';
    final riskAssessment = pred['risk_assessment'];
    
    // Get trend info
    IconData trendIcon;
    Color trendColor;
    String trendText;
    
    switch (trend) {
      case 'rising':
        trendIcon = Icons.trending_up;
        trendColor = AppTheme.warningOrange;
        trendText = 'Rising';
        break;
      case 'falling':
        trendIcon = Icons.trending_down;
        trendColor = AppTheme.primaryBlue;
        trendText = 'Falling';
        break;
      default:
        trendIcon = Icons.trending_flat;
        trendColor = AppTheme.successGreen;
        trendText = 'Stable';
    }

    return Column(
      children: [
        // Main prediction display
        Container(
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
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              // Current glucose
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currentGlucose.toInt()}',
                      style: AppTheme.displaySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getGlucoseColor(currentGlucose),
                      ),
                    ),
                    Text(
                      'mg/dL',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow and trend
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.1),
                  borderRadius: AppTheme.radiusS,
                ),
                child: Column(
                  children: [
                    Icon(
                      trendIcon,
                      color: trendColor,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      change > 0 ? '+${change.toInt()}' : '${change.toInt()}',
                      style: AppTheme.bodySmall.copyWith(
                        color: trendColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: AppTheme.spacingM),
              
              // Predicted glucose
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'In 30 min',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${predictedGlucose.toInt()}',
                      style: AppTheme.displaySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getGlucoseColor(predictedGlucose),
                      ),
                    ),
                    Text(
                      'mg/dL',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Risk assessment
        if (riskAssessment != null)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: _getRiskColor(riskAssessment['level']).withOpacity(0.1),
              border: Border(
                top: BorderSide(
                  color: _getRiskColor(riskAssessment['level']).withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getRiskIcon(riskAssessment['level']),
                  color: _getRiskColor(riskAssessment['level']),
                  size: 16,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    riskAssessment['message'] ?? 'Prediction available',
                    style: AppTheme.bodySmall.copyWith(
                      color: _getRiskColor(riskAssessment['level']),
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Model info
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.psychology_outlined,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'ML-powered prediction based on your patterns',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getRiskColor(String? level) {
    switch (level) {
      case 'high':
        return AppTheme.warningOrange;
      case 'low':
        return AppTheme.dangerRed;
      case 'extreme':
        return AppTheme.dangerRed;
      default:
        return AppTheme.successGreen;
    }
  }

  IconData _getRiskIcon(String? level) {
    switch (level) {
      case 'high':
      case 'low':
        return Icons.warning_amber_rounded;
      case 'extreme':
        return Icons.error_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }
}