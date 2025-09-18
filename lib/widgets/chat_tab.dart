import 'package:flutter/material.dart';
import 'package:symmeapp/utils/colors.dart';
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
        print('Error loading chat rooms: $error');
        if (mounted) {
          setState(() => _isLoading = false);
          Helpers.showSnackBar(context, 'Failed to load chats: $error');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_chatRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_outlined,
              size: 80,
              color: AppColors.greyDark,
            ),
            const SizedBox(height: 16),
            const Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.greyLight,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a new chat by adding a contact\nor entering a secure ID',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.greyDark),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showStartChatDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.add_comment),
              label: const Text('Start New Chat'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search/Add chat header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.greyDark),
                  ),
                  child: TextField(
                    style: const TextStyle(color: AppColors.greyLight),
                    decoration: const InputDecoration(
                      hintText: 'Search chats or enter secure ID...',
                      hintStyle: TextStyle(color: AppColors.greyDark),
                      prefixIcon: Icon(Icons.search, color: AppColors.greyDark),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _handleSearchOrStartChat,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.gradient1,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _showStartChatDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        // Chat rooms list
        Expanded(
          child: ListView.builder(
            itemCount: _chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoom = _chatRooms[index];
              return _buildChatRoomItem(chatRoom);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatRoomItem(Map<String, dynamic> chatRoom) {
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
        timeString = 'Just now';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: AppColors.backgroundLight,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.secondary.withOpacity(0.2),
              child: Text(
                displayName.isNotEmpty
                    ? displayName.substring(0, 2).toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: AppColors.secondary,
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
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.backgroundLight,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: AppColors.primary,
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
              style: const TextStyle(color: AppColors.greyLight, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (timeString.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                timeString,
                style: const TextStyle(color: AppColors.greyDark, fontSize: 12),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.greyDark),
        onTap: () {
          if (otherUserSecureId.isNotEmpty) {
            widget.onStartChat(otherUserSecureId);
          }
        },
        onLongPress: () => _showChatOptions(chatRoom),
      ),
    );
  }

  void _handleSearchOrStartChat(String input) {
    final trimmedInput = input.trim();
    if (trimmedInput.isEmpty) return;

    // Check if it looks like a secure ID (12 characters, uppercase, alphanumeric)
    if (_isValidSecureId(trimmedInput)) {
      widget.onStartChat(trimmedInput);
    } else {
      // Search existing chats
      final matchingChats = _chatRooms.where((chat) {
        final displayName = chat['displayName'] as String? ?? '';
        final lastMessage = chat['lastMessage'] as String? ?? '';
        return displayName.toLowerCase().contains(trimmedInput.toLowerCase()) ||
            lastMessage.toLowerCase().contains(trimmedInput.toLowerCase());
      }).toList();

      if (matchingChats.isNotEmpty) {
        final firstMatch = matchingChats.first;
        final secureId = firstMatch['otherUserSecureId'] as String? ?? '';
        if (secureId.isNotEmpty) {
          widget.onStartChat(secureId);
        }
      } else {
        Helpers.showSnackBar(context, 'No matching chats found');
      }
    }
  }

  bool _isValidSecureId(String id) {
    return RegExp(r'^[A-Z0-9]{12}$').hasMatch(id);
  }

  void _showStartChatDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: const Text(
          'Start New Chat',
          style: TextStyle(color: AppColors.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the secure ID of the person you want to chat with:',
              style: TextStyle(color: AppColors.greyLight),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(
                color: AppColors.greyLight,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                hintText: 'e.g., ABC123XYZ789',
                hintStyle: TextStyle(color: AppColors.greyDark),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_add, color: AppColors.accent),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 12,
            ),
            const SizedBox(height: 8),
            const Text(
              'Secure IDs are 12 characters long and contain only letters and numbers.',
              style: TextStyle(color: AppColors.greyDark, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.greyDark),
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  void _showChatOptions(Map<String, dynamic> chatRoom) {
    final otherUserSecureId = chatRoom['otherUserSecureId'] as String? ?? '';
    final displayName = chatRoom['displayName'] as String? ?? otherUserSecureId;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.secondary.withOpacity(0.2),
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName.substring(0, 2).toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Chat Options',
                          style: const TextStyle(
                            color: AppColors.greyLight,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.greyDark),
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.accent),
              title: const Text(
                'Chat Info',
                style: TextStyle(color: AppColors.greyLight),
              ),
              onTap: () {
                Navigator.pop(context);
                _showChatInfo(chatRoom);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.notifications_off_outlined,
                color: AppColors.neonOrange,
              ),
              title: const Text(
                'Mute Notifications',
                style: TextStyle(color: AppColors.greyLight),
              ),
              onTap: () {
                Navigator.pop(context);
                Helpers.showSnackBar(context, 'Mute feature coming soon!');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Clear Chat',
                style: TextStyle(color: AppColors.greyLight),
              ),
              onTap: () {
                Navigator.pop(context);
                _showClearChatDialog(chatRoom);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showChatInfo(Map<String, dynamic> chatRoom) {
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
        backgroundColor: AppColors.backgroundLight,
        title: const Text(
          'Chat Information',
          style: TextStyle(color: AppColors.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.secondary.withOpacity(0.2),
                child: Text(
                  displayName.isNotEmpty
                      ? displayName.substring(0, 2).toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Secure ID:', displayName),
            const SizedBox(height: 8),
            _buildInfoRow('Status:', lastSeenText),
            const SizedBox(height: 8),
            _buildInfoRow('Encryption:', 'End-to-end encrypted'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.greyDark,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.greyLight,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  void _showClearChatDialog(Map<String, dynamic> chatRoom) {
    final displayName = chatRoom['displayName'] as String? ?? 'Unknown';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: const Text(
          'Clear Chat',
          style: TextStyle(color: AppColors.error),
        ),
        content: Text(
          'Are you sure you want to clear all messages with $displayName? This action cannot be undone.',
          style: const TextStyle(color: AppColors.greyLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.greyDark),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
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
          _loadChatRooms(); // Refresh the list
        } else {
          Helpers.showSnackBar(context, 'Failed to clear chat');
        }
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Error clearing chat: $e');
    }
  }
}
