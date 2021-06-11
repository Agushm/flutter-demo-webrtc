import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class Demo2Screen extends StatefulWidget {
  @override
  _Demo2ScreenState createState() => _Demo2ScreenState();
}

class _Demo2ScreenState extends State<Demo2Screen> {
  bool _offer = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();

  final sdpOfferController = TextEditingController();
  final sdpAnswerController = TextEditingController();
  final setRemoteController = TextEditingController();

  @override
  void initState() {
    initRenderers();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
      setState(() {});
    });
    super.initState();
  }

  @override
  void deactivate() {
    _hangUp();
    super.deactivate();
  }

  void _hangUp() async {
    await _localStream?.dispose();
    await _peerConnection?.close();
    _peerConnection = null;
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;

    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _createOffer() async {
    final offerSdpConstraints = <String, dynamic>{
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };
    try {
      RTCSessionDescription description =
          await _peerConnection!.createOffer(offerSdpConstraints);
      var session = description.sdp;
      setState(() {
        sdpOfferController.text = json.encode(description.toMap());
      });
      _offer = true;

      // print(json.encode({
      //       'sdp': description.sdp.toString(),
      //       'type': description.type.toString(),
      //     }));

      _peerConnection!.setLocalDescription(description);
    } catch (err) {
      print(err.toString());
    }
  }

  void _createAnswer() async {
    final answerSdpConstraints = <String, dynamic>{
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };
    try {
      RTCSessionDescription? description =
          await _peerConnection!.createAnswer(answerSdpConstraints);

      setState(() {
        sdpAnswerController.text = json.encode(description.toMap());
      });
      // print(json.encode({
      //       'sdp': description.sdp.toString(),
      //       'type': description.type.toString(),
      //     }));

      _peerConnection!.setLocalDescription(description);
    } catch (err) {
      print("Error Offer: $err");
    }
  }

  void showSnackBar(String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _setRemoteDescription() async {
    String jsonString = setRemoteController.text;
    dynamic sdp = json.decode(jsonString);
    print(sdp['sdp']);
    RTCSessionDescription _description =
        RTCSessionDescription(sdp['sdp'], 'answer');

    await _peerConnection!.setRemoteDescription(_description);
  }

  void _addCandidate() async {
    String jsonString = sdpAnswerController.text;
    dynamic session = json.decode(jsonString);
    print(session['candidate']);
    dynamic candidate = new RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection!.addCandidate(candidate);
  }

  String get sdpSemantics =>
      WebRTC.platformIsWindows ? 'plan-b' : 'unified-plan';

  void _onSignalingState(RTCSignalingState state) {
    print(state);
  }

  void _onIceGatheringState(RTCIceGatheringState state) {
    print(state);
  }

  void _onIceConnectionState(RTCIceConnectionState state) {
    print(state);
  }

  void _onPeerConnectionState(RTCPeerConnectionState state) {
    print(state);
  }

  void _onAddStream(MediaStream stream) {
    print('New stream: ' + stream.id);
    _remoteRenderer.srcObject = stream;
  }

  void _onRemoveStream(MediaStream stream) {
    _remoteRenderer.srcObject = null;
  }

  void _onCandidate(RTCIceCandidate candidate) {
    print('onCandidate: ${candidate.candidate}');
    _peerConnection?.addCandidate(candidate);
  }

  void _onTrack(RTCTrackEvent event) {
    print('onTrack');
    if (event.track.kind == 'video') {
      _remoteRenderer.srcObject = event.streams[0];
    }
  }

  void _onAddTrack(MediaStream stream, MediaStreamTrack track) {
    if (track.kind == 'video') {
      _remoteRenderer.srcObject = stream;
    }
  }

  void _onRemoveTrack(MediaStream stream, MediaStreamTrack track) {
    if (track.kind == 'video') {
      _remoteRenderer.srcObject = null;
    }
  }

  void _onRenegotiationNeeded() {
    print('RenegotiationNeeded');
  }

  _createPeerConnection() async {
    var configuration = <String, dynamic>{
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': sdpSemantics
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    try {
      _localStream = await _getUserMedia();
      _peerConnection =
          await createPeerConnection(configuration, offerSdpConstraints);
      // if (pc != null) print(pc);
      _peerConnection!.onSignalingState = _onSignalingState;
      _peerConnection!.onIceGatheringState = _onIceGatheringState;
      _peerConnection!.onIceConnectionState = _onIceConnectionState;
      _peerConnection!.onConnectionState = _onPeerConnectionState;
      _peerConnection!.onIceCandidate = _onCandidate;
      _peerConnection!.onRenegotiationNeeded = _onRenegotiationNeeded;

      switch (sdpSemantics) {
        case 'plan-b':
          _peerConnection!.onAddStream = _onAddStream;
          _peerConnection!.onRemoveStream = _onRemoveStream;
          await _peerConnection!.addStream(_localStream!);
          break;
        case 'unified-plan':
          _peerConnection!.onTrack = _onTrack;
          _peerConnection!.onAddTrack = _onAddTrack;
          _peerConnection!.onRemoveTrack = _onRemoveTrack;
          _localStream!.getTracks().forEach((track) {
            _peerConnection!.addTrack(track, _localStream!);
          });
          break;
      }
      return _peerConnection;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  _getUserMedia() async {
    final mediaConstraints = WebRTC.platformIsAndroid
        ? <String, dynamic>{
            'audio': false,
            'video': {
              'mandatory': {
                'minWidth':
                    '1280', // Provide your own width, height and frame rate here
                'minHeight': '720',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          }
        : <String, dynamic>{
            'audio': false,
            'video': {
              'width': '1280',
              'height': '720',
              'facingMode': 'user',
            }
          };

    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);

    // _localStream = stream;
    _localRenderer.srcObject = stream;

    // _peerConnection.addStream(stream);

    return stream;
  }

  SizedBox videoRenderers() => SizedBox(
      height: 210,
      child: Row(children: [
        Flexible(
          child: new Container(
              key: new Key("local"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_localRenderer)),
        ),
        Flexible(
          child: new Container(
              key: new Key("remote"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_remoteRenderer)),
        )
      ]));

  Row offerAndAnswerButtons() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
        new MaterialButton(
          // onPressed: () {
          //   return showDialog(
          //       context: context,
          //       builder: (context) {
          //         return AlertDialog(
          //           content: Text(sdpController.text),
          //         );
          //       });
          // },
          onPressed: _createOffer,
          child: Text('Offer'),
          color: Colors.blue,
        ),
        MaterialButton(
          onPressed: _createAnswer,
          child: Text('Answer'),
          color: Colors.amber,
        ),
      ]);

  Row sdpCandidateButtons() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
        MaterialButton(
          onPressed: _setRemoteDescription,
          child: Text('Set Remote Desc'),
          color: Colors.amber,
        ),
        MaterialButton(
          onPressed: _addCandidate,
          child: Text('Add Candidate'),
          color: Colors.amber,
        )
      ]);

  Padding sdpCandidatesTF() => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Session Offer"),
            TextField(
              controller: sdpOfferController,
              keyboardType: TextInputType.multiline,
              maxLines: 4,
              maxLength: TextField.noMaxLength,
            ),
            Text("Session Answer"),
            TextField(
              controller: sdpAnswerController,
              keyboardType: TextInputType.multiline,
              maxLines: 4,
              maxLength: TextField.noMaxLength,
            ),
            Text("Set Remote"),
            TextField(
              controller: setRemoteController,
              keyboardType: TextInputType.multiline,
              maxLines: 4,
              maxLength: TextField.noMaxLength,
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("DEMO 2"),
        ),
        body: SingleChildScrollView(
            child: Column(children: [
          videoRenderers(),
          offerAndAnswerButtons(),
          sdpCandidatesTF(),
          sdpCandidateButtons(),
        ])));
  }
}
