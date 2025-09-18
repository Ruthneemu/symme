import 'package:flutter/material.dart';
import 'package:symme/utils/colors.dart';
import 'package:symme/utils/helpers.dart';
import 'package:symme/widgets/circles_tab.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_message_service.dart';
import '../services/storage_service.dart';
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
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection failed';
        _isLoading = false;
      });
      Helpers.showSnackBar(context, 'Failed to initialize: $e');
    }
  }

  void _setupHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5),
        (_) => FirebaseAuthService.updateLastSeen());
  }

  void _updateOnlineStatus(bool isOnline) {
    if (isOnline) FirebaseAuthService.updateLastSeen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
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
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _buildCurrentTab(theme),
      bottomNavigationBar: HomeNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
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

  Future<void> _handleRegenerateId() async {
    // same as before...
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
      });
      await _initializeApp();
    } catch (e) {
      Helpers.showSnackBar(context, 'Failed to clear data: $e');
    }
  }
}
