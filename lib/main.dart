import 'package:flutter/material.dart';

import 'screens/chat_screen.dart';

/// Punkt wejścia całej aplikacji Flutter - odpowiednik
/// `if __name__ == "__main__":` w Pythonie, tylko obowiązkowy.
void main() {
  runApp(const ChatApp());
}

/// Główny widżet aplikacji.
///
/// `StatelessWidget`, nie `StatefulWidget` - ten widżet sam
/// w sobie niczego nie zmienia, tylko raz konfiguruje `MaterialApp`
/// i wskazuje pierwszy ekran. Cała zmienność (wiadomości, stan
/// połączenia) żyje głębiej, w `ChatScreen` / `_ChatScreenState`.
class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      // Na razie username na sztywno - ekran logowania to
      // kolejny krok do zrobienia.
      home: const ChatScreen(username: 'Kasia'),
    );
  }
}
