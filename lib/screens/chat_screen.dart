import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  final String username;

  const ChatScreen({super.key, required this.username});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(username: widget.username);
    _chatService.connect();
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Czat - ${widget.username}')),
      body: Center(child: Text('Tu będzie lista wiadomości')),
    );
  }
}