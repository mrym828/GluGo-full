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

  bool _isEditingProfile = false;
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String? _selectedGender;
  String? _selectedDiabetesType;

  final bool _isEditingTargetRange = false;
  final TextEditingController _targetMinController = TextEditingController();
  final TextEditingController _targetMaxController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
    _loadUserProfile();

    _fullNameController.addListener(() {});
    _ageController.addListener(() {});
    _weightController.addListener(() {});
    _targetMinController.addListener(() {});
    _targetMaxController.addListener(() {});
  }

  void _toggleEditProfile() {
    if (_isEditingProfile) {
      // Cancel editing
      _isEditingProfile = false;
      _clearControllers();
    } else {
      // Start editing - populate controllers with current data
      _isEditingProfile = true;
      _populateControllers();
    }
    setState(() {});
  }

  void _populateControllers() {
  _fullNameController.text = _userProfile?['full_name'] ?? '';
  _ageController.text = _userProfile?['age']?.toString() ?? '';
  _weightController.text = _userProfile?['weight_kg']?.toString() ?? '';
  _selectedGender = _userProfile?['gender'] ?? 'M';
  _selectedDiabetesType = _userProfile?['diabetes_type'] ?? 'T1';
}

void _clearControllers() {
  _fullNameController.clear();
  _ageController.clear();
  _weightController.clear();
  _selectedGender = null;
  _selectedDiabetesType = null;
}

Future<void> _saveProfileChanges() async {
  try {
    setState(() {
      _isLoading = true;
    });

    final updateData = {
      'full_name': _fullNameController.text.trim(),
      if (_ageController.text.isNotEmpty) 'age': int.tryParse(_ageController.text),
      if (_weightController.text.isNotEmpty) 'weight_kg': double.tryParse(_weightController.text),
      if (_selectedGender != null) 'gender': _selectedGender,
      if (_selectedDiabetesType != null) 'diabetes_type': _selectedDiabetesType,
    };

    updateData.removeWhere((key, value) => value == null);

    await _apiService.updateProfile(updateData);
    
    // Refresh profile data
    await _loadUserProfile();
    
    // Exit edit mode
    _isEditingProfile = false;
    _clearControllers();
    
    if (mounted) {
      _showSnackBar('Profile updated successfully');
    }
  } catch (e) {
    print('Error updating profile: $e');
    if (mounted) {
      _showSnackBar('Failed to update profile', isSuccess: false);
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
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
    _fullNameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
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

  void _showEditCarbRatioDialog(){
    final currentRatio = _userProfile?['insulin_to_carb_ratio']?.toString()??'';
    final TextEditingController controller = TextEditingController(text: currentRatio);

    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusL),
        title: Row(children: [
          Icon(Icons.insights_rounded, color: AppTheme.primaryBlue),
          const SizedBox(width: AppTheme.spacingM),
          const Text('Edit Insulin to Carb Ratio'),
        ],),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter your insulin to carb ratio: ', style: AppTheme.bodyMedium,),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: controller,
            decoration: InputDecoration(
              labelText: 'Units per 15g carbs',
              hintText: 'e.g., 1.5',
              border: OutlineInputBorder(
                borderRadius: AppTheme.radiusM,
                borderSide: BorderSide(color: AppTheme.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppTheme.radiusM,
                borderSide: BorderSide(color: AppTheme.primaryBlue),
              ),
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppTheme.spacingS),
          Text(
            'Example: 1 unit of insulin for every 15g of carbs',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          ],
        ), actions: [
          TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
          ),
          ElevatedButton(
          onPressed: () async {
            final newRatio = controller.text.trim();
            if (newRatio.isNotEmpty) {
              Navigator.pop(context);
              await _updateCarbRatio(double.tryParse(newRatio));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
          ),
          child: const Text('Save'),
          ),
        ],
        ),
      );
  }

  void _showEditCorrectionFactorDialog() {
  final currentFactor = _userProfile?['correction_factor']?.toString() ?? '';
  final TextEditingController controller = TextEditingController(text: currentFactor);
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusL),
      title: Row(
        children: [
          Icon(Icons.trending_down_rounded, color: AppTheme.primaryBlue),
          const SizedBox(width: AppTheme.spacingM),
          const Text('Edit Correction Factor'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your correction factor:',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.spacingM),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Points per unit',
              hintText: 'e.g., 50',
              border: OutlineInputBorder(
                borderRadius: AppTheme.radiusM,
                borderSide: BorderSide(color: AppTheme.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppTheme.radiusM,
                borderSide: BorderSide(color: AppTheme.primaryBlue),
              ),
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Example: 1 unit lowers glucose by 50 mg/dL',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
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
          onPressed: () async {
            final newFactor = controller.text.trim();
            if (newFactor.isNotEmpty) {
              Navigator.pop(context);
              await _updateCorrectionFactor(double.tryParse(newFactor));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
          ),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Update carb ratio via API
Future<void> _updateCarbRatio(double? newRatio) async {
  if (newRatio == null) return;
  
  try {
    setState(() {
      _isLoading = true;
    });
    
    await _apiService.updateProfile({
      'insulin_to_carb_ratio': newRatio,
    });
    
    // Refresh profile data
    await _loadUserProfile();
    
    if (mounted) {
      _showSnackBar('Insulin to carb ratio updated successfully');
    }
  } catch (e) {
    print('Error updating carb ratio: $e');
    if (mounted) {
      _showSnackBar('Failed to update ratio', isSuccess: false);
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

/// Update correction factor via API
Future<void> _updateCorrectionFactor(double? newFactor) async {
  if (newFactor == null) return;
  
  try {
    setState(() {
      _isLoading = true;
    });
    
    await _apiService.updateProfile({
      'correction_factor': newFactor,
    });
    
    // Refresh profile data
    await _loadUserProfile();
    
    if (mounted) {
      _showSnackBar('Correction factor updated successfully');
    }
  } catch (e) {
    print('Error updating correction factor: $e');
    if (mounted) {
      _showSnackBar('Failed to update correction factor', isSuccess: false);
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

double _getYearsSinceDiagnosis() {
  if (_userProfile == null || _userProfile!['diagnoses_year'] == null) {
    return 0;
  }
  final diagnosisYear = _userProfile!['diagnoses_year'] as int;
  final now = DateTime.now();
  final diagnosisDate = DateTime(diagnosisYear, 1, 1);
  final days = now.difference(diagnosisDate).inDays;
  return (days / 365.25); 
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
                  if (!_isEditingProfile) ...[
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
                  ] else ...[
                    // Edit mode - Name field
                    TextField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.radiusS,
                          borderSide: BorderSide(color: AppTheme.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppTheme.radiusS,
                          borderSide: BorderSide(color: AppTheme.primaryBlue),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS,
                        ),
                      ),
                      style: AppTheme.titleSmall,
                    ),
                  ],
                ],
              ),
            ),
            // Edit/Save/Cancel button
            _isEditingProfile
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _saveProfileChanges,
                        icon: Container(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withOpacity(0.1),
                            borderRadius: AppTheme.radiusS,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: AppTheme.successGreen,
                            size: 18,
                          ),
                        ),
                        tooltip: 'Save changes',
                      ),
                      IconButton(
                        onPressed: _toggleEditProfile,
                        icon: Container(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withOpacity(0.1),
                            borderRadius: AppTheme.radiusS,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppTheme.errorRed,
                            size: 18,
                          ),
                        ),
                        tooltip: 'Cancel',
                      ),
                    ],
                  )
                : IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _toggleEditProfile();
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
                    tooltip: 'Edit profile',
                  ),
          ],
        ),
        
        // Edit mode fields
        if (_isEditingProfile) ...[
          const SizedBox(height: AppTheme.spacingL),
          _buildEditFields(),
        ],
        
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
                label: 'Years with Diabetes',
                value: _getYearsSinceDiagnosis() > 0 
                    ? _getYearsSinceDiagnosis().toStringAsFixed(1)
                    : '--',
                icon: Icons.medical_services_rounded,
                color: AppTheme.primaryBlue,
              ),
            ),
            Container(
              width: 1,
              height: 48,
              color: AppTheme.borderLight,
            ),
            Expanded(
              child: _isEditingProfile
                  ? _EditableStatItem(
                      controller: _ageController,
                      label: 'Age',
                      icon: Icons.cake_rounded,
                      color: AppTheme.successGreen,
                      inputType: TextInputType.number,
                    )
                  : _ProfileStatItem(
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
              child: _isEditingProfile
                  ? _EditableStatItem(
                      controller: _weightController,
                      label: 'Weight',
                      icon: Icons.monitor_weight_rounded,
                      color: AppTheme.mealColor,
                      inputType: TextInputType.numberWithOptions(decimal: true),
                      suffix: 'kg',
                    )
                  : _ProfileStatItem(
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

Widget _buildEditFields() {
  return Column(
    children: [
      // Diabetes Type Selector
      Row(
        children: [
          Icon(Icons.favorite_rounded, color: AppTheme.primaryBlue, size: 16),
          const SizedBox(width: AppTheme.spacingM),
          Text('Diabetes Type:', style: AppTheme.titleSmall),
          const Spacer(),
          _buildDiabetesTypeSelector(),
        ],
      ),
      const SizedBox(height: AppTheme.spacingM),
      
      // Gender Selector
      Row(
        children: [
          Icon(Icons.person_rounded, color: AppTheme.successGreen, size: 16),
          const SizedBox(width: AppTheme.spacingM),
          Text('Gender:', style: AppTheme.titleSmall),
          const Spacer(),
          _buildGenderSelector(),
        ],
      ),
    ],
  );
}

Widget _buildDiabetesTypeSelector() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
    decoration: BoxDecoration(
      color: AppTheme.primaryBlue.withOpacity(0.1),
      borderRadius: AppTheme.radiusM,
    ),
    child: DropdownButton<String>(
      value: _selectedDiabetesType,
      onChanged: (String? newValue) {
        setState(() {
          _selectedDiabetesType = newValue;
        });
      },
      items: const [
        DropdownMenuItem(value: 'T1', child: Text('Type 1')),
        DropdownMenuItem(value: 'T2', child: Text('Type 2')),
      ],
      underline: const SizedBox(),
      icon: Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primaryBlue),
      dropdownColor: Colors.white,
      borderRadius: AppTheme.radiusM,
    ),
  );
}

Widget _buildGenderSelector() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
    decoration: BoxDecoration(
      color: AppTheme.successGreen.withOpacity(0.1),
      borderRadius: AppTheme.radiusM,
    ),
    child: DropdownButton<String>(
      value: _selectedGender,
      onChanged: (String? newValue) {
        setState(() {
          _selectedGender = newValue;
        });
      },
      items: const [
        DropdownMenuItem(value: 'M', child: Text('Male')),
        DropdownMenuItem(value: 'F', child: Text('Female')),
      ],
      underline: const SizedBox(),
      icon: Icon(Icons.arrow_drop_down_rounded, color: AppTheme.successGreen),
      dropdownColor: Colors.white,
      borderRadius: AppTheme.radiusM,
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
            // Target Glucose Range - Editable
            _buildTargetGlucoseTile(targetRange, targetMin, targetMax),
            
            // LibreView Connection
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
          ],
        ),
      ),
    ],
  );
}

Widget _buildTargetGlucoseTile(String targetRange, dynamic targetMin, dynamic targetMax) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _showEditTargetRangeDialog(targetMin, targetMax);
      },
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                borderRadius: AppTheme.radiusS,
              ),
              child: Icon(
                Icons.trending_up_rounded,
                color: AppTheme.successGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spacingL),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Target Glucose Range',
                    style: AppTheme.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your ideal blood sugar levels',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  targetRange,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: AppTheme.radiusS,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void _showEditTargetRangeDialog(dynamic currentMin, dynamic currentMax) {
  _targetMinController.text = currentMin?.toString() ?? '70';
  _targetMaxController.text = currentMax?.toString() ?? '180';
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusL),
      title: Row(
        children: [
          Icon(Icons.trending_up_rounded, color: AppTheme.primaryBlue),
          const SizedBox(width: AppTheme.spacingM),
          const Text('Target Glucose Range'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Set your ideal blood glucose range (mg/dL):',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _targetMinController,
                  decoration: InputDecoration(
                    labelText: 'Minimum',
                    hintText: '70',
                    border: OutlineInputBorder(
                      borderRadius: AppTheme.radiusM,
                      borderSide: BorderSide(color: AppTheme.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppTheme.radiusM,
                      borderSide: BorderSide(color: AppTheme.primaryBlue),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Text(
                'to',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: TextField(
                  controller: _targetMaxController,
                  decoration: InputDecoration(
                    labelText: 'Maximum',
                    hintText: '180',
                    border: OutlineInputBorder(
                      borderRadius: AppTheme.radiusM,
                      borderSide: BorderSide(color: AppTheme.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppTheme.radiusM,
                      borderSide: BorderSide(color: AppTheme.primaryBlue),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.05),
              borderRadius: AppTheme.radiusM,
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, 
                    color: AppTheme.primaryBlue, size: 16),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Text(
                    'Typical range: 70-180 mg/dL for most adults with diabetes',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
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
          onPressed: () async {
            final min = int.tryParse(_targetMinController.text);
            final max = int.tryParse(_targetMaxController.text);
            
            if (min == null || max == null) {
              _showSnackBar('Please enter valid numbers', isSuccess: false);
              return;
            }
            
            if (min >= max) {
              _showSnackBar('Minimum must be less than maximum', isSuccess: false);
              return;
            }
            
            Navigator.pop(context);
            await _updateTargetRange(min, max);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
          ),
          child: const Text('Save Range'),
        ),
      ],
    ),
  );
}

Future<void> _updateTargetRange(int min, int max) async {
  try {
    setState(() {
      _isLoading = true;
    });
    
    await _apiService.updateProfile({
      'target_glucose_min': min,
      'target_glucose_max': max,
    });
    
    // Refresh profile data
    await _loadUserProfile();
    
    if (mounted) {
      _showSnackBar('Target range updated to $min-$max mg/dL');
    }
  } catch (e) {
    print('Error updating target range: $e');
    if (mounted) {
      _showSnackBar('Failed to update target range', isSuccess: false);
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
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
      Row(
        children: [
          Text(
            'Insulin Settings',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showEditInsulinSettingsInfo();
            },
            icon: Icon(
              Icons.info_outline_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            tooltip: 'Learn about insulin settings',
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacingM),
      BaseCard(
        child: Column(
          children: [
            _buildEditableInsulinRatioRow(
              'Insulin to Carb Ratio',
              _userProfile?['insulin_to_carb_ratio'],
              'Units per 15g carbs',
              onTap: _showEditCarbRatioDialog,
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildEditableInsulinRatioRow(
              'Correction Factor',
              _userProfile?['correction_factor'],
              'Points per unit',
              onTap: _showEditCorrectionFactorDialog,
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildEditableInsulinRatioRow(String label, dynamic value, String unit, {required VoidCallback onTap}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: AppTheme.radiusM,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS, horizontal: AppTheme.spacingS),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTheme.titleSmall),
                  Text(unit, style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  )),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  value?.toString() ?? 'Not Set',
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: value != null ? AppTheme.primaryBlue : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Icon(
                  Icons.edit_rounded,
                  color: AppTheme.textTertiary,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void _showEditInsulinSettingsInfo() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusL),
      title: Row(
        children: [
          Icon(Icons.insights_rounded, color: AppTheme.primaryBlue),
          const SizedBox(width: AppTheme.spacingM),
          const Text('Insulin Settings Guide'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoItem(
            'Insulin to Carb Ratio',
            'How many units of insulin you need for 15g of carbohydrates.\nExample: 1.5 means 1.5 units per 15g carbs',
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildInfoItem(
            'Correction Factor',
            'How much 1 unit of insulin lowers your blood glucose.\nExample: 50 means 1 unit lowers by 50 mg/dL',
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Tap on any setting to edit it.',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
          ),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

Widget _buildInfoItem(String title, String description) {
  return Column(
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
        description,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.textSecondary,
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

class _EditableStatItem extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color color;
  final TextInputType inputType;
  final String? suffix;

  const _EditableStatItem({
    required this.controller,
    required this.label,
    required this.icon,
    required this.color,
    required this.inputType,
    this.suffix,
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
        SizedBox(
          width: 60,
          height: 32,
          child: TextField(
            controller: controller,
            keyboardType: inputType,
            textAlign: TextAlign.center,
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: AppTheme.radiusS,
                borderSide: BorderSide(color: color.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppTheme.radiusS,
                borderSide: BorderSide(color: color),
              ),
              hintText: '--',
              hintStyle: AppTheme.titleSmall.copyWith(
                color: AppTheme.textSecondary,
              ),
              suffix: suffix != null 
                  ? Text(
                      suffix!,
                      style: AppTheme.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
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
