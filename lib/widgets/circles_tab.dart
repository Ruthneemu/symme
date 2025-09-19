import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:symme/models/circle.dart';
import 'package:symme/screens/circle_details_screen.dart';
import 'package:symme/screens/create_circle_screen.dart';
import 'package:symme/services/firebase_circle_service.dart';

class CirclesTab extends StatefulWidget {
  final String userSecureId;
  const CirclesTab({super.key, required this.userSecureId});

  @override
  _CirclesTabState createState() => _CirclesTabState();
}

class _CirclesTabState extends State<CirclesTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseCircleService.getCircles(widget.userSecureId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'You are not a part of any circles yet.',
                style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
            );
          }

          final circles = snapshot.data!.docs
              .map((doc) => Circle.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: circles.length,
            itemBuilder: (context, index) {
              final circle = circles[index];
              return Card(
                color: theme.colorScheme.surface,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    circle.name,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            CircleDetailsScreen(circle: circle),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  CreateCircleScreen(userSecureId: widget.userSecureId),
            ),
          );
        },
        child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
      ),
    );
  }
}
