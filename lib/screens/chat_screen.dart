import 'package:flutter/material.dart';
import '../models/conversation_state.dart';
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
/// tekstowe, lista wiadomości i to, co aktualnie jest wyświetlane.
///
/// Odpowiedzialność jest tu rozdzielona: `.listen()` w [initState]
/// pilnuje strumienia z [ChatService.messages] i aktualizuje
/// [_messages] (przez `setState`), a [build] po prostu rysuje to,
/// co aktualnie jest w [_messages] - nie wie nic o WebSocketach
/// ani strumieniach.
class _ChatScreenState extends State<ChatScreen> {
  late ChatService _chatService;
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];

  /// Stan rozmowy (czekam / w parze / rozmówca zniknął / rozmówca
  /// odszedł), wyliczany przez [ChatService] z wiadomości
  /// systemowych. `?` (nullable), bo w pierwszej chwili po
  /// [initState] - zanim z backendu przyjdzie pierwsze zdarzenie -
  /// nie wiemy jeszcze, w jakim jesteśmy stanie. `null` znaczy
  /// "jeszcze nie wiadomo".
  ConversationState? _conversationState;

  /// Stan samego połączenia WebSocket (transport), niezależny od
  /// stanu rozmowy. Bez `?` - od startu wiadomo, że trwa próba
  /// połączenia, więc wartość początkowa to
  /// [ConnectionStatus.connecting].
  ConnectionStatus _connectionStatus = ConnectionStatus.connecting;

  @override
  void initState() {
    super.initState();
    // widget.username - sięgamy po username z powiązanego
    // obiektu ChatScreen, bo _ChatScreenState nie ma go bezpośrednio.
    _chatService = ChatService(username: widget.username);
    _chatService.connect();

    // ChatService wystawia TRZY strumienie, każdy o jednej
    // odpowiedzialności. Subskrybujemy każdy osobno i przepisujemy
    // jego wartość do odpowiedniego pola stanu przez setState -
    // setState mówi Flutterowi "stan się zmienił, przebuduj UI".
    //
    // build() czyta potem tylko te pola i nic nie wie o strumieniach
    // ani WebSocketach.

    // 1. Kolejne wiadomości -> dopisujemy do rosnącej listy.
    _chatService.messages.listen((message) {
      setState(() {
        _messages.add(message);
      });
    });

    // 2. Stan rozmowy (wyliczony przez ChatService z pola `event`).
    _chatService.conversationState.listen((state) {
      setState(() {
        _conversationState = state;
      });
    });

    // 3. Stan połączenia (żywotność socketu).
    _chatService.connectionStatus.listen((status) {
      setState(() {
        _connectionStatus = status;
      });
    });
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
    // Guard clause: bez połączenia nie ma sensu (ani technicznej
    // możliwości) pokazywać listy wiadomości czy pola do pisania -
    // zwracamy od razu CAŁY inny ekran, zamiast mieszać dwa stany
    // w jednym drzewie widżetów.
    if (_conversationState == ConversationState.paired) {
      return Scaffold(
        appBar: AppBar(title: Text('Czat - ${widget.username}')),
        body: Center(child: Text(ConversationState.paired.toString())),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Czat - ${widget.username}')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];

                // Wiadomości systemowe (np. "X opuścił czat")
                // wyświetlamy inaczej niż zwykłe - wyśrodkowane,
                // mniejsze, bez podziału na nadawcę i treść.
                if (message.user == 'System') {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }

                return ListTile(
                  title: Text(message.user),
                  subtitle: Text(message.text),
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