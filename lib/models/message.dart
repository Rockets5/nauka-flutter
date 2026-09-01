import 'system_event.dart';

/// Reprezentuje pojedynczą wiadomość czatu.
///
/// Odpowiednik backendowego modelu `Message` z Pydantic (patrz
/// `app/models/message.py`), tyle że konwersja JSON <-> obiekt
/// jest tu pisana ręcznie, bo Dart nie ma wbudowanego mechanizmu
/// takiego jak Pydantic.
class Message {
  /// Nazwa użytkownika, który wysłał wiadomość. Dla wiadomości
  /// systemowych to umowne `"System"`.
  final String user;

  /// Treść wiadomości - zawsze przeznaczona dla człowieka.
  final String text;

  /// Dla wiadomości systemowych: ustrukturyzowany rodzaj zdarzenia,
  /// na którego podstawie [ChatService] przełącza stan rozmowy.
  /// Dla zwykłych wiadomości od użytkowników jest `null`.
  final SystemEvent? event;

  Message({required this.user, required this.text, this.event});

  /// Tworzy obiekt [Message] z mapy (surowego JSON-a).
  ///
  /// Używane przy ODBIERANIU danych z WebSocketu: mapa -> obiekt.
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      user: json['user'],
      text: json['text'],
      // json['event'] to String albo null (backend wysyła
      // "event": null dla zwykłych wiadomości). fromWire radzi
      // sobie z oboma przypadkami - patrz system_event.dart.
      event: SystemEvent.fromWire(json['event']),
    );
  }

  /// Zamienia ten obiekt na mapę gotową do zakodowania jako JSON.
  ///
  /// Używane przy WYSYŁANIU danych do WebSocketu: obiekt -> mapa.
  /// Zauważ: to samo w sobie NIE jest jeszcze stringiem - dopiero
  /// `jsonEncode(message.toJson())` zamienia mapę na tekstowy JSON,
  /// który faktycznie da się wysłać przez WebSocket.
  ///
  /// UWAGA: frontend i tak nie wysyła [Message] do serwera (wysyła
  /// sam surowy tekst - patrz ChatService.sendMessage). Ta metoda
  /// zostaje na wypadek testów albo przyszłego użycia.
  Map<String, dynamic> toJson() {
    return {
      'user': user,
      'text': text,
      'event': event?.wire,
    };
  }
}
