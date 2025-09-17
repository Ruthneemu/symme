import 'package:flutter/material.dart';
import '../services/firebase_message_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/colors.dart';

class ChatTab extends StatelessWidget {
  final Function(String) onStartChat;

  const ChatTab({super.key, required this.onStartChat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseMessageService.getChatRooms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        final chatRooms = snapshot.data ?? [];
        if (chatRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 80, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(AppStrings.noChatsYet,
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text(AppStrings.addContactsToChat,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: chatRooms.length,
          itemBuilder: (context, index) {
            final chatRoom = chatRooms[index];
            return _buildChatRoomItem(chatRoom, theme);
          },
        );
      },
    );
  }

  Widget _buildChatRoomItem(Map<String, dynamic> chatRoom, ThemeData theme) {
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
      color: theme.colorScheme.surface,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Helpers.getColorFromId(secureId),
          child: Text(
            Helpers.getInitials(secureId),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          secureId,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          lastMessage ?? 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: lastMessage != null
                ? theme.colorScheme.onSurfaceVariant
                : theme.disabledColor,
          ),
        ),
        trailing: Text(timeText,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        onTap: () => onStartChat(secureId),
      ),
    );
  }
}
