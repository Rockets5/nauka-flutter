import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';

/// Zarządza połączeniem WebSocket z serwerem czatu, z automatycznym
/// ponownym łączeniem (reconnect) po utracie połączenia.
///
/// Odpowiednik backendowego `ConnectionManager` (patrz
/// `app/services/connection_manager.py`), tylko po stronie klienta:
/// odpowiada za nawiązanie połączenia, wysyłanie wiadomości oraz
/// udostępnianie strumienia wiadomości przychodzących.
///
/// Wywołaj [connect] zanim użyjesz [sendMessage] lub [messages].
/// Wywołaj [dispose] po zakończeniu pracy z ekranem czatu, żeby
/// zamknąć połączenie i nie zostawiać go otwartego w tle.
///
/// ZNANE OGRANICZENIE: gdy reconnect jawnie zamyka stare połączenie
/// przed otwarciem nowego, backend widzi to jako zwykłe rozłączenie
/// (nie ma sposobu odróżnić go od chwilowej przerwy) i rozsyła
/// wiadomość systemową "X opuścił czat", mimo że użytkownik
/// faktycznie zostaje. Poprawne rozwiązanie wymagałoby po stronie
/// backendu okresu karencji (grace period) przed ogłoszeniem
/// odejścia - celowo zostawione jako przyszłe usprawnienie.
class ChatService {
  late WebSocketChannel _channel;

  /// Nazwa użytkownika, pod jaką wysyłane są wiadomości.
  final String username;

  /// Stały strumień wiadomości, niezależny od tego, ile razy
  /// zostanie zestawione połączenie WebSocket w tle. Dzięki temu
  /// kod konsumujący [messages] może zasubskrybować się RAZ i nie
  /// musi wiedzieć nic o reconnectach dziejących się w środku.
  final _messagesController = StreamController<Message>.broadcast();

  /// Aktualny odstęp przed kolejną próbą ponownego połączenia.
  /// Rośnie z każdą nieudaną próbą (exponential backoff: 1s, 2s,
  /// 4s, 8s...), żeby nie zasypywać serwera próbami, gdy jest
  /// niedostępny dłużej. Resetowany do wartości startowej po
  /// każdej udanej wymianie danych.
  Duration _reconnectDelay = const Duration(seconds: 1);

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

    _channel.stream.listen(
      (raw) {
        final json = jsonDecode(raw);
        _messagesController.add(Message.fromJson(json));

        // Udane odebranie wiadomości = połączenie działa
        // poprawnie, więc resetujemy opóźnienie do wartości
        // startowej na wypadek przyszłych, kolejnych prób.
        _reconnectDelay = const Duration(seconds: 1);
      },
      onError: (error) => _scheduleReconnect(),
      onDone: () => _scheduleReconnect(),
    );
  }

  /// Planuje kolejną próbę połączenia po [_reconnectDelay], a
  /// następnie podwaja opóźnienie na wypadek, gdyby również ta
  /// próba się nie powiodła (exponential backoff).
  ///
  /// Celowo bez `await` - to jest ZAPLANOWANIE wykonania na
  /// później, a nie czekanie blokujące resztę aplikacji.
  void _scheduleReconnect() {
    Future.delayed(_reconnectDelay, () {
      // Jawnie zamykamy stare połączenie przed otwarciem nowego -
      // bez tego backend mógłby przez chwilę widzieć DWA aktywne
      // połączenia tego samego użytkownika naraz (duplikujące się
      // wiadomości), zanim stare samo "dogasło" po swojej stronie.
      _channel.sink.close();
      connect();
    });

    _reconnectDelay *= 2;
  }

  /// Wysyła surowy tekst wiadomości do serwera.
  ///
  /// Wysyłamy TYLKO tekst, bez pakowania w [Message] - backend
  /// sam już zna [username] (ma go z adresu URL, `/ws/{username}`)
  /// i to on skleja pełną wiadomość (user + text) przed
  /// rozesłaniem jej dalej. Gdyby frontend wysyłał tu gotowy
  /// JSON z polem `user`, backend potraktowałby cały ten JSON
  /// jako surowy tekst i zagnieździłby go wewnątrz kolejnego
  /// pola `text`.
  void sendMessage(String text) {
    _channel.sink.add(text);
  }

  /// Stały strumień wiadomości - subskrybuj go RAZ (np. w
  /// `initState()` ekranu), a będzie dostarczał dane niezależnie
  /// od tego, ile razy w środku [connect] zostanie wywołane
  /// ponownie przy reconnect.
  Stream<Message> get messages => _messagesController.stream;

  /// Zamyka połączenie WebSocket oraz wewnętrzny [_messagesController].
  ///
  /// Wywołaj to, gdy ekran czatu jest usuwany (np. w `dispose()`
  /// widżetu), żeby nie zostawić otwartego połączenia w tle
  /// (wyciek zasobów).
  void dispose() {
    _channel.sink.close();
    _messagesController.close();
  }
}