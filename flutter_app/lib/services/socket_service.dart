import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;
  final String serverUrl;

  SocketService(this.serverUrl);

  void connect(String userId) {
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      socket.emit('register_user', {'userId': userId});
    });

    socket.connect();
  }

  void on(String event, dynamic Function(dynamic) handler) {
    socket.on(event, handler);
  }

  void emit(String event, dynamic data) {
    socket.emit(event, data);
  }

  void disconnect() {
    socket.disconnect();
  }
}
