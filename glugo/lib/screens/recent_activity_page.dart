import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';
import '../services/api_service.dart';

class RecentActivityPage extends StatefulWidget {
  const RecentActivityPage({super.key});

  @override
  State<RecentActivityPage> createState() => _RecentActivityPageState();
}

class _RecentActivityPageState extends State<RecentActivityPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _allActivities = [];
  final DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAllActivities();
  }

  Future<void> _loadAllActivities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.init();
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      // Load both glucose records and food entries
      final [glucoseRecords, foodEntries] = await Future.wait([
        _apiService.getGlucoseRecords(
          startDate: startOfDay,
          endDate: endOfDay,
          limit: 100, // Load more records
        ),
        _apiService.getFoodEntries(
          startDate: startOfDay,
          endDate: endOfDay,
        ),
      ]);

      // Combine and sort all activities by timestamp
      final allActivities = <Map<String, dynamic>>[];

      // Add glucose records
      for (final record in glucoseRecords) {
        if (record['timestamp'] != null && record['glucose_level'] != null) {
          allActivities.add({
            'type': 'glucose',
            'timestamp': record['timestamp'],
            'data': record,
          });
        }
      }

      // Add food entries
      for (final entry in foodEntries) {
        if (entry['timestamp'] != null) {
          allActivities.add({
            'type': 'food',
            'timestamp': entry['timestamp'],
            'data': entry,
          });
        }
      }

      // Sort by timestamp (newest first)
      allActivities.sort((a, b) {
        final aTime = DateTime.parse(a['timestamp']);
        final bTime = DateTime.parse(b['timestamp']);
        return bTime.compareTo(aTime);
      });

      setState(() {
        _allActivities = allActivities;
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading all activities: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: const SharedAppBar(
        title: 'Recent Activity',
        showBackButton: true,
        showConnection: true,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _allActivities.isEmpty
              ? _buildEmptyState()
              : _buildActivityList(),
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
            'Loading your activity...',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No Activity Today',
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Your glucose readings and meal logs will appear here',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXL),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    return RefreshIndicator(
      onRefresh: _loadAllActivities,
      color: AppTheme.primaryBlue,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        itemCount: _allActivities.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacingM),
        itemBuilder: (context, index) {
          final activity = _allActivities[index];
          final type = activity['type'];
          final data = activity['data'];
          
          return _buildActivityItem(type, data);
        },
      ),
    );
  }

  Widget _buildActivityItem(String type, Map<String, dynamic> data) {
    if (type == 'glucose') {
      return _buildGlucoseActivityItem(data);
    } else {
      return _buildFoodActivityItem(data);
    }
  }

  Widget _buildGlucoseActivityItem(Map<String, dynamic> record) {
    final glucose = record['glucose_level']?.toDouble() ?? 0.0;
    final timestampStr = record['timestamp'];
    final source = record['source'] ?? 'manual';
    
    String timeStr = 'Recently';
    if (timestampStr != null) {
      try {
        final timestamp = DateTime.parse(timestampStr);
        timeStr = '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        print('Error parsing timestamp: $e');
      }
    }

    return BaseCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: AppTheme.getGlucoseColor(glucose).withOpacity(0.1),
              borderRadius: AppTheme.radiusS,
            ),
            child: Icon(
              source == 'libre' ? Icons.cloud_sync_rounded : Icons.bloodtype_rounded,
              color: AppTheme.getGlucoseColor(glucose),
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Glucose Reading',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${glucose.toInt()} mg/dL • $timeStr • ${source == 'libre' ? 'Libre' : 'Manual'}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: AppTheme.getGlucoseStatus(glucose),
            color: AppTheme.getGlucoseColor(glucose),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodActivityItem(Map<String, dynamic> entry) {
    final foodName = entry['food_name'] ?? 'Meal';
    final timestampStr = entry['timestamp'];
    final mealType = entry['meal_type'] ?? 'Meal';
    final carbs = entry['nutritional_info']?['carbs']?.toInt() ?? 0;
    
    String timeStr = 'Recently';
    if (timestampStr != null) {
      try {
        final timestamp = DateTime.parse(timestampStr);
        timeStr = '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        print('Error parsing timestamp: $e');
      }
    }

    return BaseCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: AppTheme.mealColor.withOpacity(0.1),
              borderRadius: AppTheme.radiusS,
            ),
            child: Icon(
              Icons.restaurant_rounded,
              color: AppTheme.mealColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$mealType Logged',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$foodName${carbs > 0 ? ' • ${carbs}g carbs' : ''} • $timeStr',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: 'Logged',
            color: AppTheme.successGreen,
          ),
        ],
      ),
    );
  }
}