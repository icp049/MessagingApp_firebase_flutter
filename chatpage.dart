import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:notifye/chat/chat_service.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String receiverUserId;

  const ChatPage({
    Key? key,
    required this.receiverUserId,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  String? _username;

  List<QueryDocumentSnapshot> _messages = [];
  bool _isLoading = false;
  QueryDocumentSnapshot? _lastDocument;
  final int _messageLimit = 15;

  final FocusNode _focusNode = FocusNode();

  // Send message
  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      final message = _messageController.text; // Store the message text
      _messageController.clear(); // Clear the input field immediately

      try {
        await _chatService.sendMessage(widget.receiverUserId, message);
      } catch (e) {
        print("Error sending message: $e");
        // Optional: Show a Snackbar or some UI feedback to inform the user of an error
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _fetchUsername();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _fetchUsername() async {
    _username = await _chatService.fetchUsername(widget.receiverUserId);
    setState(() {}); // Trigger a UI rebuild to show the username
  }

  @override
  void dispose() {
    _focusNode.dispose(); // Dispose the FocusNode
    super.dispose();
  }

  void _loadInitialMessages() {
    setState(() => _isLoading = true);

    _chatService
        .getPaginatedMessages(_chatRoomId(), limit: _messageLimit)
        .listen((newMessages) {
      setState(() {
        _messages = newMessages; // Replace with the latest data
        if (newMessages.isNotEmpty) {
          _lastDocument = newMessages.last;
        }
        _isLoading = false;
      });
    });
  }

  void _loadMoreMessages() async {
    if (_isLoading || _lastDocument == null) return;

    setState(() => _isLoading = true);

    _chatService
        .getPaginatedMessages(_chatRoomId(),
            limit: _messageLimit, lastDocument: _lastDocument)
        .listen((newMessages) {
      setState(() {
        _messages.addAll(newMessages);
        if (newMessages.isNotEmpty) {
          _lastDocument = newMessages.last;
        }
        _isLoading = false;
      });
    });
  }

  String _chatRoomId() {
    List<String> ids = [_firebaseAuth.currentUser!.uid, widget.receiverUserId];
    ids.sort();
    return ids.join("_");
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Unfocus the keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_username ?? "....."),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // A hidden TextField to prewarm the keyboard
            Offstage(
              child: TextField(
                focusNode: FocusNode(), // Unused FocusNode
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (scrollNotification.metrics.pixels ==
                          scrollNotification.metrics.maxScrollExtent &&
                      !_isLoading) {
                    _loadMoreMessages();
                  }
                  return true;
                },
                child: ListView.builder(
                  reverse: true,
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _buildMessageItem(_messages[index]);
                  },
                ),
              ),
            ),
            const SizedBox(height: 5),
            _buildMessageInput(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Build message list
  Widget _buildMessageList() {
    String chatRoomId = _chatRoomId();

    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(chatRoomId), // Real-time messages
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final realTimeMessages = snapshot.data!.docs;

        // Combine real-time messages with paginated messages
        final combinedMessages = [
          ...realTimeMessages,
          ..._messages.where(
            (paginatedMessage) => !realTimeMessages.any((realTimeMessage) =>
                realTimeMessage.id == paginatedMessage.id), // Avoid duplicates
          ),
        ];

        return ListView.builder(
          reverse: true,
          itemCount: combinedMessages.length + (_isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == combinedMessages.length) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildMessageItem(combinedMessages[index]);
          },
        );
      },
    );
  }

  // Build message item
  Widget _buildMessageItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;

    bool isCurrentUser = data['senderId'] == _firebaseAuth.currentUser!.uid;
    Color messageColor =
        isCurrentUser ? Colors.blue.shade100 : Colors.purple.shade100;
    var alignment =
        isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start;

    String formattedTimestamp = "";
    if (data['timestamp'] != null) {
      final timestamp = data['timestamp'];
      if (timestamp is Timestamp) {
        formattedTimestamp = DateFormat('hh:mm a').format(timestamp.toDate());
      } else if (timestamp is DateTime) {
        formattedTimestamp = DateFormat('hh:mm a').format(timestamp);
      }
    }

    ValueNotifier<bool> showTimestamp = ValueNotifier(false);

    return GestureDetector(
      onLongPress: () {
        showTimestamp.value = true;
      },
      onLongPressEnd: (_) {
        Future.delayed(const Duration(seconds: 2), () {
          showTimestamp.value = false;
        });
      },
      child: Row(
        mainAxisAlignment: alignment,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isCurrentUser)
            ValueListenableBuilder<bool>(
              valueListenable: showTimestamp,
              builder: (context, value, child) {
                return value
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 20, right: 20.0),
                        child: Text(
                          formattedTimestamp,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxWidth: 250),
            decoration: BoxDecoration(
              color: messageColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              data['message'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          if (!isCurrentUser)
            ValueListenableBuilder<bool>(
              valueListenable: showTimestamp,
              builder: (context, value, child) {
                return value
                    ? Padding(
                        padding:
                            const EdgeInsets.only(bottom: 20.0, left: 20.0),
                        child: Text(
                          formattedTimestamp,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
        ],
      ),
    );
  }

  // Build message input
  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,

              maxLines: 8, // Limits to 8 lines
              minLines: 1, // Minimum height for the input field
              decoration: InputDecoration(
                hintText: 'Message..',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                      color: Colors.grey.shade300), // Default border color
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                      color: Colors.grey.shade300), // Non-focused border color
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                      color: Colors.grey.shade300), // No focus effect
                ),
                suffixIcon: GestureDetector(
                  onTap: sendMessage,
                  child: Container(
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B74D7), // Violet background
                      shape: BoxShape.circle, // Circle shape
                    ),
                    child: const Icon(
                      Icons.arrow_upward, // Arrow-up icon
                      color: Colors.white, // Icon color
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
