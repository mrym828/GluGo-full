import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';


class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000/glugo/v1'; // Android emulator
  // static const String baseUrl = 'http://localhost:8000/glugo/v1'; // iOS simulator
  // static const String baseUrl = 'http://YOUR_COMPUTER_IP:8000/glugo/v1'; // Real device
  
  String? _csrfToken;
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _cachedProfile;

  // Initialize and load saved tokens
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    
    print('ApiService initialized - Access token: ${_accessToken != null ? "exists" : "null"}');
    
    // Load cached profile if available
    final cachedProfileStr = prefs.getString('cached_profile');
    if (cachedProfileStr != null) {
      try {
        _cachedProfile = json.decode(cachedProfileStr);
      } catch (e) {
        print('Error loading cached profile: $e');
      }
    }
  }

  // ==================== AUTHENTICATION ====================

  /// Register new user
  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password, {
    String? fullName,
    String? gender,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'password_confirm': password,
          'full_name': fullName ?? '',
          'gender': gender ?? 'M',
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        await _saveTokens(data['access'], data['refresh']);
        if (data.containsKey('user')) {
          await _cacheProfile(data['user']);
        }
        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(_formatErrorMessage(error));
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on HttpException {
      throw Exception('Could not connect to server. Please try again later.');
    } on FormatException {
      throw Exception('Invalid response from server.');
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  /// Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/token/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveTokens(data['access'], data['refresh']);
        // Fetch and cache user profile after login
        try {
          final profile = await getProfile();
          await _cacheProfile(profile);
        } catch (e) {
          print('Error fetching profile after login: $e');
        }
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid username or password');
      } else {
        throw Exception('Login failed. Please try again.');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on HttpException {
      throw Exception('Could not connect to server. Please try again later.');
    } on FormatException {
      throw Exception('Invalid response from server.');
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  /// Save tokens to SharedPreferences
  Future<void> _saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
    
    print('Tokens saved successfully');
  }

  /// Cache user profile locally
  Future<void> _cacheProfile(Map<String, dynamic> profile) async {
    _cachedProfile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_profile', json.encode(profile));
  }

  /// Refresh access token
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) {
      print('No refresh token available');
      return false;
    }

    try {
      print('Attempting to refresh access token...');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        print('Access token refreshed successfully');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 500) {
        print('Refresh token is invalid or user not found. Clearing tokens.');
        await logout();
        return false;
      }
      
      print('Token refresh failed with status: ${response.statusCode}');
      return false;
    } catch (e) {
      print('Token refresh error: $e');
      await logout();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _cachedProfile = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('cached_profile');
    
    print('Logged out - tokens cleared');
  }

  bool get isLoggedIn => _accessToken != null;

  Map<String, dynamic>? get cachedProfile => _cachedProfile;


  Future<void> resetPassword(String username, String newPassword) async {
  final url = Uri.parse('$baseUrl/auth/reset-password/');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'username': username,
      'new_password': newPassword,
    }),
    );

    if (response.statusCode == 200) {
      print('Password reset successful');
    } else {
      throw Exception(json.decode(response.body)['error'] ?? 'Password reset failed');
    }
  }


  // ==================== PROFILE MANAGEMENT ====================

  /// Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.get(
        Uri.parse('$baseUrl/auth/profile/'),
        headers: _getHeaders(),
      ));
      
      if (response.statusCode == 200) {
        final profile = json.decode(response.body);
        await _cacheProfile(profile);
        return profile;
      } else {
        throw Exception('Failed to get profile: ${response.statusCode}');
      }
    } on SocketException {
      // Return cached profile if no internet
      if (_cachedProfile != null) {
        print('Using cached profile (offline mode)');
        return _cachedProfile!;
      }
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error getting profile: $e');
      rethrow;
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.patch(
        Uri.parse('$baseUrl/auth/profile/'),
        headers: _getHeaders(),
        body: json.encode(profileData),
      ));
      
      if (response.statusCode == 200) {
        final profile = json.decode(response.body);
        await _cacheProfile(profile);
        return profile;
      } else {
        final error = json.decode(response.body);
        throw Exception(_formatErrorMessage(error));
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

/// Delete user account permanently
  /// This will delete the user and all associated data
  Future<void> deleteAccount() async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.delete(
        Uri.parse('$baseUrl/auth/delete-account/'),
        headers: _getHeaders(),
      ));
      
      if (response.statusCode == 200) {
        // Account deleted successfully, clear all local data
        await logout();
        print('Account deleted successfully');
      } else {
        final error = json.decode(response.body);
        throw Exception(_formatErrorMessage(error));
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error deleting account: $e');
      rethrow;
    }
  }

  // ==================== GLUCOSE RECORDS ====================

  /// Get glucose records with optional date range
  Future<List<dynamic>> getGlucoseRecords({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      var url = '$baseUrl/glucose-records/';
      final queryParams = <String, String>{};
      
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String();
      }
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }
      
      if (queryParams.isNotEmpty) {
        url += '?${Uri(queryParameters: queryParams).query}';
      }
      
      final response = await _makeAuthenticatedRequest(() => http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      ));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load glucose records: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error fetching glucose records: $e');
      rethrow;
    }
  }

  /// Create glucose record
  Future<dynamic> createGlucoseRecord(Map<String, dynamic> data) async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.post(
        Uri.parse('$baseUrl/glucose-records/'),
        headers: _getHeaders(),
        body: json.encode(data),
      ));
      
      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        print('❌ Full response body: ${response.body}');
        final error = json.decode(response.body);
        throw Exception(_formatErrorMessage(error));
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error creating glucose record: $e');
      rethrow;
    }
  }

  /// Update glucose record
  Future<dynamic> updateGlucoseRecord(String recordId, Map<String, dynamic> data) async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.patch(
        Uri.parse('$baseUrl/glucose-records/$recordId/'),
        headers: _getHeaders(),
        body: json.encode(data),
      ));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(_formatErrorMessage(error));
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error updating glucose record: $e');
      rethrow;
    }
  }

  /// Delete glucose record
  Future<void> deleteGlucoseRecord(String recordId) async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.delete(
        Uri.parse('$baseUrl/glucose-records/$recordId/'),
        headers: _getHeaders(),
      ));
      
      if (response.statusCode != 204) {
        throw Exception('Failed to delete glucose record');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error deleting glucose record: $e');
      rethrow;
    }
  }

  /// Get glucose statistics
  Future<Map<String, dynamic>> getGlucoseStatistics({
  DateTime? startDate,
  DateTime? endDate,
}) async {
  try {
    var url = '$baseUrl/glucose-statistics/';
    final queryParams = <String, String>{};
    
    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }
    
    if (queryParams.isNotEmpty) {
      url += '?${Uri(queryParameters: queryParams).query}';
    }
    
    final response = await _makeAuthenticatedRequest(() => http.get(
      Uri.parse(url),
      headers: _getHeaders(),
    ));
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load glucose statistics');
    }

  } on SocketException {
    throw Exception('No internet connection. Please check your network.');
  } catch (e) {
    print('❌ Error fetching glucose statistics: $e');
    // don’t decode response if it doesn’t exist
    rethrow;
  }
}


  // ==================== FOOD ENTRIES ====================

  /// Get food entries
  Future<List<dynamic>> getFoodEntries({
  DateTime? startDate,
  DateTime? endDate,
  String? mealType,
  int limit = 50,
}) async {
  try {
    await init();
    
    if (!isLoggedIn) {
      throw Exception('User not logged in');
    }

    final queryParams = <String, String>{};
    
    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }
    if (mealType != null) {
      queryParams['meal_type'] = mealType;
    }
    queryParams['limit'] = limit.toString();
    
    final uri = Uri.parse('$baseUrl/food-entries/').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
    );
    
    print('Get food entries response: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List) {
        return data;
      } else if (data is Map && data['results'] != null) {
        return data['results'] as List;
      }
      return [];
    } else {
      throw Exception('Failed to get food entries: ${response.statusCode}');
    }
  } catch (e) {
    print('Error getting food entries: $e');
    rethrow;
  }
}


  /// Create food entry
  Future<Map<String, dynamic>?> createFoodEntry({
  required String foodName,
  required String? description,
  required String mealType,
  File? imageFile,
  Map<String, dynamic>? nutritionalInfo,
  double? totalCarbsG,
  double? totalProteinG,
  double? totalFatG,
  double? totalCal,
}) async {
  try {
    await init();
    
    if (!isLoggedIn) {
      throw Exception('User not logged in');
    }

    final uri = Uri.parse('$baseUrl/food/entries/');
    
    // Create multipart request
    final request = http.MultipartRequest('POST', uri);
    
    // Add headers
    request.headers['Authorization'] = 'Bearer $_accessToken';
    
    // Add fields
    request.fields['food_name'] = foodName;
    if (description != null) {
      request.fields['description'] = description;
    }
    request.fields['meal_type'] = mealType;
    
    if (totalCarbsG != null) {
      request.fields['total_carbs'] = totalCarbsG.toString();
    }

    if(totalProteinG != null){
      request.fields['total_protein'] = totalProteinG.toString();
    }

    if(totalFatG != null){
      request.fields['total_fat'] = totalFatG.toString();
    }

    if(totalCal != null){
      request.fields['total_calories'] = totalCal.toString();
    }

    if (nutritionalInfo != null) {
      request.fields['nutritional_info'] = json.encode(nutritionalInfo);
    }
    
    // Add image file if provided
    if (imageFile != null) {
      final imageBytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'food_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);
    }
    
    print('Creating food entry: $uri');
    
    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    print('Food entry response status: ${response.statusCode}');
    print('Food entry response body: ${response.body}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return data;
    } else {
      print('Food entry creation failed: ${response.body}');
      throw Exception('Failed to create food entry: ${response.statusCode}');
    }
  } catch (e) {
    print('Error creating food entry: $e');
    rethrow;
  }
}

  /// Update food entry
  Future<dynamic> updateFoodEntry(String entryId, Map<String, dynamic> data) async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.patch(
        Uri.parse('$baseUrl/food-entries/$entryId/'),
        headers: _getHeaders(),
        body: json.encode(data),
      ));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(_formatErrorMessage(error));
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error updating food entry: $e');
      rethrow;
    }
  }

  /// Delete food entry
  Future<void> deleteFoodEntry(String entryId) async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.delete(
        Uri.parse('$baseUrl/food-entries/$entryId/'),
        headers: _getHeaders(),
      ));
      
      if (response.statusCode != 204) {
        throw Exception('Failed to delete food entry');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error deleting food entry: $e');
      rethrow;
    }
  }

  // ==================== AI IMAGE ANALYSIS ====================
  /// Analyze food image with AI
  Future<Map<String, dynamic>?> analyzeImageAI(File imageFile) async {
  try {
    await init();
    
    if (!isLoggedIn) {
      throw Exception('User not logged in');
    }

    final uri = Uri.parse('$baseUrl/ai/analyze-image/');
    
    // Create multipart request
    final request = http.MultipartRequest('POST', uri);
    
    // Add headers
    request.headers['Authorization'] = 'Bearer $_accessToken';
    
    // Add image file
    final multipartFile = await http.MultipartFile.fromPath(
    'image', // must match Django field
    imageFile.path,
    contentType: MediaType('image', 'jpeg'), // adjust if PNG
  );
  request.files.add(multipartFile);
    
    print('Sending image analysis request to: $uri');
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    print('Image analysis response status: ${response.statusCode}');
    print('Image analysis response body: ${response.body}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return data;
    } else {
      print('Image analysis failed: ${response.body}');
      throw Exception('Failed to analyze image: ${response.statusCode}');
    }
  } catch (e) {
    print('Error analyzing image: $e');
    rethrow;
  }
}

  // ==================== INSULIN CALCULATION ====================

  /// Calculate insulin dose
  Future<dynamic> calculateInsulin(double totalCarbs, {double? currentGlucose}) async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.post(
        Uri.parse('$baseUrl/insulin/calculate/'),
        headers: _getHeaders(),
        body: json.encode({
          'total_carbs_g': totalCarbs,
          if (currentGlucose != null) 'current_glucose': currentGlucose,
        }),
      ));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(_formatErrorMessage(error));
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error calculating insulin: $e');
      rethrow;
    }
  }

  // ==================== LIBRE CONNECTION ====================

  /// Connect Libre with email and password
  Future<dynamic> connectLibre(String email, String password) async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.post(
        Uri.parse('$baseUrl/libre/login/'),
        headers: _getHeaders(),
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(_formatErrorMessage(error));
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error connecting Libre: $e');
      rethrow;
    }
  }

  /// Sync Libre data now
  Future<dynamic> libreSyncNow() async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.post(
        Uri.parse('$baseUrl/libre/sync-now/'),
        headers: _getHeaders(),
      ));
      print(response);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(_formatErrorMessage(error));
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error syncing Libre: $e');
      rethrow;
    }
  }

  /// Disconnect Libre
  Future<void> disconnectLibre() async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.post(
        Uri.parse('$baseUrl/libre/disconnect/'),
        headers: _getHeaders(),
      ));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to disconnect Libre');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error disconnecting Libre: $e');
      rethrow;
    }
  }

  /// Get Libre connection status
  Future<Map<String, dynamic>> getLibreStatus() async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.get(
        Uri.parse('$baseUrl/libre/status/'),
        headers: _getHeaders(),
      ));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get Libre status');
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error getting Libre status: $e');
      rethrow;
    }
  }

  // ==================== HEALTH SYNC ====================

  /// Sync health data
  Future<dynamic> syncHealthData(Map<String, dynamic> healthData) async {
    try {
      final response = await _makeAuthenticatedRequest(() => http.post(
        Uri.parse('$baseUrl/sync/health/'),
        headers: _getHeaders(),
        body: json.encode(healthData),
      ));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(_formatErrorMessage(error));
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      print('Error syncing health data: $e');
      rethrow;
    }
  }
  Future<Map<String, dynamic>?> predictGlucoseAfterMeal({
    required double carbs,
    double insulin = 0,
    String model = 'ensemble',
    int lookback = 240,
  }) async {
    try {
      if (_accessToken == null) {
        throw Exception('Not authenticated. Please log in.');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/glucose/predict-meal/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode({
          'carbs': carbs,
          'insulin': insulin,
          'model': model,
          'lookback': lookback,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Prediction request timed out');
        },
      );

      print('Meal prediction response status: ${response.statusCode}');
      print('Meal prediction response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Invalid request');
      } else if (response.statusCode == 401) {
        // Try to refresh token
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          // Retry the request
          return await predictGlucoseAfterMeal(
            carbs: carbs,
            insulin: insulin,
            model: model,
            lookback: lookback,
          );
        }
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to get prediction: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on HttpException {
      throw Exception('Could not connect to server');
    } catch (e) {
      print('Prediction error: $e');
      rethrow;
    }
  }

  /// Get regular glucose prediction (without meal)
  Future<Map<String, dynamic>?> predictGlucose({
    String model = 'ensemble',
    int lookback = 240,
  }) async {
    try {
      if (_accessToken == null) {
        throw Exception('Not authenticated. Please log in.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/glucose/predict/?model=$model&lookback=$lookback'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Prediction request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          return await predictGlucose(model: model, lookback: lookback);
        }
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to get prediction');
      }
    } catch (e) {
      print('Prediction error: $e');
      rethrow;
    }
  }

  /// Check prediction service status
  Future<Map<String, dynamic>?> getPredictionServiceStatus() async {
    try {
      if (_accessToken == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/core/glucose/predict-status/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Status check error: $e');
      return null;
    }
  }



  // ==================== HELPER METHODS ====================

  /// Get CSRF token
  Future<void> getCsrfToken() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/csrf/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _csrfToken = data['csrfToken'];
      }
    } catch (e) {
      print('Error getting CSRF token: $e');
    }
  }

  /// Common headers with JWT
  Map<String, String> _getHeaders() {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    if (_csrfToken != null) {
      headers['X-CSRFToken'] = _csrfToken!;
    }
    
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    return headers;
  }

  /// Make authenticated request with automatic token refresh
  Future<http.Response> _makeAuthenticatedRequest(
    Future<http.Response> Function() request,
  ) async {
    var response = await request();
    
    // If unauthorized, try refreshing token
    if (response.statusCode == 401) {
      print('Received 401, attempting token refresh...');
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        // Token refreshed successfully, retry the request
        response = await request();
      } else {
        // Refresh failed, user needs to log in again
        throw Exception('Authentication failed. Please log in again.');
      }
    }
    
    return response;
  }

  /// Helper method to format error messages
  String _formatErrorMessage(dynamic error) {
    if (error is Map) {
      // Extract first error message from Django error format
      if (error.containsKey('error')) {
        return error['error'].toString();
      }
      if (error.containsKey('detail')) {
        return error['detail'].toString();
      }
      // Handle field-specific errors
      final firstError = error.values.firstWhere(
        (value) => value != null,
        orElse: () => 'An error occurred',
      );
      if (firstError is List && firstError.isNotEmpty) {
        return firstError.first.toString();
      }
      return firstError.toString();
    }
    return error.toString();
  }
}

