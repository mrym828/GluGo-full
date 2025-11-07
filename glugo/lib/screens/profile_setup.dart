import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';

class ProfileSetScreen extends StatefulWidget {
  const ProfileSetScreen({super.key});

  @override
  State<ProfileSetScreen> createState() => _ProfileSetScreenState();
}

class _ProfileSetScreenState extends State<ProfileSetScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService(); // Add API service

  // Step 1: Basic Info
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  String _gender = '';
  String _activityLevel = '';

  // Step 2: Diabetes Info
  String _diabetesType = '';
  final _diagnosisYearController = TextEditingController();
  String _medicationType = '';
  final _hba1cController = TextEditingController();
  bool _usesCGM = false;
  String _cgmBrand = '';

  // Step 3: Goals & Preferences
  final _targetGlucoseMinController = TextEditingController();
  final _targetGlucoseMaxController = TextEditingController();
  List<String> _selectedGoals = [];
  List<String> _selectedNotifications = [];

  final List<String> _availableGoals = [
    'Improve HbA1c levels',
    'Reduce glucose spikes',
    'Better meal planning',
    'Increase exercise consistency',
    'Weight management',
    'Better sleep patterns'
  ];

  final List<String> _availableNotifications = [
    'High glucose alerts',
    'Low glucose alerts',
    'Medication reminders',
    'Meal logging reminders',
    'Exercise reminders',
    'Weekly progress reports'
  ];

  @override
  void initState() {
    super.initState();
    _initializeApiService();
  }

  // Initialize API service and load saved tokens
  Future<void> _initializeApiService() async {
    await _apiService.init();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _diagnosisYearController.dispose();
    _hba1cController.dispose();
    _targetGlucoseMinController.dispose();
    _targetGlucoseMaxController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_validateStep1()) {
        setState(() => _currentStep++);
        HapticFeedback.lightImpact();
      }
    } else if (_currentStep == 1) {
      if (_validateStep2()) {
        setState(() => _currentStep++);
        HapticFeedback.lightImpact();
      }
    } else if (_currentStep == 2) {
      _completeSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      HapticFeedback.lightImpact();
    }
  }

  bool _validateStep1() {
    if (_ageController.text.isEmpty || _weightController.text.isEmpty ||
        _heightController.text.isEmpty || _gender.isEmpty) {
      _showSnackBar('Please fill in all required fields', isError: true);
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_diabetesType.isEmpty || _diagnosisYearController.text.isEmpty || _medicationType.isEmpty) {
      _showSnackBar('Please fill in all required fields', isError: true);
      return false;
    }
    return true;
  }

  void _completeSetup() async {
    if (_targetGlucoseMinController.text.isEmpty || _targetGlucoseMaxController.text.isEmpty) {
      _showSnackBar('Please set your target glucose range', isError: true);
      return;
    }
    
    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();
    
    try {
      // Prepare profile data
      final profileData = {
        'age': int.tryParse(_ageController.text),
        'weight_kg': double.tryParse(_weightController.text),
        'height_cm': double.tryParse(_heightController.text),
        'gender': _gender == 'Male' ? 'M' : (_gender == 'Female' ? 'F' : 'O'),
        'diabetes_type': _diabetesType == 'Type 1' ? 'T1' : (_diabetesType == 'Type 2' ? 'T2' : null),
        'diagnoses_year': int.tryParse(_diagnosisYearController.text),
        'preferred_med': _medicationType,
        'target_glucose_min': int.tryParse(_targetGlucoseMinController.text),
        'target_glucose_max': int.tryParse(_targetGlucoseMaxController.text),
      };

      // Remove null values
      profileData.removeWhere((key, value) => value == null);

      // Update profile via API
      await _apiService.updateProfile(profileData);
      
      setState(() => _isLoading = false);
      _showSnackBar('Profile setup completed successfully!', isError: false);
      
      // Navigate to home
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to save profile. Please try again.', isError: true);
      print('Profile update error: $e'); // Add debug logging
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue,
              const Color(0xFF8FB8FE),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Progress indicator
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 4,
                        decoration: BoxDecoration(
                          color: index <= _currentStep 
                              ? Colors.white 
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                "Setup Your Profile",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Step ${_currentStep + 1} of 3",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentStep == 0) _buildStep1(),
                          if (_currentStep == 1) _buildStep2(),
                          if (_currentStep == 2) _buildStep3(),
                          const SizedBox(height: 32),
                          _buildNavigationButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Basic Information", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        
        TextField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Age",
            hintText: "Enter your age",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 16),
        
        TextField(
          controller: _weightController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Weight (kg)",
            hintText: "Enter your weight",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 16),
        
        TextField(
          controller: _heightController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Height (cm)",
            hintText: "Enter your height",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 24),
        
        const Text("Gender", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildGenderButton("Male")),
            const SizedBox(width: 12),
            Expanded(child: _buildGenderButton("Female")),
            const SizedBox(width: 12),
            Expanded(child: _buildGenderButton("Other")),
          ],
        ),
        const SizedBox(height: 24),
        
        const Text("Activity Level (Optional)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        _buildActivityButton("Sedentary", "Little to no exercise"),
        const SizedBox(height: 8),
        _buildActivityButton("Moderate", "Exercise 3-4 times/week"),
        const SizedBox(height: 8),
        _buildActivityButton("Active", "Exercise 5+ times/week"),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Diabetes Information", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        
        const Text("Diabetes Type", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildDiabetesTypeButton("Type 1")),
            const SizedBox(width: 12),
            Expanded(child: _buildDiabetesTypeButton("Type 2")),
          ],
        ),
        const SizedBox(height: 24),
        
        TextField(
          controller: _diagnosisYearController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Year of Diagnosis",
            hintText: "e.g., 2020",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 24),
        
        const Text("Primary Medication", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        _buildMedicationButton("Insulin", Icons.medical_services),
        const SizedBox(height: 8),
        _buildMedicationButton("Metformin", Icons.medication),
        const SizedBox(height: 8),
        _buildMedicationButton("Other", Icons.local_pharmacy),
        const SizedBox(height: 24),
        
        TextField(
          controller: _hba1cController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Latest HbA1c (Optional)",
            hintText: "e.g., 7.2",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 24),
        
        SwitchListTile(
          value: _usesCGM,
          onChanged: (value) {
            setState(() => _usesCGM = value);
            HapticFeedback.selectionClick();
          },
          title: const Text("Do you use a CGM?"),
          activeColor: const Color(0xFF2563EB),
          contentPadding: EdgeInsets.zero,
        ),
        
        if (_usesCGM) ...[
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: "CGM Brand",
              hintText: "e.g., Freestyle Libre, Dexcom",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onChanged: (value) => _cgmBrand = value,
          ),
        ],
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Goals & Preferences", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        
        const Text("Target Glucose Range (mg/dL)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _targetGlucoseMinController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Min",
                  hintText: "70",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _targetGlucoseMaxController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Max",
                  hintText: "180",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        const Text("Health Goals (Optional)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ..._availableGoals.map((goal) => _buildGoalCheckbox(goal)),
        const SizedBox(height: 24),

        const Text("Notification Preferences (Optional)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ..._availableNotifications.map((notification) => _buildNotificationCheckbox(notification)),
      ],
    );
  }

  Widget _buildGenderButton(String gender) {
    final isSelected = _gender == gender;
    return GestureDetector(
      onTap: () {
        setState(() => _gender = gender);
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          gender,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityButton(String level, String description) {
    final isSelected = _activityLevel == level;
    return GestureDetector(
      onTap: () {
        setState(() => _activityLevel = level);
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              level,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF2563EB) : Colors.black87,
              ),
            ),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiabetesTypeButton(String type) {
    final isSelected = _diabetesType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _diabetesType = type);
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          type,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationButton(String medication, IconData icon) {
    final isSelected = _medicationType == medication;
    return GestureDetector(
      onTap: () {
        setState(() => _medicationType = medication);
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF2563EB) : Colors.grey[600]),
            const SizedBox(width: 12),
            Text(
              medication,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCheckbox(String goal) {
    final isSelected = _selectedGoals.contains(goal);
    return CheckboxListTile(
      value: isSelected,
      onChanged: (value) {
        setState(() {
          if (value ?? false) {
            _selectedGoals.add(goal);
          } else {
            _selectedGoals.remove(goal);
          }
        });
        HapticFeedback.selectionClick();
      },
      title: Text(goal),
      activeColor: const Color(0xFF2563EB),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildNotificationCheckbox(String notification) {
    final isSelected = _selectedNotifications.contains(notification);
    return CheckboxListTile(
      value: isSelected,
      onChanged: (value) {
        setState(() {
          if (value ?? false) {
            _selectedNotifications.add(notification);
          } else {
            _selectedNotifications.remove(notification);
          }
        });
        HapticFeedback.selectionClick();
      },
      title: Text(notification),
      activeColor: const Color(0xFF2563EB),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2563EB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                "Previous",
                style: TextStyle(color: Color(0xFF2563EB), fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          flex: _currentStep == 0 ? 1 : 1,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _currentStep == 2 ? "Complete Setup" : "Next",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}