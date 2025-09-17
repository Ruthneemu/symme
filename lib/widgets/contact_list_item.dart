import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../utils/helpers.dart';

class ContactListItem extends StatelessWidget {
  final Contact contact;
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final bool showActions;

  const ContactListItem({
    super.key,
    required this.contact,
    this.onTap,
    this.onCall,
    this.onMessage,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final subtleColor = theme.colorScheme.onSurface.withOpacity(0.6);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Helpers.getColorFromId(contact.publicId),
        child: Text(
          Helpers.getInitials(contact.name),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        contact.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ID: ${contact.publicId}',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: subtleColor,
            ),
          ),
          if (contact.isOnline)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            )
          else if (contact.lastSeen != null)
            Text(
              'Last seen: ${contact.lastSeen}',
              style: TextStyle(
                fontSize: 12,
                color: subtleColor,
              ),
            ),
        ],
      ),
      trailing: showActions
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.call, color: theme.colorScheme.primary),
                  onPressed: onCall,
                  tooltip: 'Call',
                ),
                IconButton(
                  icon: Icon(Icons.message, color: theme.colorScheme.primary),
                  onPressed: onMessage,
                  tooltip: 'Message',
                ),
              ],
            )
          : null,
      onTap: onTap,
    );
  }
}
