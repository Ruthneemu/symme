import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:symme/utils/colors.dart';
import 'package:symme/utils/helpers.dart';
import 'package:symme/widgets/circles_tab.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_message_service.dart';
import '../services/storage_service.dart';
import '../services/call_manager.dart';
import '../models/call.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'settings_screen.dart';
import 'call_screen.dart';
import '../widgets/home_navbar.dart';
import '../widgets/chat_tab.dart';
import '../widgets/calls_tab.dart';
import '../widgets/connection_status.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  String? _userSecureId;
  bool _isLoading = true;
  bool _callManagerInitialized = false;
  String _connectionStatus = 'Connecting...';
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    _setupHeartbeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    CallManager.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _updateOnlineStatus(true);
        _setupHeartbeat();
        break;
      default:
        _updateOnlineStatus(false);
        _heartbeatTimer?.cancel();
        break;
    }
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _connectionStatus = 'Initializing...');

      final currentUser = FirebaseAuthService.getCurrentUser();
      if (currentUser == null) {
        setState(() => _connectionStatus = 'Signing in...');
        final user = await FirebaseAuthService.signInAnonymously();
        if (user == null) throw Exception('Failed to sign in');
      }

      final secureId = await StorageService.getUserSecureId();
      setState(() {
        _userSecureId = secureId;
        _connectionStatus = 'Connected';
        _isLoading = false;
      });

      await FirebaseMessageService.cleanupExpiredMessages();
      await _initializeCallManager();
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection failed';
        _isLoading = false;
      });
      Helpers.showSnackBar(context, 'Failed to initialize: $e');
    }
  }

  Future<void> _initializeCallManager() async {
    try {
      if (_callManagerInitialized) return;

      setState(() => _connectionStatus = 'Setting up calling...');
      await CallManager.instance.initialize(context);

      setState(() {
        _callManagerInitialized = true;
        _connectionStatus = 'Connected';
      });
    } catch (e) {
      setState(() => _connectionStatus = 'Calling service failed');

      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calling service initialization failed: $e'),
            backgroundColor: theme.colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: theme.colorScheme.onError,
              onPressed: _initializeCallManager,
            ),
          ),
        );
      }
    }
  }

  void _setupHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => FirebaseAuthService.updateLastSeen(),
    );
  }

  void _updateOnlineStatus(bool isOnline) {
    if (isOnline) FirebaseAuthService.updateLastSeen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppGradients.appBarGradient, // 👈 gradient support
          ),
        ),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (!_isLoading)
            ConnectionStatus(
              connectionStatus: _connectionStatus,
              onRefresh: _initializeApp,
              onRegenerateId: _handleRegenerateId,
              onCleanup: _handleCleanupMessages,
            ),
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: _debugUserSetup,
              tooltip: 'Debug User Setup',
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView(theme, 'Initializing app...')
          : !_callManagerInitialized
          ? _buildLoadingView(theme, 'Setting up calling service...')
          : _buildCurrentTab(theme),
      bottomNavigationBar: HomeNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  Widget _buildLoadingView(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(message, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildCurrentTab(ThemeData theme) {
    switch (_currentIndex) {
      case 0:
        return ChatTab(onStartChat: _onStartChat);
      case 1:
        return CirclesTab(userSecureId: _userSecureId ?? '');
      case 2:
        return ContactsScreen(
          onContactAdded: _onContactAdded,
          onStartChat: _onStartChat,
        );
      case 3:
        return const CallsTab();
      case 4:
        return SettingsScreen(
          userPublicId: _userSecureId ?? '',
          onClearData: _handleClearData,
          onRegenerateId: _handleRegenerateId,
        );
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }

  void _onContactAdded() => setState(() {});

  void _onStartChat(String otherUserSecureId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(otherUserSecureId: otherUserSecureId),
      ),
    );
  }

  void _onStartCall(String otherUserSecureId, CallType callType) {
    final call = Call(
      id: 'some_unique_id',
      callerId: _userSecureId!,
      receiverId: otherUserSecureId,
      type: callType,
      status: CallStatus.outgoing,
      timestamp: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(call: call, isIncoming: false),
      ),
    );
  }

  Future<void> _debugUserSetup() async {
    print('=== DEBUG USER SETUP ===');
    final currentUser = FirebaseAuthService.getCurrentUser();
    final storedUserId = await StorageService.getUserId();
    final storedSecureId = await StorageService.getUserSecureId();

    print('Current Firebase User: ${currentUser?.uid}');
    print('Stored User ID: $storedUserId');
    print('Stored Secure ID: $storedSecureId');

    if (currentUser != null) {
      try {
        final userSnapshot = await FirebaseDatabase.instance
            .ref('users/${currentUser.uid}')
            .once();
        if (userSnapshot.snapshot.exists) {
          print(
            'Firebase Realtime DB user data: ${userSnapshot.snapshot.value}',
          );
        } else {
          print('User NOT found in Firebase Realtime Database');
        }
      } catch (e) {
        print('Error checking Realtime DB: $e');
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Debug Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User ID: ${currentUser?.uid ?? "NULL"}'),
              Text('Stored User ID: ${storedUserId ?? "NULL"}'),
              Text('Secure ID: ${storedSecureId ?? "NULL"}'),
              Text(
                'CallManager: ${_callManagerInitialized ? "Initialized" : "Not initialized"}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    print('=== END DEBUG ===');
  }

  Future<void> _handleRegenerateId() async {
    // your existing code...
  }

  Future<void> _handleCleanupMessages() async {
    try {
      await FirebaseMessageService.cleanupExpiredMessages();
      Helpers.showSnackBar(context, 'Expired messages cleaned up');
    } catch (_) {
      Helpers.showSnackBar(context, 'Failed to cleanup messages');
    }
  }

  Future<void> _handleClearData() async {
    try {
      await FirebaseAuthService.signOut();
      await StorageService.clearAllData();
      setState(() {
        _isLoading = true;
        _userSecureId = null;
        _callManagerInitialized = false;
      });
      await _initializeApp();
    } catch (e) {
      Helpers.showSnackBar(context, 'Failed to clear data: $e');
    }
  }
}
