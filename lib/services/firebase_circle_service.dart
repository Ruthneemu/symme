import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:symme/models/circle.dart';

class FirebaseCircleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _circlesCollection = _firestore.collection('circles');

  static Future<String> createCircle(String name, String createdBy) async {
    try {
      final DocumentReference docRef = _circlesCollection.doc();
      final Circle newCircle = Circle(
        id: docRef.id,
        name: name,
        createdBy: createdBy,
        createdAt: Timestamp.now(),
        members: [createdBy],
      );

      await docRef.set(newCircle.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error creating circle: $e');
      rethrow;
    }
  }

  static Stream<QuerySnapshot> getCircles(String userSecureId) {
    return _circlesCollection
        .where('members', arrayContains: userSecureId)
        .snapshots();
  }

  static Future<void> addMemberToCircle(String circleId, String userSecureId) async {
    try {
      await _circlesCollection.doc(circleId).update({
        'members': FieldValue.arrayUnion([userSecureId])
      });
    } catch (e) {
      print('Error adding member to circle: $e');
      rethrow;
    }
  }
}
