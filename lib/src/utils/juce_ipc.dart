import 'dart:convert';
import 'dart:core';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:msgpack_dart/msgpack_dart.dart';
import 'dart:io';

class MyAudioSource extends StreamAudioSource {
  late Uint8List _buffer;
  MyAudioSource(Uint8List newBuffer) : super(tag: "MyAudioSource") {
    _buffer = newBuffer;
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    //Returning the stream audio response with the parameters
    print("Playing requested audio data");
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: (end ?? _buffer.length) - (start ?? 0),
      offset: start ?? 0,
      contentType: 'audio/wav',
      stream: Stream.fromIterable([_buffer.sublist(start ?? 0, end)]),
    );
  }
}

enum ClientType { client, studio }

class JuceIPC {
  //Stores the client's type
  static late ClientType type;

  //The session id for the session that the user is in
  static String sessionID = "-1";

  //True once in "ready" state
  static bool is_ready = false;

  //The process handle for the background process
  static late ProcessResult background_process_handle;

  //Set this to match the endianess of the system sending data to this application
  static Endian endianess = Endian.little;

  //Function which is executed once the required information is sent from the juce plugin (type & session_id)
  static late Function onreadyeventhandler;

  static final player = AudioPlayer();

  //Initializes the socket server, and registers the event handler for new clients
  static Future<void> begin() async {
    print('Beginning socket server...');
    //final audioServer = await ServerSocket.bind(InternetAddress.anyIPv4, 6968);
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 6969);

    background_process_handle =
        await Process.run('assets/live-monitor-background-process', []);

    server.listen((client) {
      _handleConnection(client);
    });
  }

  //Handles client connections (the JUCE plugin)
  static void _handleConnection(Socket client) {
    print(
        'Connection from ${client.remoteAddress.address}:${client.remotePort}');

    //Listen for events from the client
    client.listen(
      //Handle data from the client
      (Uint8List data) async {
        final message = String.fromCharCodes(data);
        var json = jsonDecode(message);

        _handleMessage(json);
      },

      //Handle errors
      onError: (error) {
        print('Error! ${error}');
        client.close();
      },

      //Handle client disconnect
      onDone: () {
        print('Client left');
        client.close();
      },
    );
  }

  static void _handleAudioServerConnection(Socket client) {
    print(
        'Audio Server: Connection from ${client.remoteAddress.address}:${client.remotePort}');

    //Listen for events from the client
    client.listen(
      //Handle data from the client
      (Uint8List data) async {
        print("Recieved data");
        ByteData byteData = data.buffer.asByteData();
        int bufferSize = byteData.getInt32(0, JuceIPC.endianess);
        int sampleRate = byteData.getInt32(4, JuceIPC.endianess);

        //First 8 bytes are for the buffer size and sample rate
        int data_offset = 8;
        List<double> samples = [];
        for (int i = 0; i < bufferSize; i++) {
          double sample =
              byteData.getFloat32(data_offset + (i * 4), JuceIPC.endianess);
          samples.add(sample);
        }

        Uint8List audioByteData = Uint8List(samples.length * 4);
        for (int i = 0; i < samples.length; i++) {
          int byteOffset = i * 4;
          ByteData bd = ByteData.sublistView(byteData, byteOffset);
          bd.setFloat32(0, samples[i], JuceIPC.endianess);
        }

        await player.setAudioSource(MyAudioSource(audioByteData));
        player.play();
      },

      //Handle errors
      onError: (error) {
        print('Error! ${error}');
        client.close();
      },

      //Handle client disconnect
      onDone: () {
        print('Client left');
        client.close();
      },
    );
  }

  //Handles messages sent from the JUCE plugin
  static void _handleMessage(json) {
    try {
      if (!is_ready) {
        String tempType = json["type"];
        if (tempType == "studio") {
          type = ClientType.studio;
        } else if (tempType == "client") {
          type = ClientType.client;
        }
        sessionID = json["session_id"];
        if (sessionID != "-1") {
          is_ready = true;
          onreadyeventhandler();
        }
      } else {
        // If IPC has already been established & initialized
      }
    } catch (e) {
      print(e);
    }
  }

  //Registers the callback function for one the initial information has beenr ecieved from the JUCE plugin
  static void onready(Function callback) {
    onreadyeventhandler = callback;
  }

  static Future<bool> stop() {
    print("Stopping background process...");
    Process.killPid(background_process_handle.pid);
    return Future.value(true);
  }
}
