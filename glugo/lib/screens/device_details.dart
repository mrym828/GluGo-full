import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../utils/theme.dart';
import '../widgets/shared_components.dart';
import '../services/api_service.dart';

// Helper extension for safe type conversions
extension SafeMapAccess on Map<String, dynamic> {
  int getInt(String key, {int defaultValue = 0}) {
    final value = this[key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
  
  String getString(String key, {String defaultValue = ''}) {
    final value = this[key];
    return value?.toString() ?? defaultValue;
  }
  
  bool getBool(String key, {bool defaultValue = false}) {
    final value = this[key];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    return defaultValue;
  }
}

class DevicesDetailScreen extends StatefulWidget {
  const DevicesDetailScreen({super.key});

  @override
  State<DevicesDetailScreen> createState() => _DevicesDetailScreenState();
}

class _DevicesDetailScreenState extends State<DevicesDetailScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isConnected = false;
  Map<String, dynamic>? _libreStatus;
  String? _errorMessage;

  // Expansion states
  bool _isDeviceExpanded = false;
  bool _isSyncHistoryExpanded = false;
  bool _isHelpExpanded = false;

  // Animation controllers
  late AnimationController _deviceController;
  late AnimationController _syncController;
  late AnimationController _helpController;
  late AnimationController _progressController;

  // Sync status tracking
  SyncStatus _currentSyncStatus = SyncStatus.idle;
  double _syncProgress = 0.0;
  String _syncStatusMessage = '';
  int _recordsProcessed = 0;
  int _totalRecords = 0;
  Timer? _syncStatusTimer;

  // Sync history data
  final List<Map<String, dynamic>> _syncHistory = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadLibreStatus();
    _loadSyncHistory();
    _startSyncStatusMonitoring();
  }

  void _setupAnimations() {
    _deviceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _syncController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _helpController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  void _startSyncStatusMonitoring() {
    // Poll for sync status every 2 seconds when connected
    _syncStatusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isConnected && mounted) {
        _checkSyncStatus(); // Refresh status periodically
      }
    });
  }

  Future<void> _checkSyncStatus() async{
    try {
      // Check if there's an ongoing sync by calling the status endpoint
      final status = await _apiService.getLibreStatus();
      
      // If the backend returns sync status information, update UI accordingly
      if (status.containsKey('syncing') && status['syncing'] == true) {
        if (mounted && _currentSyncStatus == SyncStatus.idle) {
          setState(() {
            _currentSyncStatus = SyncStatus.processing;
            _syncStatusMessage = 'Background sync in progress...';
          });
        }
      }
    } catch (e) {
      print('Error checking sync status: $e');
    }
  }

  Future<void> _loadSyncHistory() async {
    try {
      final status = await _apiService.getLibreStatus();

      setState(() {
        _syncHistory.clear();
      });

      if (status.containsKey('recent_syncs') && status['recent_syncs'] is List){
        final recentSyncs = status['recent_syncs'] as List;
        for (var sync in recentSyncs){
          _syncHistory.add({
            'timestamp': DateTime.parse(sync['timestamp'] ?? DateTime.now().toIso8601String()),
            'records_synced': sync['records_synced'] ?? 0,
            'status': sync['status']??'unknown',
            'duration_seconds': sync['duration_seconds'] ?? 0,
            'error': sync['error'],
          });
        }
      } else{

      }
    } catch(e){
      print('Error loading sync history: $e');
    }
  }

  Future<void> _loadLibreStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.init();
      final status = await _apiService.getLibreStatus();
      
      if (mounted) {
        setState(() {
          _libreStatus = status;
          _isConnected = status.getBool('connected');
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading Libre status: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isConnected = false;
        });
      }
    }
  }

  Future<void> _syncNow() async {
    if (!_isConnected) {
      _showSnackBar('Please connect your LibreView account first', isSuccess: false);
      return;
    }

    // Start sync animation
    setState(() {
      _currentSyncStatus = SyncStatus.connecting;
      _syncProgress = 0.0;
      _syncStatusMessage = 'Connecting to LibreView...';
      _recordsProcessed = 0;
      _totalRecords = 0;
    });

    _progressController.reset();
    _progressController.forward();

    try {
      await _updateSyncProgress(0.1, SyncStatus.connecting, 'Authenticating...');
      await Future.delayed(Duration(milliseconds: 500));

      // Update progress - Fetching phase
      await _updateSyncProgress(0.3, SyncStatus.fetching, 'Fetching glucose data...');
      await Future.delayed(Duration(milliseconds: 800));

      final result = await _apiService.libreSyncNow();
    
      final recordsCount = result.getInt('records_synced');
      
      // Update progress - Processing phase
      await _updateSyncProgress(0.5, SyncStatus.processing, 'Processing records...');
      setState(() {
        _totalRecords = recordsCount;
      });

      for (int i = 0; i < recordsCount; i += 5) {
        if (!mounted) break;
        await Future.delayed(Duration(milliseconds: 50));
        setState(() {
          _recordsProcessed = ((i + 5).clamp(0, recordsCount) as int);
          _syncProgress = 0.5 + (0.4 * _recordsProcessed / recordsCount);
        });
      }

      // Update progress - Completing phase
      await _updateSyncProgress(0.95, SyncStatus.completing, 'Finalizing...');
      await Future.delayed(Duration(milliseconds: 300));

      if (mounted) {
        setState(() {
          _currentSyncStatus = SyncStatus.success;
          _syncProgress = 1.0;
          _syncStatusMessage = 'Sync completed successfully!';
          _recordsProcessed = recordsCount;
        });

        // Show success briefly before returning to idle
        await Future.delayed(Duration(seconds: 2));
        
        if (mounted) {
          setState(() {
            _currentSyncStatus = SyncStatus.idle;
            _syncProgress = 0.0;
            _syncStatusMessage = '';
          });
        }
        
        _showSnackBar(
          'Synced $recordsCount glucose readings successfully!',
          isSuccess: true,
        );
        
        // Reload status and history
        _loadLibreStatus();
        _loadSyncHistory();
      }
    } catch (e) {
      print('Sync error: $e');
      if (mounted) {
        setState(() {
          _currentSyncStatus = SyncStatus.error;
          _syncStatusMessage = 'Sync failed: ${e.toString().replaceAll('Exception: ', '')}';
        });

        // Show error briefly before returning to idle
        await Future.delayed(Duration(seconds: 3));
        
        if (mounted) {
          setState(() {
            _currentSyncStatus = SyncStatus.idle;
            _syncProgress = 0.0;
            _syncStatusMessage = '';
          });
        }
        
        _showSnackBar(
          'Sync failed: ${e.toString().replaceAll('Exception: ', '')}',
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _updateSyncProgress(
    double progress,
    SyncStatus status,
    String message,
  ) async {
    if (mounted) {
      setState(() {
        _syncProgress = progress;
        _currentSyncStatus = status;
        _syncStatusMessage = message;
      });
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.warningOrange),
            const SizedBox(width: 12),
            const Text('Disconnect LibreView?'),
          ],
        ),
        content: const Text(
          'This will stop automatic glucose data syncing. You can reconnect anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        await _apiService.disconnectLibre();
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isConnected = false;
            _libreStatus = null;
          });
          _showSnackBar('LibreView disconnected successfully', isSuccess: true);
        }
      } catch (e) {
        print('Disconnect error: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Failed to disconnect: ${e.toString().replaceAll('Exception: ', '')}', isSuccess: false);
        }
      }
    }
  }

  void _showConnectDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.medical_services_rounded, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              const Text('Connect LibreView'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your Freestyle LibreView credentials to sync your glucose data automatically.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'LibreView Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  enabled: !isLoading,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'LibreView Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      final password = passwordController.text;

                      if (email.isEmpty || password.isEmpty) {
                        _showSnackBar('Please fill in all fields', isSuccess: false);
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      try {
                        await _apiService.connectLibre(email, password);
                        
                        // Sync immediately after connection
                        try {
                          await _apiService.libreSyncNow();
                        } catch (e) {
                          print('Initial sync warning: $e');
                          // Continue even if initial sync fails
                        }

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          _showSnackBar(
                            'LibreView connected successfully!',
                            isSuccess: true,
                          );
                          _loadLibreStatus();
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        _showSnackBar(
                          e.toString().replaceAll('Exception: ', ''),
                          isSuccess: false,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: isLoading
                  ? SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? AppTheme.successGreen : AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _syncStatusTimer?.cancel();
    _deviceController.dispose();
    _syncController.dispose();
    _helpController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: SharedAppBar(
        title: 'Connected Devices',
        showBackButton: true,
        showConnection: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadLibreStatus();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.warningOrange),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppTheme.warningOrange),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_errorMessage!)),
                          ],
                        ),
                      ),

                    // Real-time Sync Status Card
                    if (_currentSyncStatus != SyncStatus.idle)
                      _buildSyncStatusCard(),

                    // LibreView Device Tile (Expandable)
                    _buildExpandableDeviceTile(),

                    const SizedBox(height: 16),

                    // Sync History Tile (Expandable)
                    if (_isConnected) ...[
                      _buildExpandableSyncHistoryTile(),
                      const SizedBox(height: 16),
                    ],

                    // Help Section (Expandable)
                    _buildExpandableHelpTile(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSyncStatusCard() {
    final statusColor = _getSyncStatusColor(_currentSyncStatus);
    final statusIcon = _getSyncStatusIcon(_currentSyncStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getSyncStatusTitle(_currentSyncStatus),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _syncStatusMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_currentSyncStatus == SyncStatus.success)
                Icon(Icons.check_circle, color: statusColor, size: 28),
              if (_currentSyncStatus == SyncStatus.error)
                Icon(Icons.error, color: statusColor, size: 28),
            ],
          ),
          const SizedBox(height: 16),
          
          // Animated Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: 8,
                  width: MediaQuery.of(context).size.width * _syncProgress * 0.85,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor,
                        statusColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Progress percentage and details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(_syncProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              if (_totalRecords > 0)
                Text(
                  '$_recordsProcessed / $_totalRecords records',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSyncStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return AppTheme.textSecondary;
      case SyncStatus.connecting:
      case SyncStatus.fetching:
      case SyncStatus.processing:
      case SyncStatus.completing:
        return AppTheme.warningOrange;
      case SyncStatus.success:
        return AppTheme.successGreen;
      case SyncStatus.error:
        return AppTheme.errorRed;
    }
  }

  IconData _getSyncStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Icons.cloud_done_rounded;
      case SyncStatus.connecting:
        return Icons.cloud_sync_rounded;
      case SyncStatus.fetching:
        return Icons.cloud_download_rounded;
      case SyncStatus.processing:
        return Icons.sync_rounded;
      case SyncStatus.completing:
        return Icons.cloud_upload_rounded;
      case SyncStatus.success:
        return Icons.cloud_done_rounded;
      case SyncStatus.error:
        return Icons.cloud_off_rounded;
    }
  }

  String _getSyncStatusTitle(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return 'Ready';
      case SyncStatus.connecting:
        return 'Connecting';
      case SyncStatus.fetching:
        return 'Fetching Data';
      case SyncStatus.processing:
        return 'Processing';
      case SyncStatus.completing:
        return 'Completing';
      case SyncStatus.success:
        return 'Sync Complete';
      case SyncStatus.error:
        return 'Sync Failed';
    }
  }

  Widget _buildExpandableDeviceTile() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isDeviceExpanded = !_isDeviceExpanded;
                if (_isDeviceExpanded) {
                  _deviceController.forward();
                } else {
                  _deviceController.reverse();
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isConnected
                          ? AppTheme.successGreen.withOpacity(0.1)
                          : AppTheme.textSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.medical_services_rounded,
                      color: _isConnected
                          ? AppTheme.successGreen
                          : AppTheme.textSecondary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Freestyle LibreView',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isConnected
                                    ? AppTheme.successGreen
                                    : AppTheme.textSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isConnected ? 'Connected' : 'Not Connected',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isDeviceExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isDeviceExpanded
                ? Column(
                    children: [
                      Divider(color: AppTheme.borderLight, height: 1),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isConnected && _libreStatus != null) ...[
                              _buildInfoRow(
                                'Connected Account',
                                _libreStatus!.getString('email', defaultValue: 'N/A'),
                                Icons.email_outlined,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Last Sync',
                                _formatLastSync(_libreStatus!['last_sync']),
                                Icons.sync_rounded,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Total Records',
                                '${_libreStatus!.getInt('total_records', defaultValue: 0)}',
                                Icons.data_usage_rounded,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Device Type',
                                _libreStatus!.getString('device_type', defaultValue: 'Freestyle Libre'),
                                Icons.sensors_rounded,
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Sync Frequency',
                                'Every 15 minutes',
                                Icons.schedule_rounded,
                              ),
                              const SizedBox(height: 24),
                            ],
                            
                            // Action Buttons
                            if (_isConnected) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _currentSyncStatus == SyncStatus.idle 
                                          ? _syncNow 
                                          : null,
                                      icon: const Icon(Icons.sync, size: 18),
                                      label: const Text('Sync Now'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryBlue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        disabledBackgroundColor: AppTheme.neutralGray,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _disconnect,
                                      icon: const Icon(Icons.link_off, size: 18),
                                      label: const Text('Disconnect'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.errorRed,
                                        side: BorderSide(color: AppTheme.errorRed),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _showConnectDialog,
                                  icon: const Icon(Icons.add_link, size: 20),
                                  label: const Text('Connect LibreView'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSyncHistoryTile() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isSyncHistoryExpanded = !_isSyncHistoryExpanded;
                if (_isSyncHistoryExpanded) {
                  _syncController.forward();
                } else {
                  _syncController.reverse();
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sync History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_syncHistory.length} recent syncs',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isSyncHistoryExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Sync History Content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isSyncHistoryExpanded
                ? Column(
                    children: [
                      Divider(color: AppTheme.borderLight, height: 1),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _syncHistory.length,
                        separatorBuilder: (context, index) => Divider(
                          color: AppTheme.borderLight,
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                        ),
                        itemBuilder: (context, index) {
                          final sync = _syncHistory[index];
                          final isSuccess = sync['status'] == 'success';
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSuccess
                                        ? AppTheme.successGreen.withOpacity(0.1)
                                        : AppTheme.errorRed.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isSuccess
                                        ? Icons.check_circle_rounded
                                        : Icons.error_rounded,
                                    color: isSuccess
                                        ? AppTheme.successGreen
                                        : AppTheme.errorRed,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatSyncTime(sync['timestamp']),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (isSuccess) ...[
                                        Text(
                                          '${sync['records_synced']} record${sync['records_synced'] == 1 ? '' : 's'} synced',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        if (sync['glucose_value'] != null)
                                          Text(
                                            'Glucose: ${sync['glucose_value']} ${sync['glucose_unit'] ?? 'mg/dL'}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textTertiary,
                                            ),
                                          ),
                                      ] else ...[
                                        Text(
                                          sync['error'] ?? 'Unknown error',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.errorRed,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSuccess
                                        ? AppTheme.successGreen.withOpacity(0.1)
                                        : AppTheme.errorRed.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isSuccess ? 'Success' : 'Failed',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSuccess
                                          ? AppTheme.successGreen
                                          : AppTheme.errorRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (_syncHistory.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 48,
                                color: AppTheme.textTertiary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No sync history yet',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sync your data to see history here',
                                style: TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableHelpTile() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isHelpExpanded = !_isHelpExpanded;
                if (_isHelpExpanded) {
                  _helpController.forward();
                } else {
                  _helpController.reverse();
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.help_outline_rounded,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'About LibreView',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'How it works',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isHelpExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Help Content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isHelpExpanded
                ? Column(
                    children: [
                      Divider(color: AppTheme.borderLight, height: 1),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHelpItem(
                              'Automatic glucose data syncing from your Freestyle Libre sensor',
                            ),
                            const SizedBox(height: 12),
                            _buildHelpItem(
                              'Historical data import for comprehensive tracking',
                            ),
                            const SizedBox(height: 12),
                            _buildHelpItem(
                              'Secure connection with end-to-end encryption',
                            ),
                            const SizedBox(height: 12),
                            _buildHelpItem(
                              'Data syncs every 15 minutes automatically',
                            ),
                            const SizedBox(height: 12),
                            _buildHelpItem(
                              'View detailed sync history and troubleshoot issues',
                            ),
                            const SizedBox(height: 12),
                            _buildHelpItem(
                              'Real-time progress tracking during sync operations',
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _formatLastSync(dynamic lastSync) {
    if (lastSync == null) return 'Never';
    
    try {
      final DateTime syncTime = DateTime.parse(lastSync.toString());
      final now = DateTime.now();
      final difference = now.difference(syncTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hr ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatSyncTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      return minutes > 0 
          ? '$hours hr $minutes min ago'
          : '$hours hr ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

// Sync Status Enum
enum SyncStatus {
  idle,
  connecting,
  fetching,
  processing,
  completing,
  success,
  error,
}