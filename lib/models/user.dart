import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String secureId;
  final String name;

  AppUser({required this.secureId, required this.name});

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return AppUser(
      secureId: doc.id,
      name: data['name'] ?? '',
    );
  }
}
