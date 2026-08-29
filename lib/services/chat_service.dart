import 'dart:convert';
import 'package:naukaflutterapi/models/message.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatService {
    late WebSocketChannel _channel;
    final String username;

    ChatService({required this.username});

    // metoda, która nic nie zwraca
    void connect() {
        _channel = WebSocketChannel.connect(
            // Uri.parse zamienia string na obiekt reprezentujący adres URL
            // (WebSocketChannel wymaga takiego obiektu, nie gołego stringa)
            Uri.parse('ws://localhost:8000/ws/$username'),
            );
    }

    void sendMessage(String text) {
        final message = Message(user: username, text: text);
        _channel.sink.add(jsonEncode(message.toJson()));
    }

    Stream get messages => _channel.stream.map((raw) {
        final json = jsonDecode(raw);
        return Message.fromJson(json);
    });

    void dispose(){
        _channel.sink.close();
    }
}
