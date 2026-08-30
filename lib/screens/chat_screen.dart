import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/chat_service.dart';

/// Ekran czatu - "wizytówka" widżetu.
///
/// Ta klasa sama w sobie nie ma logiki rysowania ani zmiennego
/// stanu - trzyma tylko niezmienną konfigurację ([username],
/// przekazane z zewnątrz) i wskazuje, że cały faktyczny stan oraz
/// logika żyją w [_ChatScreenState] (przez `createState()`).
class ChatScreen extends StatefulWidget {
  final String username;

  const ChatScreen({super.key, required this.username});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// Faktyczny stan ekranu czatu: połączenie z serwerem, pole
/// tekstowe i to, co aktualnie jest wyświetlane.
///
/// UWAGA - obecna wersja: `StreamBuilder` pokazuje tylko
/// NAJNOWSZĄ wiadomość (bo `Stream` sam z siebie nie pamięta
/// historii). To jest potwierdzony, działający punkt wyjścia;
/// rosnąca lista wiadomości (przez `.listen()` + `setState` +
/// `ListView.builder`) to kolejny krok, jeszcze nie wdrożony tutaj.
class _ChatScreenState extends State<ChatScreen> {
  late ChatService _chatService;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // widget.username - sięgamy po username z powiązanego
    // obiektu ChatScreen, bo _ChatScreenState nie ma go bezpośrednio.
    _chatService = ChatService(username: widget.username);
    _chatService.connect();
  }

  @override
  void dispose() {
    _chatService.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Odczytuje tekst z pola, wysyła go przez [_chatService]
  /// i czyści pole, gotowe na kolejną wiadomość.
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _chatService.sendMessage(text);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Czat - ${widget.username}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<Message>(
              stream: _chatService.messages,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final message = snapshot.data!;
                return Center(
                  child: Text('${message.user}: ${message.text}'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Napisz wiadomość...',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
