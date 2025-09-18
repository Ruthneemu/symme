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
          _currentCircle.id, user.secureId);
      setState(() {
        _currentCircle.members.add(user.secureId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentCircle.name),
        backgroundColor: AppColors.backgroundDark,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: ListView.builder(
        itemCount: _currentCircle.members.length,
        itemBuilder: (context, index) {
          final memberId = _currentCircle.members[index];
          return FutureBuilder<AppUser?>(
            future: FirebaseUserService.getUserBySecureId(memberId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(
                  title:
                      Text('Loading...', style: TextStyle(color: Colors.white)),
                );
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return ListTile(
                  title: Text(memberId,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: const Text('User not found',
                      style: TextStyle(color: Colors.red)),
                );
              }

              final user = snapshot.data!;
              return ListTile(
                title: Text(user.name,
                    style: const TextStyle(color: Colors.white)),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final selectedUser = await Navigator.of(context).push<AppUser>(
            MaterialPageRoute(
              builder: (context) => const SearchUserScreen(),
            ),
          );

          if (selectedUser != null) {
            await _addMember(selectedUser);
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
