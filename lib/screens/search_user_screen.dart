import 'package:flutter/material.dart';
import 'package:symme/models/user.dart';
import 'package:symme/services/firebase_user_service.dart';

class SearchUserScreen extends StatefulWidget {
  const SearchUserScreen({super.key});

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  bool _isLoading = false;

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    final results = await FirebaseUserService.searchUsersByName(query);

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search for a user'),
        backgroundColor: theme.colorScheme.surface,
      ),
      backgroundColor: theme.colorScheme.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                labelText: 'Search by name',
                labelStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          _isLoading
              ? CircularProgressIndicator(color: theme.colorScheme.primary)
              : Expanded(
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        title: Text(
                          user.name,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                        onTap: () => Navigator.of(context).pop(user),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
