import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';
import '../services/api_service.dart';

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  final ApiService _apiService = ApiService();
  
  String _selectedPeriod = '7d';
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _foodEntries = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Overview stats
  int _totalMeals = 0;
  double _avgEstimatedRise = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _apiService.init();
    _loadFoodEntries();
  }

  Future<void> _loadFoodEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final entries = await _apiService.getFoodEntries();
    
      final filteredEntries = _filterEntriesByPeriod(entries);
      
      setState(() {
        _foodEntries = filteredEntries;
        _calculateOverviewStats();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      print('Error loading food entries: $e');
    }
  }

  List<dynamic> _filterEntriesByPeriod(List<dynamic> entries) {
    final now = DateTime.now();
    DateTime cutoffDate;

    switch (_selectedPeriod) {
      case '24h':
        cutoffDate = now.subtract(const Duration(hours: 24));
        break;
      case '7d':
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case '1m':
        cutoffDate = now.subtract(const Duration(days: 30));
        break;
      case '3m':
        cutoffDate = now.subtract(const Duration(days: 90));
        break;
      default:
        cutoffDate = now.subtract(const Duration(days: 7));
    }

    return entries.where((entry) {
      try {
        final timestamp = DateTime.parse(entry['timestamp']);
        return timestamp.isAfter(cutoffDate);
      } catch (e) {
        return true; // Include entries with invalid timestamps
      }
    }).toList();
  }

  void _calculateOverviewStats() {
    _totalMeals = _foodEntries.length;
    
    if (_foodEntries.isNotEmpty) {
      double totalRise = 0;
      int validEntries = 0;
      
      for (var entry in _foodEntries) {
        // Try to get estimated_glucose_rise from entry
        var estimatedRise = entry['estimated_glucose_rise'];
        
        // If not available, estimate based on carbs from description
        if (estimatedRise == null) {
          final nutrition = _parseNutritionFromDescription(entry['description']);
          final carbs = nutrition['carbs'] ?? 0;
          // Rough estimate: 1g carbs ≈ 3-5 mg/dL rise, using 4 as average
          estimatedRise = carbs * 4;
        }
        
        if (estimatedRise != null && estimatedRise > 0) {
          totalRise += (estimatedRise as num).toDouble();
          validEntries++;
        }
      }
      
      _avgEstimatedRise = validEntries > 0 ? totalRise / validEntries : 0.0;
    } else {
      _avgEstimatedRise = 0.0;
    }
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    HapticFeedback.selectionClick();
    _loadFoodEntries();
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _deleteMeal(String entryId) async {
    try {
      await _apiService.deleteFoodEntry(entryId);
      _showSnackBar('Meal deleted successfully');
      _loadFoodEntries();
    } catch (e) {
      _showSnackBar('Failed to delete meal: $e');
    }
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

  List<dynamic> get _filteredEntries {
    var entries = List.from(_foodEntries);
    
    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      entries = entries.where((entry) {
        // Check food_name at entry level first
        final foodName = entry['food_name']?.toString().toLowerCase() ?? '';
        if (foodName.contains(query)) return true;
        
        // Then check items array
        final itemsText = (entry['items'] as List?)
            ?.map((item) => item['name']?.toString().toLowerCase() ?? '')
            .join(' ') ?? '';
        return itemsText.contains(query);
      }).toList();
    }
    
    // Apply meal type filter
    if (_selectedFilter != 'All') {
      entries = entries.where((entry) {
        final mealType = entry['meal_type']?.toString() ?? '';
        return mealType.toLowerCase() == _selectedFilter.toLowerCase();
      }).toList();
    }
    
    entries.sort((a, b) {
      try {
        final timeA = DateTime.parse(a['timestamp']);
        final timeB = DateTime.parse(b['timestamp']);
        return timeB.compareTo(timeA);
      } catch (e) {
        return 0;
      }
    });
    
    return entries;
  }

  String _getMealTypeLabel(String? mealType) {
    if (mealType == null) return 'Meal';
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      default:
        return mealType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadFoodEntries,
        color: AppTheme.primaryBlue,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorView()
                : _buildContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return SharedAppBar(
      title: 'Meals',
      showBackButton: false,
      showConnection: false,
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'Failed to load meals',
            style: AppTheme.titleMedium,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXL),
            child: Text(
              _errorMessage ?? 'Unknown error',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          ElevatedButton(
            onPressed: _loadFoodEntries,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXL,
                vertical: AppTheme.spacingM,
              ),
            ),
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewSection(),
          const SizedBox(height: AppTheme.spacingL),
          _buildPeriodSelector(),
          const SizedBox(height: AppTheme.spacingL),
          _buildSearchAndFilters(),
          const SizedBox(height: AppTheme.spacingL),
          _buildMealHistory(),
          const SizedBox(height: AppTheme.spacingL),
          _buildInsightsSection(),
          const SizedBox(height: 100), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Row(
            children: [
              Expanded(
                child: _buildOverviewStat(
                  label: 'Total meals',
                  value: _totalMeals.toString(),
                  unit: '',
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _buildOverviewStat(
                  label: 'Avg est. rise',
                  value: _avgEstimatedRise > 0
                      ? '+${_avgEstimatedRise.toStringAsFixed(0)}'
                      : '0',
                  unit: 'mg/dL',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat({
    required String label,
    required String value,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXS),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
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
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['24h', '7d', '1m', '3m'];
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.radiusM,
        border: Border.all(color: AppTheme.borderLight, width: 0.5),
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                  borderRadius: AppTheme.radiusS,
                ),
                child: Text(
                  period,
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

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search & Filters',
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search meals, ingredients...',
                  hintStyle: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: AppTheme.radiusM,
                    borderSide: BorderSide(color: AppTheme.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppTheme.radiusM,
                    borderSide: BorderSide(color: AppTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppTheme.radiusM,
                    borderSide: BorderSide(color: AppTheme.primaryBlue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingM,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: AppTheme.radiusM,
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Icon(
                Icons.tune,
                color: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),
        _buildFilterChips(),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Today', '7d', 'Breakfast', 'Lunch', 'Dinner', 'Low Impact', 'High Impact'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacingS),
            child: GestureDetector(
              onTap: () => _onFilterChanged(filter),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryBlue
                      : AppTheme.surface,
                  borderRadius: AppTheme.radiusM,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryBlue
                        : AppTheme.borderLight,
                  ),
                ),
                child: Text(
                  filter,
                  style: AppTheme.labelMedium.copyWith(
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
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

  Widget _buildMealHistory() {
    final filteredEntries = _filteredEntries;
    
    if (filteredEntries.isEmpty) {
      return _buildEmptyState();
    }
    
    // Group entries by date
    final groupedEntries = <String, List<dynamic>>{};
    for (var entry in filteredEntries) {
      try {
        final timestamp = DateTime.parse(entry['timestamp']);
        final dateKey = _isToday(timestamp) ? 'Today' : 
                       _isYesterday(timestamp) ? 'Yesterday' :
                       DateFormat('EEEE, MMM d').format(timestamp);
        
        groupedEntries.putIfAbsent(dateKey, () => []);
        groupedEntries[dateKey]!.add(entry);
      } catch (e) {
        // Skip entries with invalid timestamps
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'History',
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        ...groupedEntries.entries.map((group) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                child: Text(
                  group.key,
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...group.value.map((entry) => _buildMealCard(entry)),
            ],
          );
        }).toList(),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
           date.month == yesterday.month &&
           date.day == yesterday.day;
  }

  // Helper method to parse nutritional values from description
  Map<String, double> _parseNutritionFromDescription(String? description) {
    if (description == null || description.isEmpty) {
      return {'carbs': 0, 'protein': 0, 'fat': 0};
    }

    double totalCarbs = 0;
    double totalProtein = 0;
    double totalFat = 0;

    // Parse carbs (e.g., "30.0g carbs")
    final carbsRegex = RegExp(r'(\d+\.?\d*)\s*g?\s*carbs?', caseSensitive: false);
    final carbsMatches = carbsRegex.allMatches(description);
    for (var match in carbsMatches) {
      totalCarbs += double.tryParse(match.group(1) ?? '0') ?? 0;
    }

    // Parse protein (e.g., "20.0g protein")
    final proteinRegex = RegExp(r'(\d+\.?\d*)\s*g?\s*proteins?', caseSensitive: false);
    final proteinMatches = proteinRegex.allMatches(description);
    for (var match in proteinMatches) {
      totalProtein += double.tryParse(match.group(1) ?? '0') ?? 0;
    }

    // Parse fat (e.g., "15.0g fat")
    final fatRegex = RegExp(r'(\d+\.?\d*)\s*g?\s*fats?', caseSensitive: false);
    final fatMatches = fatRegex.allMatches(description);
    for (var match in fatMatches) {
      totalFat += double.tryParse(match.group(1) ?? '0') ?? 0;
    }

    return {'carbs': totalCarbs, 'protein': totalProtein, 'fat': totalFat};
  }

  Widget _buildMealCard(dynamic entry) {
    final timestamp = entry['timestamp'] != null
        ? DateTime.parse(entry['timestamp'])
        : DateTime.now();
    final timeStr = DateFormat('HH:mm').format(timestamp);
    
    // Try to get food_name from entry level first, then from items array
    String mealName;
    if (entry['food_name'] != null && entry['food_name'].toString().isNotEmpty) {
      mealName = entry['food_name'];
    } else {
      final items = entry['items'] as List? ?? [];
      mealName = items.isNotEmpty
          ? items.map((item) => item['food_name']).join(', ')
          : 'Unknown Meal';
    }
    
    final items = entry['items'] as List? ?? [];
    
    // Parse nutritional values from description field
    final nutrition = _parseNutritionFromDescription(entry['description']);
    
    // Try to get from direct fields first, then fall back to parsed values
    final totalCarbs = (entry['total_carbs_g'] ?? entry['total_carbs'] ?? nutrition['carbs'] ?? 0).toDouble();
    final totalProtein = (entry['total_protein_g'] ?? entry['total_protein'] ?? nutrition['protein'] ?? 0).toDouble();
    final totalFat = (entry['total_fat_g'] ?? entry['total_fat'] ?? nutrition['fat'] ?? 0).toDouble();
    final estimatedRise = entry['estimated_glucose_rise'];
    
    final mealType = _getMealTypeLabel(entry['meal_type']);
    final portionSize = items.isNotEmpty ? items[0]['portion_size'] ?? 'serving' : 'serving';
    
    final hasGlucoseLink = entry['linked_glucose_reading'] != null;
    final glucoseData = entry['linked_glucose_reading'];
    
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal header
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: AppTheme.radiusM,
                ),
                child: Icon(
                  Icons.restaurant,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mealName,
                      style: AppTheme.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeStr • Est. ${estimatedRise != null ? "+$estimatedRise" : "+0"} mg/dL',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // Nutritional info
          Row(
            children: [
              _buildNutrientBadge(
                label: portionSize,
                value: '',
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacingS),
              _buildNutrientBadge(
                label: 'Carbs',
                value: '${totalCarbs}g',
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: AppTheme.spacingS),
              _buildNutrientBadge(
                label: 'Protein',
                value: '${totalProtein}g',
                color: AppTheme.successGreen,
              ),
              const SizedBox(width: AppTheme.spacingS),
              _buildNutrientBadge(
                label: 'Fat',
                value: '${totalFat}g',
                color: AppTheme.warningOrange,
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // Nutrient bars
          Column(
            children: [
              _buildNutrientBar('Carbs', totalCarbs / 100, AppTheme.primaryBlue),
              const SizedBox(height: 4),
              _buildNutrientBar('Protein', totalProtein / 50, AppTheme.successGreen),
              const SizedBox(height: 4),
              _buildNutrientBar('Fat', totalFat / 50, AppTheme.warningOrange),
            ],
          ),
          
          if (hasGlucoseLink) ...[
            const SizedBox(height: AppTheme.spacingM),
            _buildGlucoseLink(glucoseData),
          ],
          
          const SizedBox(height: AppTheme.spacingM),
          
          // Action buttons
          Row(
            children: [
              if (hasGlucoseLink)
                Text(
                  'Linked: ${glucoseData['pre_meal'] ?? 0} → ${glucoseData['post_meal'] ?? 0} mg/dL',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showMealDetails(entry);
                },
                child: Text('View Details'),
              ),
              TextButton(
                onPressed: () {
                  // Edit
                  HapticFeedback.lightImpact();
                },
                child: Text('Edit'),
              ),
              TextButton(
                onPressed: () {
                  _showDeleteConfirmation(entry['id'].toString());
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                ),
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTheme.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTheme.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutrientBar(String label, double value, Color color) {
    final clampedValue = value.clamp(0.0, 1.0);
    
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: clampedValue,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlucoseLink(Map<String, dynamic>? glucoseData) {
    if (glucoseData == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.05),
        borderRadius: AppTheme.radiusM,
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.trending_up,
            color: AppTheme.primaryBlue,
            size: 16,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            'Post-meal glucose',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showMealDetails(dynamic entry) {
    final timestamp = entry['timestamp'] != null
        ? DateTime.parse(entry['timestamp'])
        : DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(timestamp);
    final timeStr = DateFormat('HH:mm').format(timestamp);
    
    // Get meal name
    String mealName;
    if (entry['food_name'] != null && entry['food_name'].toString().isNotEmpty) {
      mealName = entry['food_name'];
    } else {
      final items = entry['items'] as List? ?? [];
      mealName = items.isNotEmpty
          ? items.map((item) => item['food_name']).join(', ')
          : 'Unknown Meal';
    }
    
    // Parse nutritional values
    final nutrition = _parseNutritionFromDescription(entry['description']);
    final totalCarbs = (entry['total_carbs_g'] ?? entry['total_carbs'] ?? nutrition['carbs'] ?? 0).toDouble();
    final totalProtein = (entry['total_protein_g'] ?? entry['total_protein'] ?? nutrition['protein'] ?? 0).toDouble();
    final totalFat = (entry['total_fat_g'] ?? entry['total_fat'] ?? nutrition['fat'] ?? 0).toDouble();
    final estimatedRise = entry['estimated_glucose_rise'];
    
    final description = entry['description'] ?? '';
    final mealType = _getMealTypeLabel(entry['meal_type']);
    final hasGlucoseLink = entry['linked_glucose_reading'] != null;
    final glucoseData = entry['linked_glucose_reading'];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: AppTheme.radiusL,
                            ),
                            child: Icon(
                              Icons.restaurant,
                              color: AppTheme.primaryBlue,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mealName,
                                  style: AppTheme.titleLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$mealType • $dateStr',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  timeStr,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingXL),
                      
                      // Glucose Impact
                      BaseCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Glucose Impact',
                              style: AppTheme.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingL),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
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
                                        estimatedRise != null 
                                            ? '+${estimatedRise.toStringAsFixed(0)} mg/dL'
                                            : '+${(totalCarbs * 4).toStringAsFixed(0)} mg/dL',
                                        style: AppTheme.headlineSmall.copyWith(
                                          color: AppTheme.primaryBlue,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasGlucoseLink) ...[
                                  const SizedBox(width: AppTheme.spacingL),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Actual Rise',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '+${((glucoseData['post_meal'] ?? 0) - (glucoseData['pre_meal'] ?? 0))} mg/dL',
                                          style: AppTheme.headlineSmall.copyWith(
                                            color: AppTheme.successGreen,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (hasGlucoseLink) ...[
                              const SizedBox(height: AppTheme.spacingL),
                              const Divider(),
                              const SizedBox(height: AppTheme.spacingM),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pre-meal',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${glucoseData['pre_meal'] ?? 0} mg/dL',
                                        style: AppTheme.titleMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: AppTheme.textSecondary,
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Post-meal',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${glucoseData['post_meal'] ?? 0} mg/dL',
                                        style: AppTheme.titleMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      
                      // Nutritional Information
                      BaseCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nutritional Information',
                              style: AppTheme.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingL),
                            _buildDetailNutrientRow('Carbohydrates', totalCarbs, 'g', AppTheme.primaryBlue),
                            const SizedBox(height: AppTheme.spacingM),
                            _buildDetailNutrientRow('Protein', totalProtein, 'g', AppTheme.successGreen),
                            const SizedBox(height: AppTheme.spacingM),
                            _buildDetailNutrientRow('Fat', totalFat, 'g', AppTheme.warningOrange),
                            const SizedBox(height: AppTheme.spacingM),
                            _buildDetailNutrientRow('Total Calories', 
                              (totalCarbs * 4 + totalProtein * 4 + totalFat * 9), 
                              'kcal', AppTheme.textPrimary),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      
                      // Description
                      if (description.isNotEmpty) ...[
                        BaseCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Description',
                                style: AppTheme.titleMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingM),
                              Text(
                                description,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                      ],
                      
                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                HapticFeedback.lightImpact();
                                // TODO: Implement edit functionality
                              },
                              icon: Icon(Icons.edit_outlined),
                              label: Text('Edit Meal'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                                side: BorderSide(color: AppTheme.primaryBlue),
                                foregroundColor: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingM),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showDeleteConfirmation(entry['id'].toString());
                              },
                              icon: Icon(Icons.delete_outline),
                              label: Text('Delete'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                                side: BorderSide(color: AppTheme.errorRed),
                                foregroundColor: AppTheme.errorRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingXL),
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

  Widget _buildDetailNutrientRow(String label, double value, String unit, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} $unit',
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(String entryId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Meal'),
        content: Text('Are you sure you want to delete this meal entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMeal(entryId);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return BaseCard(
      child: Column(
        children: [
          Icon(
            Icons.restaurant_outlined,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No meals logged yet',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Start by scanning food to log your first meal.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXL),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to scan screen
              HapticFeedback.lightImpact();
            },
            icon: Icon(Icons.camera_alt),
            label: Text('Scan Food'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXL,
                vertical: AppTheme.spacingM,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildInsightTile(
            icon: Icons.thumb_up_outlined,
            title: 'Good choices this week',
            subtitle: '3 low-impact meals helped keep you in range.',
            iconColor: AppTheme.successGreen,
          ),
          const Divider(height: AppTheme.spacingL),
          _buildInsightTile(
            icon: Icons.lightbulb_outlined,
            title: 'Tip',
            subtitle: 'Add veggies to rice dishes to moderate glucose rise.',
            iconColor: AppTheme.warningOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: AppTheme.radiusS,
          ),
          child: Icon(icon, color: iconColor, size: 20),
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
              const SizedBox(height: 4),
              Text(
                subtitle,
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}