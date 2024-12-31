import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notifye/chat/chatpage.dart';
import 'package:flutter/cupertino.dart';
import 'chat_service.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();

  Future<void> _deleteChat(String chatId) async {
    try {
      final userId = _firebaseAuth.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('active_chats')
          .doc(userId)
          .collection('chats')
          .doc(chatId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat deleted successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Active Chats Section
          Expanded(
            flex: 1,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('active_chats')
                  .doc(_firebaseAuth.currentUser!.uid)
                  .collection('chats')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Error loading active chats.'));
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
                      Map<String, dynamic> chatData =
                          doc.data() as Map<String, dynamic>;
                      final isCurrentUser = _firebaseAuth.currentUser!.uid ==
                          doc.id.split("_")[0];
                      final isRead = isCurrentUser
                          ? (chatData['isReadByUser1'] ??
                              true) // Default to true if null
                          : (chatData['isReadByUser2'] ??
                              true); // Default to true if null
                      final receiverUsername =
                          chatData['receiver_username'] ?? 'Unknown User';
                      final lastMessage = chatData['last_message'] ?? '';
                      final receiverId = chatData['receiver_id'];
                      final chatId = doc.id;

                      return Dismissible(
                        key: Key(chatId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: const Color(0xFFCC4C4C),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: const Icon(CupertinoIcons.delete,
                              color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          _deleteChat(chatId);
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Space between avatar and dot
                              if (!isRead)
                                Container(
                                  width: 10.0,
                                  height: 10.0,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF5C3C88),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              const SizedBox(width: 10),
                              CircleAvatar(
                                radius: 24.0,
                                backgroundColor: Colors.grey[300],
                                child: const Icon(
                                  Icons.person,
                                  size: 28.0,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            receiverUsername,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            lastMessage,
                            overflow: TextOverflow.ellipsis,
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
                                const SnackBar(
                                    content: Text('Invalid user ID')),
                              );
                            }
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (chatData.containsKey('last_message_time'))
                                Text(
                                  formatTimestamp(
                                      chatData['last_message_time']),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12.0),
                                ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                          tileColor: isRead
                              ? null
                              : Colors.grey[200], // Highlight unread chats
                        ),
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

String formatTimestamp(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final DateTime dateTime = timestamp.toDate();
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays > 1) {
    return DateFormat('MMM dd').format(dateTime); // e.g., Jan 01
  } else if (difference.inDays == 1) {
    return 'Yesterday';
  } else {
    return DateFormat('hh:mm a').format(dateTime); // e.g., 10:30 AM
  }
}
