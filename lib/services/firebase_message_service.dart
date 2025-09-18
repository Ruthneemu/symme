import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';
import '../services/crypto_service.dart';
import '../services/storage_service.dart';
import 'dart:async';
import '../models/call.dart';
import '../services/firebase_auth_service.dart';

class FirebaseMessageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send encrypted message - FIXED VERSION
  static Future<bool> sendMessage({
    required String receiverSecureId,
    required String content,
    required MessageType type,
    int? expiresInSeconds,
  }) async {
    try {
      final sender = _auth.currentUser;
      if (sender == null) {
        print('ERROR: No authenticated user found');
        return false;
      }

      print('Attempting to send message to: $receiverSecureId');

      // Get receiver data using the FirebaseAuthService method
      final receiverData = await FirebaseAuthService.getUserBySecureId(receiverSecureId);
      if (receiverData == null) {
        print('ERROR: Receiver not found for secure ID: $receiverSecureId');
        return false;
      }

      final receiverPublicKey = receiverData['publicKey'] as String?;
      final receiverId = receiverData['userId'] as String?;

      if (receiverPublicKey == null || receiverId == null) {
        print('ERROR: Missing receiver data - publicKey: $receiverPublicKey, userId: $receiverId');
        return false;
      }

      // Get sender's secure ID
      final senderSecureId = await StorageService.getUserSecureId();
      if (senderSecureId == null) {
        print('ERROR: Sender secure ID is null');
        return false;
      }

      print('Encrypting message...');
      // Encrypt message
      final encryptionResult = CryptoService.encryptMessage(
        content,
        receiverPublicKey,
      );

      // Create message object
      final messageId = CryptoService.generateMessageId();
      final now = DateTime.now();
      final expirationSeconds = expiresInSeconds ?? (7 * 24 * 60 * 60); // 7 days default

      final message = Message(
        id: messageId,
        senderId: sender.uid,
        receiverId: receiverId,
        content: encryptionResult['encryptedMessage']!,
        type: type,
        timestamp: now,
        isEncrypted: true,
        expiresInSeconds: expirationSeconds,
      );

      // Prepare message data for Firebase
      final messageData = message.toJson();
      messageData['encryptedCombination'] = encryptionResult['encryptedCombination'];
      messageData['combinationId'] = encryptionResult['combinationId'];
      messageData['iv'] = encryptionResult['iv'];
      messageData['senderSecureId'] = senderSecureId;
      messageData['receiverSecureId'] = receiverSecureId;
      messageData['expiresAt'] = now
          .add(Duration(seconds: expirationSeconds))
          .millisecondsSinceEpoch;

      print('Saving message to Firebase...');

      // Store message in BOTH sender's and receiver's paths
      // This ensures both users can see the conversation
      await Future.wait([
        // Save in sender's path
        _database
            .child('messages/${sender.uid}/$receiverId/$messageId')
            .set(messageData),
        // Save in receiver's path
        _database
            .child('messages/$receiverId/${sender.uid}/$messageId')
            .set(messageData),
      ]);

      print('Updating chat rooms...');
      
      // Update chat room info for both users
      await Future.wait([
        _updateChatRoom(sender.uid, receiverId, message, receiverSecureId),
        _updateChatRoom(receiverId, sender.uid, message, senderSecureId),
      ]);

      // Store sender's copy locally with unencrypted content
      final localMessage = message.copyWith(
        content: content, // Store unencrypted for sender
      );
      await _storeMessageLocally(sender.uid, receiverId, localMessage);

      print('Message sent successfully!');
      return true;
    } catch (e, stackTrace) {
      print('ERROR sending message: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // Get messages for a chat - IMPROVED VERSION
  static Stream<List<Message>> getMessages(String otherUserSecureId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _getUserBySecureId(otherUserSecureId).asStream().asyncExpand((otherUserData) {
      if (otherUserData == null) return Stream.value(<Message>[]);
      
      final otherUserId = otherUserData['userId'] as String;
      
      // Listen to messages in the current user's chat with the other user
      return _database
          .child('messages/${currentUser.uid}/$otherUserId')
          .onValue
          .asyncMap((event) async {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data == null) return <Message>[];

        final messages = <Message>[];
        for (final messageEntry in data.entries) {
          try {
            final messageData = messageEntry.value as Map<dynamic, dynamic>;
            
            // Convert to proper Map<String, dynamic>
            final messageMap = Map<String, dynamic>.from(messageData);
            
            // Try to decrypt if this is an encrypted message for us
            if (messageMap['isEncrypted'] == true && 
                messageMap['receiverId'] == currentUser.uid) {
              
              final privateKey = await StorageService.getUserPrivateKey();
              if (privateKey != null && messageMap['encryptedCombination'] != null) {
                final decryptedContent = CryptoService.decryptMessageWithCombination(
                  messageMap['content'],
                  messageMap['encryptedCombination'],
                  privateKey,
                );
                
                if (decryptedContent != null) {
                  messageMap['content'] = decryptedContent;
                } else {
                  messageMap['content'] = '[Encrypted Message - Cannot Decrypt]';
                }
              }
            }
            
            final message = Message.fromJson(messageMap);
            messages.add(message);
          } catch (e) {
            print('Error parsing message: $e');
          }
        }

        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return messages;
      });
    });
  }

  // Helper method to get user by secure ID
  static Future<Map<String, dynamic>?> _getUserBySecureId(String secureId) async {
    return await FirebaseAuthService.getUserBySecureId(secureId);
  }

  // Updated chat room update method
  static Future<void> _updateChatRoom(
    String userId1,
    String userId2,
    Message lastMessage,
    String otherUserSecureId,
  ) async {
    try {
      final chatRoomId = CryptoService.generateRoomId(userId1, userId2);

      await _database.child('chatRooms/$userId1/$userId2').update({
        'roomId': chatRoomId,
        'otherUserSecureId': otherUserSecureId,
        'lastMessage': lastMessage.type == MessageType.text
            ? lastMessage.content.length > 50 
                ? '${lastMessage.content.substring(0, 50)}...'
                : lastMessage.content
            : '[${lastMessage.type.name}]',
        'lastMessageTime': lastMessage.timestamp.millisecondsSinceEpoch,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error updating chat room: $e');
    }
  }

  // Store message locally
  static Future<void> _storeMessageLocally(
    String senderId,
    String receiverId,
    Message message,
  ) async {
    try {
      final roomId = CryptoService.generateRoomId(senderId, receiverId);
      final messages = await StorageService.getMessages(roomId);
      messages.add(message);
      await StorageService.saveMessages(roomId, messages);
    } catch (e) {
      print('Error storing message locally: $e');
    }
  }

  // Mark message as read
  static Future<void> markMessageAsRead(
    String messageId,
    String otherUserId,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _database
          .child('messages/${currentUser.uid}/$otherUserId/$messageId')
          .update({'isRead': true});
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  // Clean up expired messages
  static Future<void> cleanupExpiredMessages() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final snapshot = await _database
          .child('messages/${currentUser.uid}')
          .once();
      final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        final now = DateTime.now().millisecondsSinceEpoch;

        for (final chatEntry in data.entries) {
          final chatData = chatEntry.value as Map<dynamic, dynamic>;

          for (final messageEntry in chatData.entries) {
            final messageData = messageEntry.value as Map<dynamic, dynamic>;
            final expiresAt = messageData['expiresAt'] as int?;

            if (expiresAt != null && now > expiresAt) {
              try {
                await _database
                    .child(
                      'messages/${currentUser.uid}/${chatEntry.key}/${messageEntry.key}',
                    )
                    .remove();
              } catch (e) {
                print('Error deleting expired message ${messageEntry.key}: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error cleaning up expired messages: $e');
    }
  }

  // Get chat rooms
  static Stream<List<Map<String, dynamic>>> getChatRooms() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _database.child('chatRooms/${currentUser.uid}').onValue.asyncMap((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <Map<String, dynamic>>[];

      final chatRooms = <Map<String, dynamic>>[];

      for (final entry in data.entries) {
        try {
          final chatData = entry.value as Map<dynamic, dynamic>;
          final otherUserId = entry.key as String;
          final otherUserSecureId = chatData['otherUserSecureId'] as String?;

          if (otherUserSecureId != null) {
            // Get other user's current info
            final otherUserData = await FirebaseAuthService.getUserBySecureId(otherUserSecureId);
            
            chatRooms.add({
              'otherUserId': otherUserId,
              'otherUserSecureId': otherUserSecureId,
              'lastMessage': chatData['lastMessage'],
              'lastMessageTime': chatData['lastMessageTime'],
              'roomId': chatData['roomId'],
              'isOnline': otherUserData?['isActive'] ?? false,
              'lastSeen': otherUserData?['lastSeen'],
            });
          }
        } catch (e) {
          print('Error processing chat room: $e');
        }
      }

      chatRooms.sort((a, b) {
        final aTime = a['lastMessageTime'] as int? ?? 0;
        final bTime = b['lastMessageTime'] as int? ?? 0;
        return bTime.compareTo(aTime);
      });

      return chatRooms;
    });
  }

  // Delete message
  static Future<bool> deleteMessage(
    String messageId,
    String otherUserId,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      await _database
          .child('messages/${currentUser.uid}/$otherUserId/$messageId')
          .remove();
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  // Clear all messages in a chat
  static Future<bool> clearChat(String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      await _database
          .child('messages/${currentUser.uid}/$otherUserId')
          .remove();

      await _database
          .child('chatRooms/${currentUser.uid}/$otherUserId')
          .remove();

      return true;
    } catch (e) {
      print('Error clearing chat: $e');
      return false;
    }
  }

  // Call signal methods remain the same...
  static Future<bool> sendCallSignal({
    required String receiverId,
    required String callId,
    required String type,
    required Map<String, dynamic> data,
    required CallType callType,
  }) async {
    try {
      final currentUserId = await StorageService.getUserId();
      if (currentUserId == null) return false;

      String actualReceiverId = receiverId;
      
      if (!receiverId.startsWith('user_')) {
        final receiverQuery = await _firestore
            .collection('users')
            .where('secureId', isEqualTo: receiverId)
            .limit(1)
            .get();

        if (receiverQuery.docs.isNotEmpty) {
          actualReceiverId = receiverQuery.docs.first.id;
        }
      }

      final signalData = {
        'senderId': currentUserId,
        'receiverId': actualReceiverId,
        'callId': callId,
        'type': type,
        'data': data,
        'callType': callType.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('call_signals')
          .add(signalData);

      return true;
    } catch (e) {
      print('Error sending call signal: $e');
      return false;
    }
  }

  static Stream<Map<String, dynamic>> listenForCallSignals() {
    try {
      return _firestore
          .collection('call_signals')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
        final currentUserId = await StorageService.getUserId();
        if (currentUserId == null) return <String, dynamic>{};

        for (final doc in snapshot.docChanges) {
          if (doc.type == DocumentChangeType.added) {
            final data = doc.doc.data() as Map<String, dynamic>;
            
            if (data['receiverId'] == currentUserId) {
              doc.doc.reference.delete().catchError((e) {
                print('Error deleting call signal: $e');
              });
              
              return data;
            }
          }
        }
        
        return <String, dynamic>{};
      }).where((data) => data.isNotEmpty);
    } catch (e) {
      print('Error listening for call signals: $e');
      return Stream.empty();
    }
  }

  static Future<void> cleanupExpiredCallSignals() async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      
      final query = await _firestore
          .collection('call_signals')
          .where('timestamp', isLessThan: Timestamp.fromDate(oneHourAgo))
          .get();

      final batch = _firestore.batch();
      
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Cleaned up ${query.docs.length} expired call signals');
    } catch (e) {
      print('Error cleaning up expired call signals: $e');
    }
  }
}