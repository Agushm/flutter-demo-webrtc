import 'dart:io';

import 'dart:typed_data';

class SocketClient {
  var _socket;
  Future<Socket?> connect(String host) async {
    _socket = await Socket.connect(host, 4567);
    print(
        'Connected to: ${_socket!.remoteAddress.address}:${_socket!.remotePort}');

    /**
     *  Handle membaca pesan dari socket
    */
    _socket!.listen(
      (Uint8List data) {
        final serverResponse = String.fromCharCodes(data);
        print('Socket: $serverResponse');
      },
      // handle saat error
      onError: (error) {
        print(error);
        _socket!.destroy();
      },

      // handle saat koneksi selesai
      onDone: () {
        print('Socket left.');
        _socket!.destroy();
      },
    );

    return _socket;
  }

  Future<void> sendMessage(String message) async {
    print('Client: $message');
    _socket!.write(message);
  }
}
