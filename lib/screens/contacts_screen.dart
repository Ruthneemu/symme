import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/contact.dart';
import '../services/firebase_auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/contact_list_item.dart';
import '../widgets/qr_code_dialog.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';
import '../utils/colors.dart';

class ContactsScreen extends StatefulWidget {
  final VoidCallback onContactAdded;
  final Function(String) onStartChat;

  const ContactsScreen({
    super.key,
    required this.onContactAdded,
    required this.onStartChat,
  });

  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _secureIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  List<Contact> _contacts = [];
  bool _isLoading = true;
  String? _userSecureId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _secureIdController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final contacts = await StorageService.getContacts();
      final userSecureId = await StorageService.getUserSecureId();

      setState(() {
        _contacts = contacts;
        _userSecureId = userSecureId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Helpers.showSnackBar(context, 'Failed to load contacts: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Column(
      children: [
        // Your Secure ID Card
        if (_userSecureId != null)
          Container(
            margin: const EdgeInsets.all(16),
            child: Card(
              color: theme.colorScheme.surface,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Your Secure ID',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _userSecureId!,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy,
                                color: AppColors.secondary),
                            onPressed: () => _copySecureId(),
                            tooltip: 'Copy ID',
                          ),
                          IconButton(
                            icon: const Icon(Icons.qr_code,
                                color: AppColors.accent),
                            onPressed: () => _showQRCode(),
                            tooltip: 'Show QR Code',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share this ID with others to connect securely',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Add Contact Section
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Contact',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddContactDialog(),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add by ID'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showScanQRDialog(),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan QR'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Contacts List
        Expanded(
          child: _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 80,
                          color: theme.colorScheme.onSurface.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.noContactsYet,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.useQrOrInvite,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return Card(
                      color: theme.colorScheme.surface,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: ContactListItem(
                        contact: contact,
                        onTap: () => widget.onStartChat(contact.publicId),
                        onMessage: () => widget.onStartChat(contact.publicId),
                        onCall: () => _showCallDialog(contact),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _copySecureId() {
    if (_userSecureId != null) {
      Clipboard.setData(ClipboardData(text: _userSecureId!));
      Helpers.showSnackBar(context, 'Secure ID copied to clipboard');
    }
  }

  void _showQRCode() {
    if (_userSecureId != null) {
      showDialog(
        context: context,
        builder: (context) => QRCodeDialog(publicId: _userSecureId!),
      );
    }
  }

  void _showAddContactDialog() {
    _secureIdController.clear();
    _nameController.clear();

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('Add Contact',
            style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _secureIdController,
              decoration: const InputDecoration(
                labelText: 'Secure ID',
                hintText: 'Enter 12-character Secure ID',
                prefixIcon: Icon(Icons.security),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 12,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Contact Name (Optional)',
                hintText: 'Enter a name for this contact',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () => _addContact(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Add Contact'),
          ),
        ],
      ),
    );
  }

  void _showScanQRDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('Scan QR Code',
            style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(0.4)),
                    const SizedBox(height: 8),
                    Text(
                      'QR Scanner\nComing Soon!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }

  Future<void> _addContact() async {
    final secureId = _secureIdController.text.trim().toUpperCase();
    final name = _nameController.text.trim();

    if (secureId.isEmpty) {
      Helpers.showSnackBar(context, 'Please enter a Secure ID');
      return;
    }

    if (secureId.length != 12) {
      Helpers.showSnackBar(context, 'Secure ID must be 12 characters');
      return;
    }

    if (secureId == _userSecureId) {
      Helpers.showSnackBar(context, 'Cannot add your own Secure ID');
      return;
    }

    if (_contacts.any((c) => c.publicId == secureId)) {
      Helpers.showSnackBar(context, 'Contact already exists');
      return;
    }

    try {
      final userData = await FirebaseAuthService.getUserBySecureId(secureId);

      if (userData == null) {
        Helpers.showSnackBar(context, 'Secure ID not found or inactive');
        return;
      }

      final newContact = Contact(
        publicId: secureId,
        name: name.isNotEmpty ? name : 'User ${secureId.substring(0, 4)}',
        addedAt: DateTime.now(),
      );

      _contacts.add(newContact);
      await StorageService.saveContacts(_contacts);

      Navigator.pop(context);
      setState(() {});
      widget.onContactAdded();

      Helpers.showSnackBar(context, AppStrings.contactAdded);
    } catch (e) {
      Helpers.showSnackBar(context, 'Failed to add contact: ${e.toString()}');
    }
  }

  void _showCallDialog(Contact contact) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('Call ${contact.name}',
            style: TextStyle(color: theme.colorScheme.onSurface)),
        content: const Text(
          'Voice and video calling features are coming soon!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }
}
