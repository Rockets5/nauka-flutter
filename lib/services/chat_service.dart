import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/conversation_state.dart';
import '../models/message.dart';
import '../models/system_event.dart';

/// Status połączenia transportowego (żywotność socketu WebSocket).
///
/// To OSOBNA oś od [ConversationState] (stanu rozmowy). Można być
/// [ConversationState.paired] i jednocześnie [ConnectionStatus.connecting]
/// (chwilowa przerwa w sieci w trakcie rozmowy).
enum ConnectionStatus {
  /// Trwa próba połączenia - pierwsza albo po zerwaniu.
  connecting,

  /// Socket działa, dane płyną.
  connected,

  /// Poddano się po serii nieudanych prób (patrz
  /// [ChatService._maxReconnectAttempts]). UI powinno zaproponować
  /// ręczne ponowienie ([ChatService.retry]).
  givenUp,
}

/// Zarządza połączeniem WebSocket z serwerem czatu 1-na-1.
///
/// Odpowiednik backendowego `ConnectionManager` po stronie klienta.
/// Wystawia TRZY strumienie, każdy o jednej odpowiedzialności:
/// - [messages] - kolejne wiadomości (zwykłe i systemowe),
/// - [conversationState] - stan rozmowy wyliczony z wiadomości
///   systemowych (pole `event`); ekran nie parsuje niczego sam,
/// - [connectionStatus] - żywotność samego socketu.
///
/// Wywołaj [connect] raz. Ponowne łączenie po zerwaniu obsługuje
/// [_scheduleReconnect] wewnętrznie (exponential backoff z limitem).
/// Wywołaj [dispose], gdy ekran czatu jest usuwany.
class ChatService {
  /// Nazwa użytkownika - trafia do adresu URL (`/ws/{username}`),
  /// z którego backend odczytuje nadawcę.
  final String username;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final _messagesController = StreamController<Message>.broadcast();
  final _stateController = StreamController<ConversationState>.broadcast();
  final _connectionController = StreamController<ConnectionStatus>.broadcast();

  /// Backoff startuje od 1s i podwaja się przy kolejnych nieudanych
  /// próbach, ale nigdy nie przekracza [_maxReconnectDelay] - powrót
  /// musi zmieścić się w 60-sekundowym oknie grace period backendu,
  /// inaczej pokój zostanie zamknięty, zanim zdążymy wrócić.
  static const _initialReconnectDelay = Duration(seconds: 1);
  static const _maxReconnectDelay = Duration(seconds: 5);

  /// Po tylu nieudanych próbach z rzędu przestajemy próbować, żeby
  /// nie zjadać baterii i transferu w nieskończoność. Powrót do
  /// prób jest możliwy ręcznie przez [retry].
  static const _maxReconnectAttempts = 8;

  Duration _reconnectDelay = _initialReconnectDelay;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  /// Ustawiane w [dispose]. Chroni przed tym, żeby zaplanowany
  /// reconnect albo spóźniony callback strumienia nie próbował
  /// działać na już zamkniętym serwisie.
  bool _disposed = false;

  ChatService({required this.username});

  Stream<Message> get messages => _messagesController.stream;
  Stream<ConversationState> get conversationState => _stateController.stream;
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionController.stream;

  /// Nawiązuje połączenie WebSocket z serwerem.
  ///
  /// UWAGA na emulatorze Androida: `localhost` odnosi się do samego
  /// emulatora, nie do komputera-hosta. `10.0.2.2` to alias hosta.
  ///
  /// Jest `async`, bo `WebSocketChannel.connect` łączy się LENIWIE -
  /// dopiero `channel.ready` mówi, czy socket faktycznie stanął.
  Future<void> connect() async {
    if (_disposed) return;

    _connectionController.add(ConnectionStatus.connecting);

    final channel = WebSocketChannel.connect(
      Uri.parse('ws://10.0.2.2:8000/ws/$username'),
    );
    _channel = channel;

    try {
      await channel.ready;
    } catch (_) {
      // Połączenie nie doszło do skutku - zaplanuj kolejną próbę.
      _scheduleReconnect();
      return;
    }

    if (_disposed) {
      channel.sink.close();
      return;
    }

    _subscription = channel.stream.listen(
      _handleIncoming,
      // onError i onDone to dwa objawy tego samego: socket przestał
      // działać. Oba prowadzą do tej samej reakcji.
      onError: (_) => _scheduleReconnect(),
      onDone: () => _scheduleReconnect(),
    );

    // Sukces - zerujemy backoff, żeby ewentualne przyszłe zerwanie
    // znów startowało od krótkiego 1s, a nie od rozpędzonego limitu.
    _reconnectDelay = _initialReconnectDelay;
    _reconnectAttempts = 0;
    _connectionController.add(ConnectionStatus.connected);
  }

  /// Obsługuje jedną przychodzącą ramkę z socketu.
  void _handleIncoming(dynamic raw) {
    final Message message;
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      message = Message.fromJson(json);
    } catch (_) {
      // Nieoczekiwany format ramki - pomijamy ją, zamiast wywracać
      // całe połączenie (symetrycznie do tego, jak backend traktuje
      // śmieciowe komendy od klienta).
      return;
    }

    _messagesController.add(message);

    // Wiadomość systemowa niesie `event` -> przelicz go na stan
    // rozmowy i wypchnij na osobny strumień.
    final event = message.event;
    if (event != null) {
      _stateController.add(_stateForEvent(event));
    }
  }

  /// Mapuje zdarzenie z backendu na stan rozmowy dla UI.
  ///
  /// 5 zdarzeń -> 4 stany: `paired` i `partnerReconnected` prowadzą
  /// do tego samego [ConversationState.paired], bo z punktu widzenia
  /// ekranu "jesteś w rozmowie" to jeden stan.
  ///
  /// `switch` bez `default` - dodanie wariantu do [SystemEvent]
  /// wymusi (błąd kompilacji) dopisanie obsługi tutaj.
  ConversationState _stateForEvent(SystemEvent event) {
    switch (event) {
      case SystemEvent.waiting:
        return ConversationState.waiting;
      case SystemEvent.paired:
      case SystemEvent.partnerReconnected:
        return ConversationState.paired;
      case SystemEvent.partnerDisconnected:
        return ConversationState.partnerAway;
      case SystemEvent.partnerLeft:
        return ConversationState.partnerLeft;
    }
  }

  /// Wysyła wiadomość tekstową do partnera.
  ///
  /// Opakowana w komendę JSON `{"type": "message", "text": ...}` -
  /// backend rozróżnia komendy po polu `type`, bo frontend ma teraz
  /// więcej niż jedną intencję (patrz [next]).
  void sendMessage(String text) {
    _send({'type': 'message', 'text': text});
  }

  /// Kończy obecną rozmowę (jeśli trwa) i prosi backend o dobranie
  /// nowego rozmówcy. To jest akcja przycisku "dobierz rozmówcę".
  void next() {
    _send({'type': 'next'});
  }

  void _send(Map<String, dynamic> command) {
    _channel?.sink.add(jsonEncode(command));
  }

  /// Planuje kolejną próbę połączenia po [_reconnectDelay], po czym
  /// podwaja opóźnienie (do [_maxReconnectDelay]). Po
  /// [_maxReconnectAttempts] próbach z rzędu poddaje się.
  void _scheduleReconnect() {
    if (_disposed) return;

    // onError i onDone potrafią odpalić się jedno po drugim dla
    // tego samego zerwania - bez tej straży zaplanowalibyśmy dwie
    // próby naraz.
    if (_reconnectTimer != null) return;

    _subscription?.cancel();
    _subscription = null;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _connectionController.add(ConnectionStatus.givenUp);
      return;
    }

    _reconnectAttempts++;
    _connectionController.add(ConnectionStatus.connecting);

    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectTimer = null;
      _channel?.sink.close();
      connect();
    });

    final doubled = _reconnectDelay * 2;
    _reconnectDelay =
        doubled > _maxReconnectDelay ? _maxReconnectDelay : doubled;
  }

  /// Ręczne wznowienie prób po tym, jak [connectionStatus] zgłosił
  /// [ConnectionStatus.givenUp] (np. przycisk "Spróbuj ponownie").
  void retry() {
    if (_disposed) return;

    _reconnectAttempts = 0;
    _reconnectDelay = _initialReconnectDelay;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    connect();
  }

  /// Zamyka połączenie i wszystkie trzy strumienie. Wywołaj z
  /// `dispose()` widżetu ekranu czatu, żeby nie zostawić otwartego
  /// socketu ani zaplanowanego reconnectu w tle.
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _messagesController.close();
    _stateController.close();
    _connectionController.close();
  }
}
