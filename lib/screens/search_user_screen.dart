import 'package:flutter/material.dart';
import 'package:symme/models/user.dart';
import 'package:symme/services/firebase_user_service.dart';
import 'package:symme/utils/colors.dart';

class SearchUserScreen extends StatefulWidget {
  const SearchUserScreen({super.key});

  @override
  _SearchUserScreenState createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  bool _isLoading = false;

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final results = await FirebaseUserService.searchUsersByName(query);

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search for a user'),
        backgroundColor: AppColors.backgroundDark,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: const InputDecoration(
                labelText: 'Search by name',
                labelStyle: TextStyle(color: AppColors.greyLight),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.greyLight),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          _isLoading
              ? const CircularProgressIndicator(color: AppColors.primary)
              : Expanded(
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        title: Text(user.name,
                            style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.of(context).pop(user);
                        },
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
