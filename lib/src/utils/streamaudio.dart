import 'dart:io';

void main() async {
  var socket = await Socket.connect('localhost', 1180);
  var bytes = <int>[];
  await for (var chunk in socket) {
    bytes.addAll(chunk);
    // Process the bytes as needed
  }
  // Use the bytes as the audio stream
  socket.close();
}
