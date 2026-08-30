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

  /// Komunikat błędu połączenia WebSocket, albo `null`, jeśli
  /// wszystko działa poprawnie. `String?` (ze znakiem zapytania)
  /// oznacza, że ta zmienna może nie mieć wartości - na start jej
  /// brak (`null`) po prostu oznacza "na razie bez błędu".
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    // widget.username - sięgamy po username z powiązanego
    // obiektu ChatScreen, bo _ChatScreenState nie ma go bezpośrednio.
    _chatService = ChatService(username: widget.username);
    _chatService.connect();

    // Nasłuchujemy strumienia ręcznie (zamiast tylko przez
    // StreamBuilder), żeby dopisywać każdą nową wiadomość do
    // własnej, rosnącej listy. setState mówi Flutterowi, że stan
    // się zmienił i UI trzeba przebudować.
    //
    // onError to jawny odpowiednik tego, co StreamBuilder
    // sprawdzał automatycznie przez snapshot.hasError - .listen()
    // nic nie robi za nas, więc błąd (np. nieudane połączenie od
    // razu na starcie) trzeba obsłużyć osobno, tutaj.
    //
    // onDone to osobny przypadek: utrata JUŻ nawiązanego
    // połączenia (np. serwer padł) często nie jest "błędem" tylko
    // zamknięciem strumienia - bez tej obsługi taka sytuacja
    // przechodziłaby całkowicie w ciszy, bez żadnego komunikatu.
    _chatService.messages.listen(
      (message) {
        setState(() {
          _messages.add(message);
        });
      },
      onError: (error) {
        setState(() {
          _connectionError = 'Nie udało się połączyć z serwerem';
        });
      },
      onDone: () {
        setState(() {
          _connectionError = 'Połączenie z serwerem zostało przerwane';
        });
      },
    );
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
    if (_connectionError != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Czat - ${widget.username}')),
        body: Center(child: Text(_connectionError!)),
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