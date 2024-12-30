import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderId;
  final String senderUsername;
  final String receiverId;
  final String receiverUsername;
  final String message;
  final Timestamp timestamp;

  // Updated constructor to include all parameters
  Message({
    required this.senderId,
    required this.senderUsername,
    required this.receiverId,
    required this.receiverUsername,
    required this.message,
    required this.timestamp,
  });

  // Convert a Message object to a Map
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderUsername': senderUsername,
      'receiverId': receiverId,
      'receiverUsername': receiverUsername,
      'message': message,
      'timestamp': timestamp,
    };
  }

  // Create a Message object from a Map
  
}
