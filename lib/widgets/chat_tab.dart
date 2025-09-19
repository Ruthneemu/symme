import 'package:flutter/material.dart';
import '../services/firebase_message_service.dart';
import '../utils/helpers.dart';

class ChatTab extends StatefulWidget {
  final Function(String) onStartChat;

  const ChatTab({super.key, required this.onStartChat});

  @override
  _ChatTabState createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  List<Map<String, dynamic>> _chatRooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  void _loadChatRooms() {
    FirebaseMessageService.getChatRooms().listen(
      (chatRooms) {
        if (mounted) {
          setState(() {
            _chatRooms = chatRooms;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          Helpers.showSnackBar(context, 'Failed to load chats: $error');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : _chatRooms.isEmpty
          ? _buildEmptyState(theme)
          : _buildChatList(theme),
      floatingActionButton: FloatingActionButton(
        onPressed: _showStartChatDialog,
        backgroundColor: theme.colorScheme.primary,
        tooltip: 'Start New Chat',
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No Chats Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to start a new conversation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _chatRooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        return _buildChatRoomItem(_chatRooms[index], theme);
      },
    );
  }

  Widget _buildChatRoomItem(Map<String, dynamic> chatRoom, ThemeData theme) {
    final otherUserSecureId = chatRoom['otherUserSecureId'] as String? ?? '';
    final displayName = chatRoom['displayName'] as String? ?? otherUserSecureId;
    final lastMessage = chatRoom['lastMessage'] as String? ?? 'No messages yet';
    final lastMessageTime = chatRoom['lastMessageTime'] as int?;
    final isOnline = chatRoom['isOnline'] as bool? ?? false;

    String timeString = '';
    if (lastMessageTime != null) {
      final messageDate = DateTime.fromMillisecondsSinceEpoch(lastMessageTime);
      final now = DateTime.now();
      final difference = now.difference(messageDate);

      if (difference.inDays > 0) {
        timeString = '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        timeString = '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        timeString = '${difference.inMinutes}m ago';
      } else {
        timeString = 'Now';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: theme.colorScheme.surface,
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              child: Text(
                displayName.isNotEmpty
                    ? displayName.substring(0, 2).toUpperCase()
                    : 'U',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          displayName,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'monospace',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              lastMessage,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (timeString.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                timeString,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withOpacity(0.4),
        ),
        onTap: () {
          if (otherUserSecureId.isNotEmpty) {
            widget.onStartChat(otherUserSecureId);
          }
        },
        onLongPress: () => _showChatOptions(chatRoom),
      ),
    );
  }

  void _showStartChatDialog() {
    final TextEditingController controller = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Start New Chat',
          style: TextStyle(color: theme.colorScheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the secure ID of the person you want to chat with:',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'e.g., ABC123XYZ789',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.person_add,
                  color: theme.colorScheme.primary,
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 12,
            ),
            const SizedBox(height: 8),
            Text(
              'Secure IDs are 12 characters long and contain only letters and numbers.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final secureId = controller.text.trim().toUpperCase();
              if (_isValidSecureId(secureId)) {
                Navigator.pop(context);
                widget.onStartChat(secureId);
              } else {
                Helpers.showSnackBar(
                  context,
                  'Please enter a valid 12-character secure ID',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  bool _isValidSecureId(String id) {
    return RegExp(r'^[A-Z0-9]{12}$').hasMatch(id);
  }

  void _showChatOptions(Map<String, dynamic> chatRoom) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.info_outline,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                'Chat Info',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                _showChatInfo(chatRoom);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.notifications_off_outlined,
                color: theme.colorScheme.tertiary,
              ),
              title: Text(
                'Mute Notifications',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                Helpers.showSnackBar(context, 'Mute feature coming soon!');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Clear Chat',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                _showClearChatDialog(chatRoom);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showChatInfo(Map<String, dynamic> chatRoom) {
    final theme = Theme.of(context);
    final otherUserSecureId = chatRoom['otherUserSecureId'] as String? ?? '';
    final displayName = chatRoom['displayName'] as String? ?? otherUserSecureId;
    final isOnline = chatRoom['isOnline'] as bool? ?? false;
    final lastSeen = chatRoom['lastSeen'] as int?;

    String lastSeenText = 'Unknown';
    if (isOnline) {
      lastSeenText = 'Online now';
    } else if (lastSeen != null) {
      final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen);
      final now = DateTime.now();
      final difference = now.difference(lastSeenDate);

      if (difference.inDays > 0) {
        lastSeenText =
            'Last seen ${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        lastSeenText =
            'Last seen ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        lastSeenText =
            'Last seen ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        lastSeenText = 'Last seen just now';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Chat Information',
          style: TextStyle(color: theme.colorScheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                child: Text(
                  displayName.isNotEmpty
                      ? displayName.substring(0, 2).toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Secure ID:', displayName, theme),
            const SizedBox(height: 8),
            _buildInfoRow('Status:', lastSeenText, theme),
            const SizedBox(height: 8),
            _buildInfoRow('Encryption:', 'End-to-end encrypted', theme),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  void _showClearChatDialog(Map<String, dynamic> chatRoom) {
    final theme = Theme.of(context);
    final displayName = chatRoom['displayName'] as String? ?? 'Unknown';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Clear Chat',
          style: TextStyle(color: theme.colorScheme.error),
        ),
        content: Text(
          'Are you sure you want to clear all messages with $displayName? This action cannot be undone.',
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _clearChat(chatRoom);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChat(Map<String, dynamic> chatRoom) async {
    try {
      final otherUserId = chatRoom['otherUserId'] as String?;
      if (otherUserId != null) {
        final success = await FirebaseMessageService.clearChat(otherUserId);
        if (success) {
          Helpers.showSnackBar(context, 'Chat cleared successfully');
          _loadChatRooms();
        } else {
          Helpers.showSnackBar(context, 'Failed to clear chat');
        }
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Error clearing chat: $e');
    }
  }
}
