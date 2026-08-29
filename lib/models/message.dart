class Message {
  final String user;
  final String text;

  Message({required this.user, required this.text});

  // Konwersja: JSON (Map) -> obiekt Dart
  // Używamy tego, gdy ODBIERAMY dane z serwera

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      user: json['user'],
      text: json['text'],
    );
  }

  // Konwesja: obiekt Dart -> JSON (Map)
  // Używamy tego, gdy WYSYŁAMY dane do serwera

  Map<String, dynamic> toJson() {
    return {
      'user': user,
      'text': text,
    };
  }
}