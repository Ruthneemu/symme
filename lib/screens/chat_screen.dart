import 'package:flutter/material.dart';
import 'dart:async';
import '../models/message.dart';
import '../services/firebase_message_service.dart';
import '../services/storage_service.dart';
import '../widgets/chat_bubble.dart';
import '../utils/helpers.dart';
import '../utils/colors.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserSecureId;

  const ChatScreen({super.key, required this.otherUserSecureId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _otherUserId;
  String? _currentUserId;
  final bool _isOtherUserOnline = false;
  int _disappearingTimer = 0;
  StreamSubscription<List<Message>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _loadDisappearingTimer();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userId = await StorageService.getUserId();
      if (mounted) {
        setState(() => _currentUserId = userId);
      }
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  Future<void> _initializeChat() async {
    try {
      setState(() => _isLoading = true);

      setState(() {
        _otherUserId = widget.otherUserSecureId;
        _isLoading = false;
      });

      _listenToMessages();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to load chat: $e');
      }
    }
  }

  void _listenToMessages() {
    if (_otherUserId == null) return;

    _messagesSubscription = FirebaseMessageService.getMessages(_otherUserId!)
        .listen(
          (messages) {
            if (mounted) {
              setState(() => _messages = messages);
              _scrollToBottom();
            }
          },
          onError: (error) {
            print('Error listening to messages: $error');
            if (mounted) {
              Helpers.showSnackBar(context, 'Error loading messages: $error');
            }
          },
        );
  }

  Future<void> _loadDisappearingTimer() async {
    try {
      final timer = await StorageService.getDisappearingMessageTimer();
      if (mounted) {
        setState(() => _disappearingTimer = timer);
      }
    } catch (e) {
      print('Error loading disappearing timer: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final success = await FirebaseMessageService.sendMessage(
        receiverSecureId: widget.otherUserSecureId,
        content: text,
        type: MessageType.text,
        expiresInSeconds: _disappearingTimer > 0 ? _disappearingTimer : null,
      );

      if (success) {
        _messageController.clear();
        _scrollToBottom();
      } else {
        Helpers.showSnackBar(context, 'Failed to send message');
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Error sending message: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showDisappearingMessagesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Disappearing Messages',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set timer for new messages:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...[
              {'label': 'Off', 'value': 0},
              {'label': '1 Hour', 'value': 3600},
              {'label': '24 Hours', 'value': 86400},
              {'label': '7 Days', 'value': 604800},
              {'label': '30 Days', 'value': 2592000},
            ].map(
              (option) => RadioListTile<int>(
                activeColor: AppColors.primaryCyan,
                title: Text(
                  option['label'] as String,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                value: option['value'] as int,
                groupValue: _disappearingTimer,
                onChanged: (value) {
                  setState(() => _disappearingTimer = value ?? 0);
                  Navigator.pop(context);
                  _saveDisappearingTimer();
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDisappearingTimer() async {
    try {
      await StorageService.setDisappearingMessageTimer(_disappearingTimer);

      String timerText = 'Off';
      if (_disappearingTimer > 0) {
        if (_disappearingTimer < 86400) {
          timerText = '${(_disappearingTimer / 3600).round()} hour(s)';
        } else {
          timerText = '${(_disappearingTimer / 86400).round()} day(s)';
        }
      }

      Helpers.showSnackBar(context, 'Disappearing messages: $timerText');
    } catch (e) {
      Helpers.showSnackBar(context, 'Error saving timer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppGradients.appBarGradient),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserSecureId,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textOnPrimary,
                fontFamily: 'monospace',
              ),
            ),
            if (_isOtherUserOnline)
              const Text(
                'Online',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            color: AppColors.surfaceCard,
            onSelected: (value) {
              if (value == 'disappearing') {
                _showDisappearingMessagesDialog();
              } else if (value == 'clear_chat') {
                _showClearChatDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'disappearing',
                child: ListTile(
                  leading: const Icon(
                    Icons.timer,
                    color: AppColors.primaryCyan,
                  ),
                  title: const Text(
                    'Disappearing Messages',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    _disappearingTimer > 0
                        ? _getTimerText(_disappearingTimer)
                        : 'Off',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const PopupMenuItem(
                value: 'clear_chat',
                child: ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: AppColors.errorRed,
                  ),
                  title: Text(
                    'Clear Chat',
                    style: TextStyle(color: AppColors.errorRed),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryCyan,
                ),
              ),
            )
          : Column(
              children: [
                if (_disappearingTimer > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: AppColors.primaryCyan.withOpacity(0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer,
                          size: 16,
                          color: AppColors.primaryCyan,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Messages disappear after ${_getTimerText(_disappearingTimer)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: _buildMessagesList()),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: _buildMessageInput(),
                ),
              ],
            ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'This chat is end-to-end encrypted',
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              'Send your first message to start the conversation',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == _currentUserId;

        return ChatBubble(
          message: message,
          isMe: isMe,
          showTimestamp: _shouldShowTimestamp(index),
        );
      },
    );
  }

  bool _shouldShowTimestamp(int index) {
    if (index == 0) return true;
    final current = _messages[index];
    final previous = _messages[index - 1];
    return current.timestamp.difference(previous.timestamp).inMinutes > 30;
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: null,
                      maxLength: 4096,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            maxLength,
                            required isFocused,
                          }) => null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file,
                      color: AppColors.primaryCyan,
                    ),
                    onPressed: _showAttachmentOptions,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            backgroundColor: AppColors.primaryCyan,
            foregroundColor: AppColors.textOnPrimary,
            mini: true,
            onPressed: _isSending ? null : _sendMessage,
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textOnPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      backgroundColor: AppColors.surfaceCard,
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Attachment Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(Icons.camera_alt, 'Camera', 'camera'),
                _buildAttachmentOption(Icons.photo, 'Gallery', 'gallery'),
                _buildAttachmentOption(Icons.insert_drive_file, 'File', 'file'),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, String type) {
    return InkWell(
      onTap: () => _handleAttachment(type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.backgroundSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.primaryCyan),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  void _handleAttachment(String type) {
    Navigator.pop(context);
    Helpers.showSnackBar(context, '$type attachment coming soon!');
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Clear Chat',
          style: TextStyle(color: AppColors.errorRed),
        ),
        content: const Text(
          'This will delete all messages in this chat. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: AppColors.textOnPrimary,
            ),
            onPressed: () {
              Navigator.pop(context);
              _clearChat();
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChat() async {
    if (_otherUserId == null) {
      Helpers.showSnackBar(context, 'Cannot clear chat: missing user ID');
      return;
    }

    try {
      final success = await FirebaseMessageService.clearChat(_otherUserId!);
      if (success) {
        Helpers.showSnackBar(context, 'Chat cleared successfully');
        setState(() => _messages.clear());
      } else {
        Helpers.showSnackBar(context, 'Failed to clear chat');
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Failed to clear chat: $e');
    }
  }

  String _getTimerText(int seconds) {
    if (seconds < 3600) {
      return '${(seconds / 60).round()} minutes';
    } else if (seconds < 86400) {
      return '${(seconds / 3600).round()} hours';
    } else {
      return '${(seconds / 86400).round()} days';
    }
  }
}
