import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';

/// Zarządza połączeniem WebSocket z serwerem czatu.
///
/// Odpowiednik backendowego `ConnectionManager` (patrz
/// `app/services/connection_manager.py`), tylko po stronie klienta:
/// odpowiada za nawiązanie połączenia, wysyłanie wiadomości oraz
/// udostępnianie strumienia wiadomości przychodzących.
///
/// Wywołaj [connect] zanim użyjesz [sendMessage] lub [messages].
/// Wywołaj [dispose] po zakończeniu pracy z ekranem czatu, żeby
/// zamknąć połączenie i nie zostawiać go otwartego w tle.
class ChatService {
  late WebSocketChannel _channel;

  /// Nazwa użytkownika, pod jaką wysyłane są wiadomości.
  final String username;

  ChatService({required this.username});

  /// Nawiązuje połączenie WebSocket z serwerem.
  ///
  /// UWAGA na emulatorze Androida: `localhost` odnosi się do
  /// samego emulatora, nie do komputera-hosta. Użyj `10.0.2.2`
  /// zamiast `localhost`, żeby połączyć się z serwerem
  /// uruchomionym na Twoim komputerze. Na innych platformach
  /// (Windows desktop, prawdziwe urządzenie w tej samej sieci)
  /// adres trzeba dopasować odpowiednio.
  void connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://10.0.2.2:8000/ws/$username'),
    );
  }

  /// Wysyła wiadomość tekstową do serwera.
  ///
  /// Pakuje tekst razem z [username] w model [Message], zamienia
  /// go na mapę (`toJson`), a potem na tekstowy JSON (`jsonEncode`)
  /// - dopiero taki string może zostać wysłany przez WebSocket.
  void sendMessage(String text) {
    final message = Message(user: username, text: text);
    _channel.sink.add(jsonEncode(message.toJson()));
  }

  /// Strumień wiadomości przychodzących od serwera.
  ///
  /// Każdy surowy string JSON z `_channel.stream` jest dekodowany
  /// i zamieniany na obiekt [Message] przez `.map()`. Można go
  /// skonsumować przez `StreamBuilder` (automatyczne przebudowanie
  /// UI) albo przez `.listen()` (ręczna reakcja na każdą nową
  /// wiadomość, np. do dopisywania jej do własnej listy).
  Stream<Message> get messages => _channel.stream.map((raw) {
        final json = jsonDecode(raw);
        return Message.fromJson(json);
      });

  /// Zamyka połączenie WebSocket.
  ///
  /// Wywołaj to, gdy ekran czatu jest usuwany (np. w `dispose()`
  /// widżetu), żeby nie zostawić otwartego połączenia w tle
  /// (wyciek zasobów).
  void dispose() {
    _channel.sink.close();
  }
}
