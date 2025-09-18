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
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseCircleService.getCircles(widget.userSecureId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'You are not a part of any circles yet.',
                style: TextStyle(fontSize: 16),
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
              return ListTile(
                title: Text(circle.name),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CircleDetailsScreen(circle: circle),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  CreateCircleScreen(userSecureId: widget.userSecureId),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
