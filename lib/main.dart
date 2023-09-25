import 'dart:core';

import 'package:flutter/material.dart';

import 'src/call_sample/call_sample.dart';
import 'src/call_sample/data_channel_sample.dart';
import 'src/route_item.dart';

import 'src/utils/juce_ipc.dart';

const serverUrl = "webrtc.ml360-testing.dev";

void main() async {
  // Wait for initialization to be completed first.
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

enum DialogDemoAction {
  cancel,
  connect,
}

class _MyAppState extends State<MyApp> {
  bool ipc_ready = false;
  List<RouteItem> items = [];

  bool _datachannel = false;
  @override
  initState() {
    super.initState();

    //Initialize the class for facilitating IPC between this monitor application, and the JUCE plugin
    JuceIPC.begin();

    //Register an event handler which sets ipc_read to be true once the JuceIPC class recieves the required information from the JUCE plugin
    JuceIPC.onready(LoadingScreen.navigateToCallsPage);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child:
          MaterialApp(debugShowCheckedModeBanner: false, home: LoadingScreen()),
      onWillPop: () async => JuceIPC.stop(),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  bool _datachannel = false;
  static late BuildContext _context;
  TextEditingController sessionIdTextController =
      TextEditingController(); //Needed for reading the value from the TextField
  TextEditingController clientTypeTextController =
      TextEditingController(); //Needed for reading the value from the TextField
  String session_id = '';

  static void navigateToCallsPage() {
    print("Navigating to calls page...");
    Navigator.of(_context).push(MaterialPageRoute(
        builder: (BuildContext context) => CallSample(host: serverUrl)));
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text("Live Monitor")),
      body: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text("Awaiting connection to ML360..."),
          const SizedBox(height: 20),
          SizedBox(
              width: 200,
              child: TextField(
                  decoration:
                      const InputDecoration(hintText: "SessionID (dev only)"),
                  controller: sessionIdTextController)),
          const SizedBox(height: 20),
          SizedBox(
              width: 200,
              child: TextField(
                  decoration: const InputDecoration(
                      hintText: "Client type (studio or client)"),
                  controller: clientTypeTextController)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (sessionIdTextController.text != '' &&
                  clientTypeTextController.text != '') {
                JuceIPC.sessionID = sessionIdTextController
                    .text; //Overwrite stored session id with one entered in input
                if (clientTypeTextController.text == 'client') {
                  JuceIPC.type = ClientType.client;
                } else if (clientTypeTextController.text == 'studio') {
                  JuceIPC.type = ClientType.studio;
                }
                navigateToCallsPage();
              }
            },
            child: Text("Bypass (dev only)"),
          ),
          Image.asset("assets/logo.png", width: 300),
        ])
      ]),
    );
  }
}
