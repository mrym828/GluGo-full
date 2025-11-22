import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';
import '../models/glucose_reading.dart';

class AllReadingsPage extends StatelessWidget {
  final List<GlucoseReading> readings;

  const AllReadingsPage({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: SharedAppBar(
        title: 'All Glucose Readings',
        showConnection: true,
        showBackButton: true,
      ),
      body: readings.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              itemCount: readings.length,
              itemBuilder: (context, index) {
                final reading = readings[index];
                final isLast = index == readings.length - 1;
                return _ReadingItem(
                  reading: reading,
                  showDivider: !isLast,
                );
              },
            ),
    );
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
              'Start logging your glucose readings to see them here',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reading Item Widget for All Readings Page
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
    final timeDisplay = _getDetailedTimeDisplay(reading.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: CustomListItem(
        icon: Icons.bloodtype_rounded,
        iconColor: glucoseColor,
        title: '${reading.value.toInt()} mg/dL',
        subtitle: timeDisplay,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(
              label: glucoseStatus,
              color: glucoseColor,
            ),
            const SizedBox(height: 4),
            Text(
              _getDateDisplay(reading.timestamp),
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
        showDivider: showDivider,
      ),
    );
  }

  String _getDetailedTimeDisplay(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (timestamp.isAfter(today)) {
    final hour = timestamp.hour;
    final minute = timestamp.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
    }
    else if (timestamp.isAfter(yesterday) && timestamp.isBefore(today)) {
    final hour = timestamp.hour;
    final minute = timestamp.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return 'Yesterday ${displayHour}:${minute.toString().padLeft(2, '0')} $period';
    }
    else {
    final hour = timestamp.hour;
    final minute = timestamp.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final month = timestamp.month;
    final day = timestamp.day;
    final year = timestamp.year.toString().substring(2); // Last 2 digits of year
    
    return '$month/$day/$year ${displayHour}:${minute.toString().padLeft(2, '0')} $period';
    }
  }

  String _getDateDisplay(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));
    
    if (timestamp.isAfter(today)) {
      return 'Today';
    } else if (timestamp.isAfter(yesterday) && timestamp.isBefore(today)) {
      return 'Yesterday';
    } else if(timestamp.isAfter(weekAgo)){
      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday','Sunday'];
      return days[timestamp.weekday - 1];
    } else {
    return '${timestamp.month}/${timestamp.day}/${timestamp.year.toString().substring(2)}';
    }
  }}