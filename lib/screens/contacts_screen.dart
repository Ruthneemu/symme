import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/contact.dart';
import '../services/firebase_auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/contact_list_item.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';
import 'qr_code_screen.dart';
import '../services/call_manager.dart';
import '../models/call.dart';

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
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Column(
        children: [
          // Your Secure ID Card
          if (_userSecureId != null)
            Container(
              margin: const EdgeInsets.all(16),
              child: Card(
                color: theme.colorScheme.surface, // 👈 respect theme
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: theme.colorScheme.primary,
                          ),
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
                          color: theme.colorScheme.surfaceVariant,
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
                              icon: const Icon(Icons.copy),
                              color: theme.colorScheme.primary,
                              onPressed: () => _copySecureId(),
                              tooltip: 'Copy ID',
                            ),
                            IconButton(
                              icon: const Icon(Icons.qr_code),
                              color: theme.colorScheme.primary,
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
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _scanQRCode(),
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
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
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
      ),
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QrCodeScreen(publicId: _userSecureId!),
        ),
      );
    }
  }

  void _showAddContactDialog() {
    _secureIdController.clear();
    _nameController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Contact'),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _addContact(),
            child: const Text('Add Contact'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanQRCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const QrCodeScreen(startInScanMode: true),
      ),
    );

    if (result != null) {
      _addContact(qrData: result);
    }
  }

  Future<void> _addContact({String? qrData}) async {
    final secureId = qrData ?? _secureIdController.text.trim().toUpperCase();
    final name = _nameController.text.trim();

    if (secureId.isEmpty) {
      Helpers.showSnackBar(context, 'Please enter a Secure ID');
      return;
    }

    if (secureId.length != 12) {
      Helpers.showSnackBar(context, 'Invalid Secure ID');
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

      if (qrData == null) {
        Navigator.pop(context);
      }
      setState(() {});
      widget.onContactAdded();

      Helpers.showSnackBar(context, AppStrings.contactAdded);
    } catch (e) {
      Helpers.showSnackBar(context, 'Failed to add contact: ${e.toString()}');
    }
  }

  void _showCallDialog(Contact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Call ${contact.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.call),
              title: const Text('Voice Call'),
              onTap: () {
                Navigator.pop(context);
                _initiateCall(contact.publicId, CallType.audio);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video Call'),
              onTap: () {
                Navigator.pop(context);
                _initiateCall(contact.publicId, CallType.video);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Debug Call Setup'),
              onTap: () {
                Navigator.pop(context);
                _debugCall(contact.publicId, CallType.audio);
              },
            ),
          ],
        ),
      ),
    );
  }
  // Updated _initiateCall method for your ContactsScreen

  Future<void> _initiateCall(String secureId, CallType callType) async {
    try {
      if (!CallManager.instance.hasActiveCall) {
        final contact = _contacts.firstWhere((c) => c.publicId == secureId);
        _showCallingDialog(contact.name, callType);

        await CallManager.instance.startCall(
          receiverSecureId: secureId,
          callType: callType,
        );
      } else {
        Helpers.showSnackBar(context, 'Another call is already in progress');
      }
    } catch (e) {
      print('Call initiation failed: $e');
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Helpers.showSnackBar(context, 'Failed to start call: ${e.toString()}');
    }
  }

  // Debug method to help identify issues
  Future<void> _debugCall(String secureId, CallType callType) async {
    print('=== DEBUGGING CALL TO: $secureId ===');

    // Debug current user
    await _debugCurrentUser();

    // Debug contact lookup
    await _debugContactLookup(secureId);

    // Show debug results
    _showDebugResults(secureId);

    print('=== END DEBUG ===');
  }

  Future<void> _debugCurrentUser() async {
    print('--- CURRENT USER DEBUG ---');

    final currentUser = FirebaseAuth.instance.currentUser;
    print('Firebase Auth User: ${currentUser?.uid}');

    final storedUserId = await StorageService.getUserId();
    final storedSecureId = await StorageService.getUserSecureId();
    print('Stored User ID: $storedUserId');
    print('Stored Secure ID: $storedSecureId');

    if (currentUser != null) {
      try {
        final userSnapshot = await FirebaseDatabase.instance
            .ref('users/${currentUser.uid}')
            .once();

        if (userSnapshot.snapshot.exists) {
          final userData = userSnapshot.snapshot.value as Map<dynamic, dynamic>;
          print('Realtime DB User Data: $userData');
        } else {
          print('ERROR: User not found in Realtime Database!');
        }
      } catch (e) {
        print('ERROR checking Realtime DB: $e');
      }
    }
  }

  Future<void> _debugContactLookup(String secureId) async {
    print('--- CONTACT LOOKUP DEBUG: $secureId ---');

    // Try FirebaseAuthService
    try {
      final userData = await FirebaseAuthService.getUserBySecureId(secureId);
      if (userData != null) {
        print('Found via FirebaseAuthService: $userData');
      } else {
        print('NOT found via FirebaseAuthService');
      }
    } catch (e) {
      print('ERROR with FirebaseAuthService: $e');
    }

    // Check secureId mapping
    try {
      final secureIdSnapshot = await FirebaseDatabase.instance
          .ref('secureIds/$secureId')
          .once();

      if (secureIdSnapshot.snapshot.exists) {
        final mapping =
            secureIdSnapshot.snapshot.value as Map<dynamic, dynamic>;
        print('SecureID mapping: $mapping');

        final userId = mapping['userId'];
        if (userId != null) {
          final userSnapshot = await FirebaseDatabase.instance
              .ref('users/$userId')
              .once();

          if (userSnapshot.snapshot.exists) {
            print('Mapped user data: ${userSnapshot.snapshot.value}');
          } else {
            print('ERROR: Mapped user not found!');
          }
        }
      } else {
        print('ERROR: SecureID mapping not found!');
      }
    } catch (e) {
      print('ERROR checking secureId mapping: $e');
    }
  }

  void _showDebugResults(String secureId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Results'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contact Secure ID: $secureId'),
              Text('Check console for detailed logs'),
              const SizedBox(height: 16),
              const Text('Common Issues:'),
              const Text('• Contact not registered'),
              const Text('• User missing from database'),
              const Text('• CallManager not initialized'),
              const Text('• Network connectivity'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initiateCall(secureId, CallType.audio);
            },
            child: const Text('Try Call Anyway'),
          ),
        ],
      ),
    );
  }

  void _showCallingDialog(String contactName, CallType callType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Calling $contactName...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              callType == CallType.video ? 'Video Call' : 'Voice Call',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              CallManager.instance.endCall();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
