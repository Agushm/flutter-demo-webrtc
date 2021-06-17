import 'package:web_socket_channel/web_socket_channel.dart';

typedef void OnMessageCallback(dynamic msg);
typedef void OnCloseCallback(int code, String reason);
typedef void OnOpenCallback();

class DemoWebSocket {
  String _url;
  WebSocketChannel? _socket;
  OnOpenCallback? onOpen;
  OnMessageCallback? onMessage;
  OnCloseCallback? onClose;
  DemoWebSocket(this._url);

  void connect() {
    try {
      _socket = WebSocketChannel.connect(
        Uri.parse(_url),
      );
      onOpen?.call();
      _socket!.stream.listen((data) {
        onMessage!.call(data);
      }, onDone: () {
        onClose?.call(_socket!.closeCode!, _socket!.closeReason!);
      });
    } catch (e) {
      onClose?.call(500, e.toString());
    }
  }

  send(data) {
    if (_socket != null) {
      _socket!.sink.add(data);
      print('send: $data');
    } else {
      print('gagal send');
    }
  }

  close() {
    if (_socket != null) _socket!.sink.close();
  }
}
