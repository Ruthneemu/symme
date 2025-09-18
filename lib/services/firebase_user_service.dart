import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:symme/models/user.dart';

class FirebaseUserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _usersCollection =
      _firestore.collection('users');

  static Future<AppUser?> getUserBySecureId(String secureId) async {
    try {
      final DocumentSnapshot doc = await _usersCollection.doc(secureId).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user by secureId: $e');
      return null;
    }
  }

  static Future<List<AppUser>> getAllUsers() async {
    try {
      final QuerySnapshot snapshot = await _usersCollection.get();
      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  static Future<List<AppUser>> searchUsersByName(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final QuerySnapshot snapshot = await _usersCollection
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error searching users by name: $e');
      return [];
    }
  }
}
