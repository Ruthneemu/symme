// services/call_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call.dart';
import '../services/storage_service.dart';

class CallService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final StreamController<Call> _incomingCallController = StreamController.broadcast();
  static final StreamController<Map<String, dynamic>> _callSignalController = StreamController.broadcast();
  
  static Stream<Call> get incomingCalls => _incomingCallController.stream;
  static Stream<Map<String, dynamic>> get callSignals => _callSignalController.stream;
  
  static StreamSubscription<QuerySnapshot>? _callsSubscription;
  static StreamSubscription<QuerySnapshot>? _signalsSubscription;

  static Future<void> initialize() async {
    await _listenForCalls();
    await _listenForCallSignals();
  }

  static Future<void> _listenForCalls() async {
    try {
      final currentUserId = await StorageService.getUserId();
      if (currentUserId == null) return;

      _callsSubscription = _firestore
          .collection('calls')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'incoming')
          .snapshots()
          .listen(
        (snapshot) {
          for (final doc in snapshot.docChanges) {
            if (doc.type == DocumentChangeType.added) {
              final call = Call.fromJson(doc.doc.data() as Map<String, dynamic>);
              _incomingCallController.add(call);
            }
          }
        },
        onError: (error) {
          print('Error listening for calls: $error');
        },
      );
    } catch (e) {
      print('Error setting up call listener: $e');
    }
  }

  static Future<void> _listenForCallSignals() async {
    try {
      final currentUserId = await StorageService.getUserId();
      if (currentUserId == null) return;

      _signalsSubscription = _firestore
          .collection('call_signals')
          .where('receiverId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          for (final doc in snapshot.docChanges) {
            if (doc.type == DocumentChangeType.added) {
              final data = doc.doc.data() as Map<String, dynamic>;
              _callSignalController.add(data);
              
              // Delete the signal after processing
              doc.doc.reference.delete();
            }
          }
        },
        onError: (error) {
          print('Error listening for call signals: $error');
        },
      );
    } catch (e) {
      print('Error setting up call signals listener: $e');
    }
  }

  static Future<bool> initiateCall({
    required String receiverSecureId,
    required CallType callType,
  }) async {
    try {
      final currentUserId = await StorageService.getUserId();
      final currentUserSecureId = await StorageService.getUserSecureId();
      
      if (currentUserId == null || currentUserSecureId == null) {
        return false;
      }

      // Check if receiver exists and get their user ID
      final receiverQuery = await _firestore
          .collection('users')
          .where('secureId', isEqualTo: receiverSecureId)
          .limit(1)
          .get();

      if (receiverQuery.docs.isEmpty) {
        throw Exception('User not found');
      }

      final receiverUserId = receiverQuery.docs.first.id;
      final callId = DateTime.now().millisecondsSinceEpoch.toString();

      final call = Call(
        id: callId,
        callerId: currentUserId,
        receiverId: receiverUserId,
        type: callType,
        status: CallStatus.outgoing,
        timestamp: DateTime.now(),
        callerName: currentUserSecureId,
        receiverName: receiverSecureId,
      );

      // Save call record
      await _firestore
          .collection('calls')
          .doc(callId)
          .set(call.toJson());

      return true;
    } catch (e) {
      print('Error initiating call: $e');
      return false;
    }
  }

  static Future<bool> answerCall(String callId) async {
    try {
      await _firestore
          .collection('calls')
          .doc(callId)
          .update({
        'status': CallStatus.connecting.toString().split('.').last,
        'answeredAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error answering call: $e');
      return false;
    }
  }

  static Future<bool> declineCall(String callId) async {
    try {
      await _firestore
          .collection('calls')
          .doc(callId)
          .update({
        'status': CallStatus.declined.toString().split('.').last,
        'endedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error declining call: $e');
      return false;
    }
  }

  static Future<bool> endCall(String callId, {int? duration}) async {
    try {
      final updateData = {
        'status': CallStatus.ended.toString().split('.').last,
        'endedAt': FieldValue.serverTimestamp(),
      };

      if (duration != null) {
        updateData['duration'] = duration;
      }

      await _firestore
          .collection('calls')
          .doc(callId)
          .update(updateData);

      return true;
    } catch (e) {
      print('Error ending call: $e');
      return false;
    }
  }

  static Stream<List<Call>> getCallHistory() {
    return const Stream.empty(); // Implement based on your needs
  }

  static Future<List<Call>> getRecentCalls({int limit = 50}) async {
    try {
      final currentUserId = await StorageService.getUserId();
      if (currentUserId == null) return [];

      final query = await _firestore
          .collection('calls')
          .where('callerId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final receivedQuery = await _firestore
          .collection('calls')
          .where('receiverId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final allCalls = <Call>[];
      
      for (final doc in query.docs) {
        allCalls.add(Call.fromJson(doc.data()));
      }
      
      for (final doc in receivedQuery.docs) {
        allCalls.add(Call.fromJson(doc.data()));
      }

      // Sort by timestamp
      allCalls.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return allCalls.take(limit).toList();
    } catch (e) {
      print('Error getting recent calls: $e');
      return [];
    }
  }

  static Future<void> markCallAsMissed(String callId) async {
    try {
      await _firestore
          .collection('calls')
          .doc(callId)
          .update({
        'status': CallStatus.missed.toString().split('.').last,
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking call as missed: $e');
    }
  }

  static Future<void> clearCallHistory() async {
    try {
      final currentUserId = await StorageService.getUserId();
      if (currentUserId == null) return;

      final batch = _firestore.batch();

      // Delete calls where user is caller
      final callerQuery = await _firestore
          .collection('calls')
          .where('callerId', isEqualTo: currentUserId)
          .get();

      for (final doc in callerQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete calls where user is receiver
      final receiverQuery = await _firestore
          .collection('calls')
          .where('receiverId', isEqualTo: currentUserId)
          .get();

      for (final doc in receiverQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error clearing call history: $e');
    }
  }

  static Future<void> cleanupOldCalls() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final query = await _firestore
          .collection('calls')
          .where('timestamp', isLessThan: thirtyDaysAgo.millisecondsSinceEpoch)
          .get();

      final batch = _firestore.batch();
      
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Cleaned up ${query.docs.length} old calls');
    } catch (e) {
      print('Error cleaning up old calls: $e');
    }
  }

  static void dispose() {
    _callsSubscription?.cancel();
    _signalsSubscription?.cancel();
    _incomingCallController.close();
    _callSignalController.close();
  }
}