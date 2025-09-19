import 'package:flutter/material.dart';
import 'package:symme/models/circle.dart';
import 'package:symme/models/user.dart';
import 'package:symme/screens/search_user_screen.dart';
import 'package:symme/services/firebase_circle_service.dart';
import 'package:symme/services/firebase_user_service.dart';
import 'package:symme/utils/colors.dart';

class CircleDetailsScreen extends StatefulWidget {
  final Circle circle;

  const CircleDetailsScreen({super.key, required this.circle});

  @override
  _CircleDetailsScreenState createState() => _CircleDetailsScreenState();
}

class _CircleDetailsScreenState extends State<CircleDetailsScreen> {
  late Circle _currentCircle;

  @override
  void initState() {
    super.initState();
    _currentCircle = widget.circle;
  }

  Future<void> _addMember(AppUser user) async {
    if (!_currentCircle.members.contains(user.secureId)) {
      await FirebaseCircleService.addMemberToCircle(
        _currentCircle.id,
        user.secureId,
      );
      setState(() {
        _currentCircle.members.add(user.secureId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentCircle.name,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onPrimary,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppGradients.appBarGradient),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView.builder(
        itemCount: _currentCircle.members.length,
        itemBuilder: (context, index) {
          final memberId = _currentCircle.members[index];
          return FutureBuilder<AppUser?>(
            future: FirebaseUserService.getUserBySecureId(memberId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListTile(
                  title: Text('Loading...', style: theme.textTheme.bodyLarge),
                );
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return ListTile(
                  title: Text(memberId, style: theme.textTheme.bodyLarge),
                  subtitle: Text(
                    'User not found',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                );
              }

              final user = snapshot.data!;
              return ListTile(
                title: Text(user.name, style: theme.textTheme.bodyLarge),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final selectedUser = await Navigator.of(context).push<AppUser>(
            MaterialPageRoute(builder: (context) => const SearchUserScreen()),
          );

          if (selectedUser != null) {
            await _addMember(selectedUser);
          }
        },
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
