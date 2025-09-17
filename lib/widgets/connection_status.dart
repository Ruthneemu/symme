import 'package:flutter/material.dart';
import '../utils/colors.dart';

class ConnectionStatus extends StatelessWidget {
  final String connectionStatus;
  final VoidCallback onRefresh;
  final VoidCallback onRegenerateId;
  final VoidCallback onCleanup;

  const ConnectionStatus({
    super.key,
    required this.connectionStatus,
    required this.onRefresh,
    required this.onRegenerateId,
    required this.onCleanup,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: connectionStatus == 'Connected'
                ? AppColors.success
                : AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        Text(connectionStatus,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        PopupMenuButton<String>(
          color: theme.colorScheme.surface,
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                onRefresh();
                break;
              case 'regenerate_id':
                onRegenerateId();
                break;
              case 'cleanup':
                onCleanup();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'refresh', child: Text("Refresh")),
            const PopupMenuItem(value: 'regenerate_id', child: Text("Regenerate ID")),
            const PopupMenuItem(value: 'cleanup', child: Text("Clean Messages")),
          ],
        )
      ],
    );
  }
}
