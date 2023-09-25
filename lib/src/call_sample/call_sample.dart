import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_video_call/src/utils/juce_ipc.dart';
import 'package:flutter_video_call/src/utils/round_slider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../widgets/screen_select_dialog.dart';
import 'signaling.dart';

class CallSample extends StatefulWidget {
  static String tag = 'call_sample';
  final String host;
  var muted = false;
  CallSample({super.key, required this.host});

  @override
  _CallSampleState createState() => _CallSampleState();
}

class _CallSampleState extends State<CallSample> {
  Signaling? _signaling;
  List<dynamic> _peers = [];
  String? _selfId;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  Session? _session;
  DesktopCapturerSource? selected_source_;
  bool _waitAccept = false;
  bool isOpen = true;
  double progress1 = 45.0;
  double progress2 = 77.0;

  // ignore: unused_element
  _CallSampleState();

  //The function for intitializing the state of the widget. Runs on mount
  @override
  initState() {
    super.initState(); //Initializes the state of its superclass
    initRenderers(); //Initializes the webrtc video renderers
    _connect(context); //Connects to the signaling server
  }

  //Initializes the webrtc video renderers
  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  //Disconnects from the signaling server and descructs the webrtc video renderers
  @override
  deactivate() {
    super.deactivate();
    _signaling?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  //Initializes a connection with the signaling server
  void _connect(BuildContext context) async {
    _signaling ??= Signaling(widget.host, context)
      ..connect(JuceIPC.sessionID.toString(),
          JuceIPC.type.toString()); //Pass session_id here

    //Handle changes in the state from the signaling server
    _signaling?.onSignalingStateChange = (SignalingState state) {
      switch (state) {
        case SignalingState.ConnectionClosed:
        case SignalingState.ConnectionError:
        case SignalingState.ConnectionOpen:
          break;
      }
    };

    //Handle changes in the state of the call itself
    _signaling?.onCallStateChange = (Session session, CallState state) async {
      switch (state) {
        case CallState.CallStateNew: //Initial load?
          setState(() {
            _session = session;
          });
          break;
        case CallState.CallStateRinging: //Call incoming
          bool? accept =
              await _showAcceptDialog(); //Await the value returned from the accept dialog
          if (accept!) {
            _accept();
            setState(() {
              _inCalling = true;
            });
          } else {
            _reject();
          }
          break;
        case CallState.CallStateBye: //Call rejected
          if (_waitAccept) {
            print('peer reject');
            _waitAccept = false;
            Navigator.of(context).pop(false);
          }
          setState(() {
            _localRenderer.srcObject = null;
            _remoteRenderer.srcObject = null;
            _inCalling = false;
            _session = null;
          });
          break;
        case CallState.CallStateInvite: //Invites a peer to a call
          _waitAccept = true;
          _showInvateDialog();
          break;
        case CallState.CallStateConnected: //Call connected
          if (_waitAccept) {
            _waitAccept = false;
            Navigator.of(context).pop(false);
          }
          setState(() {
            _inCalling = true;
          });

          break;
//Awaiting peer to join?
      }
    };

    //When list of peers is updated
    _signaling?.onPeersUpdate = ((event) {
      //event contains an array of peers & their id's, as well as the users own id
      setState(() {
        _selfId = event['self'];
        print("Change in peers:");
        print(event['peers']);
        print(event['peers'][0]['juce_session_id']);
        var temp = [];
        try {
          for (var i = 0; i < event['peers'].length; i++) {
            if (event['peers'][i]['juce_session_id'] ==
                    JuceIPC.sessionID.toString() &&
                event['peers'][i]['id'] != _selfId) {
              temp.add(event['peers'][i]);
            }
          }
        } catch (e) {
          print(e);
        }

        _peers = temp;

        //Call user if in same juce session, and is a client, and if own user is a studio
        if (_peers.isNotEmpty &&
            _peers[0]['juce_client_type'] == "ClientType.client" &&
            JuceIPC.type == ClientType.studio) {
          print(_peers[0]);
          try {
            _signaling?.invite(_peers[0]['id'], 'video',
                false); //Should automatically call when peer joins
          } catch (e) {
            print(e);
          }
        }
      });
    });

    //Not too sure what these do
    _signaling?.onLocalStream = ((stream) {
      _localRenderer.srcObject = stream;
      setState(() {});
    });

    _signaling?.onAddRemoteStream = ((_, stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {});
    });

    _signaling?.onRemoveRemoteStream = ((_, stream) {
      _remoteRenderer.srcObject = null;
    });
  }

  //Shows the dialog for when a call is incoming. Returns a boolean
  Future<bool?> _showAcceptDialog() {
    return showDialog<bool?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Studio is inviting you to video call"),
          content: const Text("accept?"),
          actions: <Widget>[
            MaterialButton(
              child: const Text(
                'Reject',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            MaterialButton(
              child: const Text(
                'Accept',
                style: TextStyle(color: Colors.green),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  //Show the dialog for inviting a user to a call
  Future<bool?> _showInvateDialog() {
    return showDialog<bool?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Inviting user to video call"),
          content: const Text("Waiting for user to accept..."),
          actions: <Widget>[
            TextButton(
              child: const Text("cancel"),
              onPressed: () {
                Navigator.of(context)
                    .pop(false); //Return to previous page if cancel is clicked
                _hangUp();
              },
            ),
          ],
        );
      },
    );
  }

  //Invites a peer to a call
  _invitePeer(BuildContext context, String peerId, bool useScreen) async {
    if (_signaling != null && peerId != _selfId) {
      _signaling?.invite(peerId, 'video', useScreen);
    }
  }

  _accept() {
    if (_session != null) {
      _signaling?.accept(_session!.sid);
    }
  }

  _reject() {
    if (_session != null) {
      _signaling?.reject(_session!.sid);
    }
  }

  _hangUp() {
    if (_session != null) {
      _signaling?.bye(_session!.sid);
    }
  }

  _switchCamera() {
    _signaling?.switchCamera();
  }

  //Dialog for selecting the screen share source. KEEP THIS
  Future<void> selectScreenSourceDialog(BuildContext context) async {
    MediaStream? screenStream;
    if (WebRTC.platformIsDesktop) {
      final source = await showDialog<DesktopCapturerSource>(
        context: context,
        builder: (context) => ScreenSelectDialog(),
      );
      if (source != null) {
        try {
          var stream =
              await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
            'video': {
              'deviceId': {'exact': source.id},
              'mandatory': {'frameRate': 30.0}
            }
          });
          stream.getVideoTracks()[0].onEnded = () {
            print(
                'By adding a listener on onEnded you can: 1) catch stop video sharing on Web');
          };
          screenStream = stream;
        } catch (e) {
          print(e);
        }
      }
    } else if (WebRTC.platformIsWeb) {
      screenStream =
          await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
        'audio': false,
        'video': true,
      });
    }
    if (screenStream != null) _signaling?.switchToScreenSharing(screenStream);
  }

  _muteMic() {
    _signaling?.muteMic();
    setState(() {
      widget.muted = _signaling?.isMuted ?? false;
    });
  }

  //Displays all peers
  _buildRow(context, peer) {
    var self = (peer['id'] == _selfId);
    return ListBody(children: <Widget>[
      ListTile(
        title: Text(self
            ? peer['name'] + ', ID: ${peer['id']} ' + ' [Your self]'
            : peer['name'] + ', ID: ${peer['id']} '),
        onTap: null,
        trailing: SizedBox(
            width: 100.0,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                    icon: Icon(self ? Icons.close : Icons.videocam,
                        color: self ? Colors.grey : Colors.black),
                    onPressed: () => _invitePeer(context, peer['id'], false),
                    tooltip: 'Video calling',
                  ),
                  IconButton(
                    icon: Icon(self ? Icons.close : Icons.screen_share,
                        color: self ? Colors.grey : Colors.black),
                    onPressed: () => _invitePeer(context, peer['id'], true),
                    tooltip: 'Screen sharing',
                  )
                ])),
        subtitle: Text('${'[' + peer['user_agent']}]'),
      ),
      const Divider()
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const buttonColor = Color(0xFF252A30);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/logo.png',
                height: 40,
                color: Colors.white,
              ),
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(5),
                splashColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                child: Container(
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people),
                      SizedBox(
                        width: 5,
                      ),
                      Text(
                        '2',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),

          // Text('P2P Call${_selfId != null ? ' [ID ($_selfId)] ' : ''}'),
          backgroundColor: const Color(0xFF1A1919),
          actions: <Widget>[
            GestureDetector(
              onTap: () {},
              child: Container(
                decoration: BoxDecoration(
                  color: buttonColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.all(8.0),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.radio_button_on_rounded,
                      color: Colors.red,
                    ),
                    SizedBox(
                      width: 5,
                    ),
                    Text(
                      'Recording',
                      style: TextStyle(
                        fontSize: 14,
                        // fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const IconButton(
              icon: Icon(
                Icons.settings,
                color: Colors.white,
              ),
              onPressed: null,
              tooltip: 'setup',
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _inCalling
            ? SizedBox(
                width: 350.0,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FloatingActionButton(
                            // tooltip: 'Record',
                            onPressed: null,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.radio_button_checked_rounded,
                              color: Colors.red,
                            ),
                          ),
                          Text(
                            'Record',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          )
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FloatingActionButton(
                            // tooltip: 'Camera',
                            onPressed: _switchCamera,
                            backgroundColor: buttonColor,
                            child: const Icon(Icons.videocam_rounded),
                          ),
                          const Text(
                            'Camera',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          )
                        ],
                      ),
                      // FloatingActionButton(
                      //   child: const Icon(Icons.desktop_mac),
                      //   tooltip: 'Screen Sharing',
                      //   onPressed: () => selectScreenSourceDialog(context),
                      //   backgroundColor:buttonColor,
                      // ),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FloatingActionButton(
                            onPressed: null,
                            // tooltip: 'Speaker',
                            backgroundColor: buttonColor,
                            child: Icon(Icons.volume_up_rounded),
                          ),
                          Text(
                            'Speaker',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          )
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FloatingActionButton(
                            //child: const Icon(Icons.mic),
                            // tooltip: 'Mute Mic',
                            onPressed: _muteMic,

                            backgroundColor: buttonColor,
                            child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: widget.muted
                                    ? const Icon(Icons.mic_off)
                                    : const Icon(Icons.mic)),
                          ),
                          Text(
                            widget.muted ? 'Unmute' : 'Mute',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          )
                        ],
                      ),
                      // const Spacer(),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FloatingActionButton(
                            // tooltip: 'Leave',
                            onPressed: _hangUp,
                            backgroundColor: const Color(0xFF1A1919),
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.red,
                            ),
                          ),
                          const Text(
                            'Leave',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          )
                        ],
                      ),
                    ]))
            : null,
        body: _inCalling
            ? Container(
                color: const Color(0xFF131213),
                padding: const EdgeInsets.only(
                    left: 20, top: 20, bottom: 0, right: 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      flex: 12,
                      child: Container(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(
                              flex: 1,
                              child: Container(
                                margin: const EdgeInsets.only(
                                    right: 10, bottom: 90),
                                // decoration: BoxDecoration(
                                //   color: const Color(0xFF1A1919),
                                //   image: _remoteRenderer.renderVideo
                                //       ? null
                                //       : const DecorationImage(
                                //           image: NetworkImage(
                                //               'https://media.istockphoto.com/id/1214360990/photo/e-learning.jpg?s=612x612&w=0&k=20&c=r6YfVfuCFvnv3wD2rmSGfoqXkvf-KO4TSkj04S0k9J0='),
                                //           fit: BoxFit.cover,
                                //         ),
                                //   borderRadius: BorderRadius.circular(10),
                                // ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: RTCVideoView(_remoteRenderer,
                                          objectFit: RTCVideoViewObjectFit
                                              .RTCVideoViewObjectFitCover),
                                    ),
                                    const Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Icon(
                                        Icons.radio_button_checked_rounded,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const Positioned(
                                      bottom: 10,
                                      left: 10,
                                      child: Text(
                                        'Lara',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 90),
                                // decoration: BoxDecoration(
                                //   color: const Color(0xFF1A1919),
                                //   image: _localRenderer.renderVideo
                                //       ? null
                                //       : const DecorationImage(
                                //           image: NetworkImage(
                                //               'https://storage.googleapis.com/pai-images/2e5c7ef7aaa34ebfb3837960cbd978d6.jpeg'),
                                //           fit: BoxFit.cover,
                                //         ),
                                //   borderRadius: BorderRadius.circular(10),
                                // ), // Background color for local video
                                child: Stack(
                                  children: <Widget>[
                                    Positioned.fill(
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: RTCVideoView(_localRenderer,
                                              mirror: true,
                                              objectFit: RTCVideoViewObjectFit
                                                  .RTCVideoViewObjectFitCover),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 16,
                                      child: Container(
                                        width: 0,
                                        height: 0,
                                        decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                                  255, 89, 0, 255)
                                              .withOpacity(0.4),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Icon(
                                        Icons.radio_button_checked_rounded,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const Positioned(
                                      bottom: 10,
                                      left: 10,
                                      child: Text(
                                        'Tom',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: isOpen ? 3 : 1,
                      child: Stack(
                        children: [
                          isOpen
                              ? Container(
                                  margin: const EdgeInsets.only(left: 20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1919),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Column(
                                    children: [
                                      const TabBar(
                                        indicatorColor: Color(0xFF7A7FD3),
                                        indicatorPadding:
                                            EdgeInsets.symmetric(horizontal: 8),
                                        automaticIndicatorColorAdjustment: true,
                                        indicatorWeight: 3,
                                        tabs: [
                                          Tab(icon: Text("Studio")),
                                          Tab(icon: Text('Media')),
                                          Tab(icon: Text("Chat")),
                                        ],
                                      ),
                                      Expanded(
                                        child: TabBarView(
                                          children: [
                                            Column(
                                              children: [
                                                Container(
                                                  height: 120,
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.all(8)
                                                          .copyWith(bottom: 2),
                                                  margin:
                                                      const EdgeInsets.all(10)
                                                          .copyWith(),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF222223),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Text(
                                                            'Episode no.25',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          const Spacer(),
                                                          Icon(
                                                            Icons.settings,
                                                            color: Colors
                                                                .grey.shade500,
                                                          )
                                                        ],
                                                      ),
                                                      Text(
                                                        'Audio & Video - (720p live)',
                                                        style: TextStyle(
                                                          color: Colors
                                                              .grey.shade500,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      const Spacer(),
                                                      Row(
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                        .only(
                                                                    right: 8),
                                                            child: Icon(
                                                              Icons.people,
                                                              color: Colors.grey
                                                                  .shade500,
                                                              size: 15,
                                                            ),
                                                          ),
                                                          Text(
                                                            'You & 1 other',
                                                            style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade500,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          const Spacer(),
                                                          GestureDetector(
                                                            onTap: () {},
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color:
                                                                    buttonColor,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            5),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(4.0),
                                                              margin:
                                                                  const EdgeInsets
                                                                      .all(8.0),
                                                              child: const Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .person_add_rounded,
                                                                    color: Colors
                                                                        .white,
                                                                    size: 15,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 5,
                                                                  ),
                                                                  Text(
                                                                    'invite',
                                                                    style:
                                                                        TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          Icon(
                                                            Icons.info_outline,
                                                            size: 20,
                                                            color: Colors
                                                                .grey.shade500,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  height: 90,
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.all(8)
                                                          .copyWith(
                                                              bottom: 0,
                                                              top: 2),
                                                  margin:
                                                      const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF222223),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      ListTile(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        leading:
                                                            const CircleAvatar(
                                                          backgroundImage:
                                                              NetworkImage(
                                                            'https://images.ctfassets.net/hrltx12pl8hq/3j5RylRv1ZdswxcBaMi0y7/b84fa97296bd2350db6ea194c0dce7db/Music_Icon.jpg',
                                                          ),
                                                        ),
                                                        title: const Text(
                                                          'Lara',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        subtitle: Text(
                                                          'Host 97% uploaded',
                                                          style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade500),
                                                        ),
                                                        tileColor: Colors.red,
                                                        onTap: () {},
                                                      ),
                                                      SliderTheme(
                                                        data: SliderTheme.of(
                                                                context)
                                                            .copyWith(
                                                          activeTrackColor: Colors
                                                              .green, // Color for active track sections

                                                          disabledActiveTickMarkColor:
                                                              Colors
                                                                  .black, // Color for inactive track
                                                          thumbShape:
                                                              CustomThumbShape(
                                                                  thumbRadius:
                                                                      6),
                                                          thumbColor:
                                                              Colors.white,
                                                          trackHeight: 4,
                                                          trackShape:
                                                              ColoredTrackShape(),
                                                          tickMarkShape:
                                                              SliderTickMarkShape
                                                                  .noTickMark,
                                                          overlayShape:
                                                              CustomOverlayShape(),
                                                        ),
                                                        child: Slider(
                                                          value: progress1,
                                                          onChanged:
                                                              (newValue) {
                                                            setState(() {
                                                              progress1 =
                                                                  newValue;
                                                              print(progress1);
                                                            });
                                                          },
                                                          min: 0.0,
                                                          max: 100.0,
                                                          divisions:
                                                              200, // Number of sections in the active track
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  height: 90,
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.all(8)
                                                          .copyWith(
                                                              bottom: 0,
                                                              top: 2),
                                                  margin:
                                                      const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF222223),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      ListTile(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        leading:
                                                            const CircleAvatar(
                                                          backgroundImage:
                                                              NetworkImage(
                                                            'https://storage.googleapis.com/pai-images/2e5c7ef7aaa34ebfb3837960cbd978d6.jpeg',
                                                          ),
                                                        ),
                                                        title: const Text(
                                                          'Tom',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        subtitle: Text(
                                                          'Guest 89% uploaded',
                                                          style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade500),
                                                        ),
                                                        tileColor: Colors.red,
                                                        onTap: () {},
                                                      ),
                                                      SliderTheme(
                                                        data: SliderTheme.of(
                                                                context)
                                                            .copyWith(
                                                          activeTrackColor: Colors
                                                              .green, // Color for active track sections

                                                          disabledActiveTickMarkColor:
                                                              Colors
                                                                  .black, // Color for inactive track
                                                          thumbShape:
                                                              CustomThumbShape(
                                                                  thumbRadius:
                                                                      6),
                                                          thumbColor:
                                                              Colors.white,
                                                          trackHeight: 4,
                                                          trackShape:
                                                              ColoredTrackShape(),
                                                          tickMarkShape:
                                                              SliderTickMarkShape
                                                                  .noTickMark,
                                                          overlayShape:
                                                              CustomOverlayShape(),
                                                        ),
                                                        child: Slider(
                                                          value: progress2,
                                                          onChanged:
                                                              (newValue) {
                                                            setState(() {
                                                              progress2 =
                                                                  newValue;
                                                              print(progress2);
                                                            });
                                                          },
                                                          min: 0.0,
                                                          max: 100.0,
                                                          divisions:
                                                              200, // Number of sections in the active track
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Text(
                                              'Media',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            const Text(
                                              'Chat',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  margin: const EdgeInsets.only(left: 20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1919),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  padding:
                                      const EdgeInsets.only(top: 60, left: 10),
                                  child: const Text(
                                    'View More',
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                          // Positioned(
                          //   top: 60,
                          //   left: 10,
                          //   child: InkWell(
                          //     onTap: () {
                          //       setState(() {
                          //         isOpen = true;
                          //       });
                          //     },
                          //     child: CircleAvatar(
                          //       radius: 8,
                          //       backgroundColor: const Color(0xFF252A30),
                          //       child: Icon(
                          //         !isOpen
                          //             ? Icons.arrow_back_ios_new_rounded
                          //             : Icons.arrow_forward_ios_rounded,
                          //         color: Colors.white,
                          //         size: 8,
                          //       ),
                          //     ),
                          //   ),
                          // )
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(0.0),
                itemCount: (_peers != null ? _peers.length : 0),
                itemBuilder: (context, i) {
                  return _buildRow(context, _peers[i]);
                }),
      ),
    );
  }
}
