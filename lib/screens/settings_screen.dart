import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:symme/providers/theme_provider.dart';
import 'package:symme/screens/chat_screen.dart';
import 'package:symme/screens/qr_code_screen.dart';
import '../widgets/identity_card.dart';
import '../services/storage_service.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  final String userPublicId;
  final VoidCallback onClearData;
  final VoidCallback onRegenerateId;

  const SettingsScreen({
    super.key,
    required this.userPublicId,
    required this.onClearData,
    required this.onRegenerateId,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _disappearingTimer = 604800; // 7 days default
  bool _autoDeleteExpired = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final timer = await StorageService.getDisappearingMessageTimer();
    final autoDelete = await StorageService.getAutoDeleteExpired();
    setState(() {
      _disappearingTimer = timer;
      _autoDeleteExpired = autoDelete;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 12),
          IdentityCard(publicId: widget.userPublicId),

          /// Appearance
          _buildSection(context, 'Appearance', [
            ListTile(
              leading: Icon(Icons.dark_mode, color: theme.colorScheme.primary),
              title: const Text("Dark Mode"),
              subtitle: Text(
                themeProvider.themeMode == ThemeMode.dark
                    ? "Enabled"
                    : "Disabled",
                style: theme.textTheme.bodySmall,
              ),
              trailing: Switch(
                value: themeProvider.themeMode == ThemeMode.dark,
                onChanged: themeProvider.toggleTheme,
              ),
            ),
          ]),

          /// Privacy & Security
          _buildSection(context, 'Privacy & Security', [
            ListTile(
              leading: Icon(Icons.security, color: theme.colorScheme.secondary),
              title: const Text('End-to-End Encryption'),
              subtitle: const Text('All messages are encrypted'),
              trailing: Icon(
                Icons.check_circle,
                color: theme.colorScheme.tertiary,
              ),
            ),
            ListTile(
              leading: Icon(Icons.timer, color: theme.colorScheme.primary),
              title: const Text('Disappearing Messages'),
              subtitle: Text(_getDisappearingTimerText()),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onTap: () => _showDisappearingMessagesDialog(context),
            ),
            ListTile(
              leading: Icon(
                Icons.auto_delete,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('Auto-delete Expired'),
              subtitle: const Text('Automatically clean up expired messages'),
              trailing: Switch(
                value: _autoDeleteExpired,
                onChanged: (value) async {
                  setState(() => _autoDeleteExpired = value);
                  await StorageService.setAutoDeleteExpired(value);
                },
              ),
            ),
            ListTile(
              leading: Icon(Icons.block, color: theme.colorScheme.error),
              title: const Text('Blocked Contacts'),
              subtitle: const Text('Manage blocked users'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onTap: () => _showBlockedContactsDialog(context),
            ),
          ]),

          /// Identity
          _buildSection(context, 'Identity', [
            ListTile(
              leading: Icon(Icons.qr_code, color: theme.colorScheme.primary),
              title: const Text('Share Secure ID'),
              subtitle: const Text('Share or scan a Secure ID'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onTap: () => _navigateToQrScreen(context),
            ),
            ListTile(
              leading: Icon(Icons.refresh, color: theme.colorScheme.secondary),
              title: const Text('Regenerate Secure ID'),
              subtitle: const Text('Generate a new Secure ID'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onTap: () => _showRegenerateIdDialog(context),
            ),
            ListTile(
              leading: Icon(Icons.key, color: theme.colorScheme.tertiary),
              title: const Text('Encryption Keys'),
              subtitle: const Text('Rotate encryption keys'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onTap: () => _showKeyRotationDialog(context),
            ),
          ]),

          /// Application
          _buildSection(context, 'Application', [
            ListTile(
              leading: Icon(
                Icons.info_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('About'),
              subtitle: Text('Version ${AppConstants.appVersion}'),
              onTap: () => _showAboutDialog(context),
            ),
            ListTile(
              leading: Icon(
                Icons.help_outline,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Help & Support'),
              subtitle: const Text('Get help using SecureChat'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onTap: () => _showHelpDialog(context),
            ),
            ListTile(
              leading: Icon(
                Icons.cleaning_services,
                color: theme.colorScheme.secondary,
              ),
              title: const Text('Clear Messages'),
              subtitle: const Text('Delete all messages (keep contacts)'),
              onTap: () => _showClearMessagesDialog(context),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: theme.colorScheme.error,
              ),
              title: const Text('Clear All Data'),
              subtitle: const Text('Delete all messages and contacts'),
              onTap: () => _showClearDataDialog(context),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
          color: theme.colorScheme.surface,
          child: Column(children: children),
        ),
      ],
    );
  }

  Future<void> _navigateToQrScreen(BuildContext context) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => QrCodeScreen(publicId: widget.userPublicId),
      ),
    );

    if (result != null && result.isNotEmpty) {
      _handleScannedCode(result);
    }
  }

  void _handleScannedCode(String code) {
    Helpers.showConfirmDialog(
      context: context,
      title: 'Start a new chat?',
      content: 'Do you want to start a new chat with $code?',
      onConfirm: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(otherUserSecureId: code),
          ),
        );
      },
    );
  }

  String _getDisappearingTimerText() {
    if (_disappearingTimer == 0) return 'Off';
    if (_disappearingTimer < 3600) return '${_disappearingTimer ~/ 60} minutes';
    if (_disappearingTimer < 86400) {
      return '${_disappearingTimer ~/ 3600} hours';
    }
    return '${_disappearingTimer ~/ 86400} days';
  }

  void _showDisappearingMessagesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disappearing Messages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose default timer for disappearing messages:'),
            const SizedBox(height: 16),
            ...[
              {'label': 'Off', 'value': 0},
              {'label': '1 Hour', 'value': 3600},
              {'label': '24 Hours', 'value': 86400},
              {'label': '7 Days', 'value': 604800},
              {'label': '30 Days', 'value': 2592000},
            ].map(
              (option) => RadioListTile<int>(
                title: Text(option['label'] as String),
                value: option['value'] as int,
                groupValue: _disappearingTimer,
                onChanged: (value) async {
                  setState(() {
                    _disappearingTimer = value ?? 0;
                  });
                  await StorageService.setDisappearingMessageTimer(
                    _disappearingTimer,
                  );
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showBlockedContactsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blocked Contacts'),
        content: const Text('No blocked contacts yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRegenerateIdDialog(BuildContext context) {
    Helpers.showConfirmDialog(
      context: context,
      title: 'Regenerate Secure ID',
      content:
          'This will generate a new Secure ID for you. Your existing contacts will need to add your new ID to continue chatting. This action cannot be undone.',
      onConfirm: widget.onRegenerateId,
      confirmText: 'Regenerate',
      cancelText: 'Cancel',
    );
  }

  void _showKeyRotationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encryption Keys'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your encryption keys are used to secure your messages.'),
            SizedBox(height: 8),
            Text(
              'Key rotation is automatic and happens when you regenerate your Secure ID.',
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

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationIcon: const Icon(Icons.security, size: 48),
      children: const [
        Text(
          'A secure communication app that protects your privacy with end-to-end encryption.',
        ),
        SizedBox(height: 16),
        Text('Features:'),
        Text('• End-to-end encryption'),
        Text('• No phone numbers required'),
        Text('• Secure contact system'),
        Text('• Message expiration'),
        Text('• Firebase real-time messaging'),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to use SecureChat:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Share your Secure ID with others'),
            Text('2. Add contacts using their Secure ID'),
            Text('3. Start chatting securely!'),
            SizedBox(height: 16),
            Text(
              'Your messages are encrypted and automatically expire after 7 days by default.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showClearMessagesDialog(BuildContext context) {
    Helpers.showConfirmDialog(
      context: context,
      title: 'Clear All Messages',
      content:
          'This will delete all your messages but keep your contacts and settings. This action cannot be undone.',
      onConfirm: () async {
        try {
          await StorageService.clearAllMessages();
          Helpers.showSnackBar(context, 'All messages cleared');
        } catch (e) {
          Helpers.showSnackBar(context, 'Failed to clear messages');
        }
      },
      confirmText: 'Clear Messages',
      cancelText: 'Cancel',
    );
  }

  void _showClearDataDialog(BuildContext context) {
    Helpers.showConfirmDialog(
      context: context,
      title: 'Clear All Data',
      content:
          'This will permanently delete all your messages, contacts, and settings. This action cannot be undone.',
      onConfirm: () {
        widget.onClearData();
        Helpers.showSnackBar(context, 'All data cleared');
      },
      confirmText: 'Delete All',
      cancelText: 'Cancel',
    );
  }
}
