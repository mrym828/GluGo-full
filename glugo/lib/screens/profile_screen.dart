import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/shared_components.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // API Service and data state
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
    _loadUserProfile();
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

  /// Load user profile from backend
  Future<void> _loadUserProfile() async {
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

      // Fetch user profile
      final profile = await _apiService.getProfile();
      
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load profile. Using cached data if available.';
        });
        
        // Try to use cached profile
        if (_apiService.cachedProfile != null) {
          setState(() {
            _userProfile = _apiService.cachedProfile;
          });
        } else {
          _showSnackBar('Failed to load profile', isSuccess: false);
        }
      }
    }
  }

  /// Handle logout
  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusL),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.primaryBlue),
            const SizedBox(width: AppTheme.spacingM),
            const Text('Log Out'),
          ],
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Perform logout
        await _apiService.logout();
        
        if (mounted) {
          // Navigate to login screen
          Navigator.pushReplacementNamed(context, '/auth');
        }
      } catch (e) {
        print('Logout error: $e');
        _showSnackBar('Error during logout', isSuccess: false);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppTheme.successGreen : AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusM),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusL),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.errorRed),
            const SizedBox(width: AppTheme.spacingM),
            const Text('Delete Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is permanent and cannot be undone.',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'All your data will be permanently deleted:',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingS),
            _buildDeleteItem('All glucose readings'),
            _buildDeleteItem('All food entries'),
            _buildDeleteItem('Profile information'),
            _buildDeleteItem('Connected devices'),
            _buildDeleteItem('Health records'),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Are you absolutely sure?',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.errorRed,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleDeleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.spacingM, top: 4),
      child: Row(
        children: [
          Icon(Icons.close, size: 16, color: AppTheme.errorRed),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// Handle account deletion
  Future<void> _handleDeleteAccount() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.radiusL,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.errorRed),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  'Deleting account...',
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Call API to delete account
      await _apiService.deleteAccount();
      
      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);
        
        // Navigate to login screen
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
          (route) => false,
        );
        
        // Show success message
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.white),
                    const SizedBox(width: AppTheme.spacingM),
                    const Expanded(
                      child: Text('Account deleted successfully'),
                    ),
                  ],
                ),
                backgroundColor: AppTheme.errorRed,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.radiusM,
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        });
      }
    } catch (e) {
      print('Error deleting account: $e');
      
      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);
        
        // Show error message
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusL),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.errorRed),
                const SizedBox(width: AppTheme.spacingM),
                const Text('Delete Failed'),
              ],
            ),
            content: Text(
              'Failed to delete account. Please try again or contact support if the problem persists.\n\nError: ${e.toString()}',
              style: AppTheme.bodyMedium,
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Helper method to get diabetes type display text
  String _getDiabetesTypeDisplay() {
    if (_userProfile == null) return 'Not Set';
    final type = _userProfile!['diabetes_type'];
    if (type == 'T1') return 'Type 1';
    if (type == 'T2') return 'Type 2';
    return 'Not Set';
  }

  /// Helper method to get gender display text
  String _getGenderDisplay() {
    if (_userProfile == null) return 'Not Set';
    final gender = _userProfile!['gender'];
    if (gender == 'M') return 'Male';
    if (gender == 'F') return 'Female';
    return 'Not Set';
  }

  /// Calculate days since diagnosis
  int _getDaysActive() {
    if (_userProfile == null || _userProfile!['diagnoses_year'] == null) {
      return 0;
    }
    final diagnosisYear = _userProfile!['diagnoses_year'] as int;
    final now = DateTime.now();
    final diagnosisDate = DateTime(diagnosisYear, 1, 1);
    return now.difference(diagnosisDate).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryBlue),
                  const SizedBox(height: AppTheme.spacingL),
                  Text('Loading profile...', style: AppTheme.bodyMedium),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadUserProfile,
              color: AppTheme.primaryBlue,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingM),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange.withOpacity(0.1),
                              borderRadius: AppTheme.radiusM,
                              border: Border.all(color: AppTheme.warningOrange),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: AppTheme.warningOrange),
                                const SizedBox(width: AppTheme.spacingM),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AppTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingL),
                        ],
                        _buildUserProfileCard(),
                        const SizedBox(height: AppTheme.spacingXL),
                        _buildAccountSection(),
                        const SizedBox(height: AppTheme.spacingXL),
                        _buildHealthSettingsSection(),
                        const SizedBox(height: AppTheme.spacingXL),
                        _buildInsulinSettings(),
                        const SizedBox(height: AppTheme.spacingXL),
                        _buildLogoutSection(),
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
      actions: [
        IconButton(
          onPressed: () => _showSnackBar('Settings coming soon'),
          icon: const Icon(Icons.settings_rounded, color: Colors.white),
          tooltip: 'Settings',
        ),
      ],
    );
  }

  Widget _buildUserProfileCard() {
    final fullName = _userProfile?['full_name'] ?? 'User';
    final email = _userProfile?['email'] ?? 'No email';
    final username = _userProfile?['username'] ?? 'username';
    final diabetesType = _getDiabetesTypeDisplay();
    
    return BaseCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryBlue,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    child: Center(
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                        style: AppTheme.headlineMedium.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isNotEmpty ? fullName : username,
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Row(
                      children: [
                        StatusBadge(
                          label: diabetesType,
                          color: AppTheme.primaryBlue,
                          icon: Icons.favorite_rounded,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        if (_getGenderDisplay() != 'Not Set')
                          StatusBadge(
                            label: _getGenderDisplay(),
                            color: AppTheme.successGreen,
                            icon: Icons.person_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, '/profileset').then((_) {
                    _loadUserProfile(); // Refresh after edit
                  });
                },
                icon: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: AppTheme.radiusS,
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color: AppTheme.primaryBlue,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          Divider(
            color: AppTheme.borderLight,
            height: 1,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Row(
            children: [
              Expanded(
                child: _ProfileStatItem(
                  label: 'Days Active',
                  value: _getDaysActive().toString(),
                  icon: Icons.calendar_today_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: AppTheme.borderLight,
              ),
              Expanded(
                child: _ProfileStatItem(
                  label: 'Age',
                  value: _userProfile?['age']?.toString() ?? '--',
                  icon: Icons.cake_rounded,
                  color: AppTheme.successGreen,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: AppTheme.borderLight,
              ),
              Expanded(
                child: _ProfileStatItem(
                  label: 'Weight',
                  value: _userProfile?['weight_kg'] != null 
                      ? '${_userProfile!['weight_kg']} kg' 
                      : '--',
                  icon: Icons.monitor_weight_rounded,
                  color: AppTheme.mealColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Settings',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        BaseCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ProfileSettingTile(
                icon: Icons.notifications_rounded,
                iconColor: AppTheme.warningOrange,
                title: 'Notifications',
                subtitle: 'Manage alerts and reminders',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary,
                  size: 20,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showSnackBar('Notification settings coming soon');
                },
              ),
              _ProfileSettingTile(
                icon: Icons.privacy_tip_rounded,
                iconColor: AppTheme.textSecondary,
                title: 'Privacy & Security',
                subtitle: 'Data and account protection',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary,
                  size: 20,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showSnackBar('Privacy settings coming soon');
                },
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthSettingsSection() {
    final targetMin = _userProfile?['target_glucose_min'];
    final targetMax = _userProfile?['target_glucose_max'];
    final targetRange = (targetMin != null && targetMax != null)
        ? '$targetMin-$targetMax mg/dL'
        : '70-180 mg/dL';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Health Settings',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        BaseCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ProfileSettingTile(
                icon: Icons.trending_up_rounded,
                iconColor: AppTheme.successGreen,
                title: 'Target Glucose Range',
                subtitle: 'Your ideal blood sugar levels',
                trailing: Text(
                  targetRange,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, '/profile-setup').then((_) { //change to be edited in same page
                    _loadUserProfile();
                  });
                },
              ),
              FutureBuilder<Map<String, dynamic>>(
              future: _apiService.getLibreStatus(),
              builder: (context, snapshot) {
                final isConnected = snapshot.data?['is_connected'] ?? false;
                final email = snapshot.data?['email'] ?? 'Not connected';
                final lastSync = snapshot.data?['last_sync'];
                
                return _ProfileSettingTile(
                  icon: Icons.medical_services_rounded,
                  iconColor: isConnected ? AppTheme.successGreen : AppTheme.textSecondary,
                  title: 'LibreView',
                  subtitle: isConnected 
                    ? email 
                    : 'Connect for automatic glucose sync',
                  trailing: isConnected
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusBadge(
                            label: 'Connected',
                            color: AppTheme.successGreen,
                            icon: Icons.check_circle_rounded,
                          ),
                          if (lastSync != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Synced ${_formatLastSync(lastSync)}',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      )
                    : StatusBadge(
                        label: 'Not Connected',
                        color: AppTheme.textSecondary,
                        icon: Icons.link_off_rounded,
                      ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/device').then((_) {
                      setState(() {}); // Refresh to update status
                    });
                  },
                );
              },
            ),

              _ProfileSettingTile(
                icon: Icons.restaurant_rounded,
                iconColor: AppTheme.mealColor,
                title: 'Meal Preferences',
                subtitle: 'Dietary filters and cuisines',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary,
                  size: 20,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showSnackBar('Meal preferences coming soon');
                },
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatLastSync(dynamic lastSync) {
  try {
    final DateTime syncTime = DateTime.parse(lastSync.toString());
    final now = DateTime.now();
    final difference = now.difference(syncTime);
    
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  } catch (e) {
    return 'recently';
  }
}

  // Add a new section in the profile screen
Widget _buildInsulinSettings() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Insulin Settings',
        style: AppTheme.titleMedium.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: AppTheme.spacingM),
      BaseCard(
        child: Column(
          children: [
            _buildInsulinRatioRow(
              'Insulin to Carb Ratio',
              _userProfile?['insulin_to_carb_ratio'],
              'Units per 15g carbs',
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildInsulinRatioRow(
              'Correction Factor',
              _userProfile?['correction_factor'],
              'Points per unit',
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildInsulinRatioRow(String label, dynamic value, String unit) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.titleSmall),
          Text(unit, style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          )),
        ],
      ),
      Text(
        value?.toString() ?? 'Not Set',
        style: AppTheme.titleMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryBlue,
        ),
      ),
    ],
  );
}

  Widget _buildLogoutSection() {
    return Column(
      children: [
        BaseCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _handleLogout();
                  },
                  borderRadius: AppTheme.radiusL,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            borderRadius: AppTheme.radiusS,
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            color: AppTheme.primaryBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingL),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Log Out',
                                style: AppTheme.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sign out from this device',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textTertiary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingL),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.errorRed.withOpacity(0.05),
                AppTheme.errorRed.withOpacity(0.02),
              ],
            ),
            borderRadius: AppTheme.radiusL,
            border: Border.all(
              color: AppTheme.errorRed.withOpacity(0.2),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                _showDeleteAccountDialog();
              },
              borderRadius: AppTheme.radiusL,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_forever_rounded,
                      color: AppTheme.errorRed,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Text(
                      'Delete Account',
                      style: AppTheme.titleSmall.copyWith(
                        color: AppTheme.errorRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Profile Stat Item Widget
class _ProfileStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ProfileStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: AppTheme.radiusS,
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          value,
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// Profile Setting Tile Widget
class _ProfileSettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final bool showDivider;

  const _ProfileSettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListItem(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      showDivider: showDivider,
    );
  }
}