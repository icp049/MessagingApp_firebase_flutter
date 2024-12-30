import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:notifye/chat/message.dart';

class ChatService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> fetchUsername(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc['username'] ?? 'Unknown User';
      } else {
        return 'Unknown User';
      }
    } catch (e) {
      print('Error fetching username: $e');
      return 'Unknown User';
    }
  }

  // Send message
  Future<void> sendMessage(String receiverId, String message) async {
    final String currentUserId = _firebaseAuth.currentUser!.uid;

    try {
      // Fetch sender and receiver usernames
      final String senderUsername = await fetchUsername(currentUserId);
      final String receiverUsername = await fetchUsername(receiverId);

      final Timestamp timestamp = Timestamp.now();

      // Create new message
      Message newMessage = Message(
        senderId: currentUserId,
        senderUsername: senderUsername,
        receiverId: receiverId,
        receiverUsername: receiverUsername,
        timestamp: timestamp,
        message: message,
      );

      // Construct chat room ID
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      String chatRoomId = ids.join("_");

      // Add message to chat room
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(newMessage.toMap());

      // Update active chats for both users
      await _firestore
          .collection('active_chats')
          .doc(currentUserId)
          .collection('chats')
          .doc(chatRoomId)
          .set({
        'chat_room_id': chatRoomId,
        'last_message': message,
        'last_message_time': timestamp,
        'receiver_id': receiverId,
        'receiver_username': receiverUsername,
      });

      await _firestore
          .collection('active_chats')
          .doc(receiverId)
          .collection('chats')
          .doc(chatRoomId)
          .set({
        'chat_room_id': chatRoomId,
        'last_message': message,
        'last_message_time': timestamp,
        'receiver_id': currentUserId,
        'receiver_username': senderUsername,
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  // Get messages for a chat room
  Stream<QuerySnapshot> getMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get active chats
  Stream<QuerySnapshot> getActiveChats(String userId) {
    return _firestore
        .collection('active_chats')
        .doc(userId)
        .collection('chats')
        .orderBy('last_message_time', descending: true)
        .snapshots();
  }

  // Get paginated messages
  Stream<List<QueryDocumentSnapshot>> getPaginatedMessages(
    String chatRoomId, {
    required int limit,
    QueryDocumentSnapshot? lastDocument,
  }) {
    Query query = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) => snapshot.docs);
  }
}
