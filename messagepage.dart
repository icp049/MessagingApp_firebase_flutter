import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notifye/chat/chat_service.dart';
import 'package:notifye/chat/chatpage.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({Key? key}) : super(key: key);

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: Column(
        children: [
          // Active Chats Section
          Expanded(
            flex: 1,
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getActiveChats(_firebaseAuth.currentUser!.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading active chats.'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData) {
                  final activeChats = snapshot.data!.docs;

                  if (activeChats.isEmpty) {
                    return const Center(child: Text('No active chats.'));
                  }

                  return ListView(
                    children: activeChats.map((doc) {
                      Map<String, dynamic> chatData = doc.data() as Map<String, dynamic>;
                      final receiverUsername = chatData['receiver_username'] ?? 'Unknown User';
                      final lastMessage = chatData['last_message'] ?? '';
                      final receiverId = chatData['receiver_id'];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        leading: CircleAvatar(
                          radius: 24.0, // Avatar size
                          backgroundColor: Colors.grey[300], // Background color when there's no image
                          child: Icon(
                            Icons.person, // Default icon (person icon)
                            size: 28.0,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(receiverUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          lastMessage,
                          overflow: TextOverflow.ellipsis, // Truncate long messages
                          style: const TextStyle(color: Colors.black54),
                        ),
                        onTap: () {
                          if (receiverId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  receiverUserId: receiverId,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid user ID')),
                            );
                          }
                        },
                        trailing: Icon(Icons.chevron_right, color: Colors.grey[600]), // Icon for navigation
                      );
                    }).toList(),
                  );
                }

                return const Center(child: Text('No active chats.'));
              },
            ),
          ),
        ],
      ),
    );
  }
}
