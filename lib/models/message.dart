/// Reprezentuje pojedynczą wiadomość czatu.
///
/// Odpowiednik backendowego modelu `Message` z Pydantic (patrz
/// `app/models/message.py`), tyle że konwersja JSON <-> obiekt
/// jest tu pisana ręcznie, bo Dart nie ma wbudowanego mechanizmu
/// takiego jak Pydantic.
class Message {
  /// Nazwa użytkownika, który wysłał wiadomość.
  final String user;

  /// Treść wiadomości.
  final String text;

  Message({required this.user, required this.text});

  /// Tworzy obiekt [Message] z mapy (surowego JSON-a).
  ///
  /// Używane przy ODBIERANIU danych z WebSocketu: mapa -> obiekt.
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      user: json['user'],
      text: json['text'],
    );
  }

  /// Zamienia ten obiekt na mapę gotową do zakodowania jako JSON.
  ///
  /// Używane przy WYSYŁANIU danych do WebSocketu: obiekt -> mapa.
  /// Zauważ: to samo w sobie NIE jest jeszcze stringiem - dopiero
  /// `jsonEncode(message.toJson())` zamienia mapę na tekstowy JSON,
  /// który faktycznie da się wysłać przez WebSocket.
  Map<String, dynamic> toJson() {
    return {
      'user': user,
      'text': text,
    };
  }
}
