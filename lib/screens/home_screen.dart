import 'package:flutter/material.dart';
import 'dart:async';
import '../services/firebase_auth_service.dart';
import '../services/firebase_message_service.dart';
import '../services/storage_service.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'contacts_screen.dart';
import '../models/call.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';
import 'call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  String? _userSecureId;
  bool _isLoading = true;
  String _connectionStatus = 'Connecting...';
  Timer? _heartbeatTimer;

  final List<String> _tabTitles = ['Chats', 'Contacts', 'Calls', 'Settings'];

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
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _updateOnlineStatus(false);
        _heartbeatTimer?.cancel();
        break;
    }
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _connectionStatus = 'Initializing...';
      });

      final currentUser = FirebaseAuthService.getCurrentUser();
      if (currentUser == null) {
        setState(() {
          _connectionStatus = 'Signing in...';
        });

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

      Helpers.showSnackBar(
        context,
        'Failed to initialize app: ${e.toString()}',
      );
    }
  }

  void _setupHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      FirebaseAuthService.updateLastSeen();
    });
  }

  void _updateOnlineStatus(bool isOnline) {
    if (isOnline) {
      FirebaseAuthService.updateLastSeen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabTitles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _connectionStatus == 'Connected'
                            ? Colors.green
                            : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _connectionStatus,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Refresh'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'regenerate_id',
                  child: ListTile(
                    leading: Icon(Icons.generating_tokens),
                    title: Text('Regenerate ID'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'cleanup',
                  child: ListTile(
                    leading: Icon(Icons.cleaning_services),
                    title: Text('Clean Messages'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Setting up SecureChat...'),
                ],
              ),
            )
          : _buildCurrentTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.phone),
            label: 'Calls',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildChatsTab();
      case 1:
        return ContactsScreen(
          onContactAdded: _onContactAdded,
          onStartChat: _onStartChat,
        );
      case 2:
        return _buildCallsTab();
      case 3:
        return SettingsScreen(
          userPublicId: _userSecureId ?? '',
          onClearData: _handleClearData,
          onRegenerateId: _handleRegenerateId,
        );
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }

  Widget _buildChatsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseMessageService.getChatRooms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chatRooms = snapshot.data ?? [];

        if (chatRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.noChatsYet,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.addContactsToChat,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: chatRooms.length,
          itemBuilder: (context, index) {
            final chatRoom = chatRooms[index];
            return _buildChatRoomItem(chatRoom);
          },
        );
      },
    );
  }

  Widget _buildCallsTab() {
    // TODO: Replace with real call history
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.phone, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No calls yet"),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _onStartCall("sampleUserId", CallType.audio),
            child: const Text("Start Sample Call"),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRoomItem(Map<String, dynamic> chatRoom) {
    final secureId = chatRoom['otherUserSecureId'] as String;
    final isOnline = chatRoom['isOnline'] as bool;
    final lastMessage = chatRoom['lastMessage'] as String?;
    final lastMessageTime = chatRoom['lastMessageTime'] as int?;

    String timeText = '';
    if (lastMessageTime != null) {
      timeText = Helpers.formatTimestamp(
        DateTime.fromMillisecondsSinceEpoch(lastMessageTime),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Helpers.getColorFromId(secureId),
              child: Text(
                Helpers.getInitials(secureId),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          secureId,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        ),
        subtitle: Text(
          lastMessage ?? 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: lastMessage != null ? null : Colors.grey[500],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (timeText.isNotEmpty)
              Text(
                timeText,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            const SizedBox(height: 4),
            if (isOnline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Online',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
          ],
        ),
        onTap: () => _onStartChat(secureId),
      ),
    );
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'refresh':
        await _initializeApp();
        break;
      case 'regenerate_id':
        await _handleRegenerateId();
        break;
      case 'cleanup':
        await _handleCleanupMessages();
        break;
    }
  }

  Future<void> _handleRegenerateId() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Secure ID'),
        content: const Text(
          'This will generate a new Secure ID for you. Your existing contacts will need to add your new ID to continue chatting. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await FirebaseAuthService.regenerateSecureId();
      if (success) {
        final newId = await StorageService.getUserSecureId();
        setState(() {
          _userSecureId = newId;
        });
        Helpers.showSnackBar(context, 'Secure ID regenerated successfully');
      } else {
        Helpers.showSnackBar(context, 'Failed to regenerate Secure ID');
      }
    }
  }

  Future<void> _handleCleanupMessages() async {
    try {
      await FirebaseMessageService.cleanupExpiredMessages();
      Helpers.showSnackBar(context, 'Expired messages cleaned up');
    } catch (e) {
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
      Helpers.showSnackBar(context, 'Failed to clear data: ${e.toString()}');
    }
  }

  void _onContactAdded() {
    setState(() {});
  }

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
        builder: (context) => CallScreen(
          call: call,
          isIncoming: false,
        ),
      ),
    );
  }
}
