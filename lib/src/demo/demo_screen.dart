import 'dart:async';
import 'dart:convert';

import 'package:demo_rtc/src/demo/demo_signaling.dart';
import 'package:demo_rtc/src/utils/socket_client.dart';
import 'package:demo_rtc/src/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class DemoScreen extends StatefulWidget {
  @override
  _DemoScreenState createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  Session? session;
  Signaling? _signaling;
  List<dynamic>? _peers;
  var _selfId;
  RTCVideoRenderer? _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer? _remoteRenderer = RTCVideoRenderer();
  bool? _inCalling = false;
  RTCPeerConnection? _peerConnection;

  TextEditingController _offerDescController = TextEditingController();
  TextEditingController _answerDescController = TextEditingController();
  TextEditingController _setRemoteController = TextEditingController();
  TextEditingController _iceController = TextEditingController();

  List<RTCIceCandidate> _listIceCandidate = [];

  @override
  initState() {
    super.initState();
    initRenderers();
    _connect();
    SocketClient().connect('wss://echo.websocket.org');
  }

  initRenderers() async {
    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();
  }

  @override
  deactivate() {
    super.deactivate();
    if (_peerConnection != null) {
      _peerConnection!.close();
    }
    _localRenderer!.dispose();
    _remoteRenderer!.dispose();
  }

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
    _remoteRenderer!.srcObject = stream;
  }

  void _onRemoveStream(MediaStream stream) {
    _remoteRenderer!.srcObject = null;
  }

  void _onCandidate(RTCIceCandidate? candidate) {
    if (candidate == null) {
      print('iceCandidate is Complete');
      return;
    }
    _listIceCandidate.add(candidate);
    print('onCandidate: ${json.encode(candidate.toMap())}');
    setState(() {});
  }

  void _onTrack(RTCTrackEvent event) {
    print('onTrack');
    if (event.track.kind == 'video') {
      _remoteRenderer!.srcObject = event.streams[0];
    }
  }

  void _onAddTrack(MediaStream stream, MediaStreamTrack track) {
    if (track.kind == 'video') {
      _remoteRenderer!.srcObject = stream;
    }
  }

  void _onRemoveTrack(MediaStream stream, MediaStreamTrack track) {
    if (track.kind == 'video') {
      _remoteRenderer!.srcObject = null;
    }
  }

  void _onRenegotiationNeeded() {
    print('RenegotiationNeeded');
  }

  void _createStream() async {
    _localRenderer!.srcObject = await Signaling().createStream('video', false);
  }

  void _connect() async {
    final mediaConstraints = WebRTC.platformIsAndroid
        ? <String, dynamic>{
            'audio': true,
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
            'audio': true,
            'video': {
              'width': '1280',
              'height': '720',
              'facingMode': 'user',
            }
          };

    var configuration = <String, dynamic>{
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': Signaling().sdpSemantics
    };

    final _config = <String, dynamic>{
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': false},
      ],
    };

    if (_peerConnection != null) return;

    try {
      _peerConnection = await createPeerConnection(configuration, _config);

      _peerConnection!.onSignalingState = _onSignalingState;
      _peerConnection!.onIceGatheringState = _onIceGatheringState;
      _peerConnection!.onIceConnectionState = _onIceConnectionState;
      _peerConnection!.onConnectionState = _onPeerConnectionState;
      _peerConnection!.onIceCandidate = _onCandidate;
      _peerConnection!.onRenegotiationNeeded = _onRenegotiationNeeded;

      MediaStream? _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer!.srcObject = _localStream;

      switch (Signaling().sdpSemantics) {
        case 'plan-b':
          _peerConnection!.onAddStream = _onAddStream;
          _peerConnection!.onRemoveStream = _onRemoveStream;
          await _peerConnection!.addStream(_localStream);
          break;
        case 'unified-plan':
          _peerConnection!.onTrack = _onTrack;
          _peerConnection!.onAddTrack = _onAddTrack;
          _peerConnection!.onRemoveTrack = _onRemoveTrack;
          _localStream.getTracks().forEach((track) {
            _peerConnection!.addTrack(track, _localStream);
          });
          break;
      }

      /*
      await _peerConnection.addTransceiver(
        track: _localStream.getAudioTracks()[0],
        init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendRecv, streams: [_localStream]),
      );
      */
      /*
      // ignore: unused_local_variable
      var transceiver = await _peerConnection.addTransceiver(
        track: _localStream.getVideoTracks()[0],
        init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendRecv, streams: [_localStream]),
      );
      */

      /*
      // Unified-Plan Simulcast
      await _peerConnection.addTransceiver(
          track: _localStream.getVideoTracks()[0],
          init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendOnly,
            streams: [_localStream],
            sendEncodings: [
              // for firefox order matters... first high resolution, then scaled resolutions...
              RTCRtpEncoding(
                rid: 'f',
                maxBitrate: 900000,
                numTemporalLayers: 3,
              ),
              RTCRtpEncoding(
                rid: 'h',
                numTemporalLayers: 3,
                maxBitrate: 300000,
                scaleResolutionDownBy: 2.0,
              ),
              RTCRtpEncoding(
                rid: 'q',
                numTemporalLayers: 3,
                maxBitrate: 100000,
                scaleResolutionDownBy: 4.0,
              ),
            ],
          ));
      
      await _peerConnection.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeVideo);
      await _peerConnection.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeVideo);
      await _peerConnection.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
          init:
              RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly));
      */

      // _peerConnection!.getStats();
      /* Unfied-Plan replaceTrack
      var stream = await MediaDevices.getDisplayMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;
      await transceiver.sender.replaceTrack(stream.getVideoTracks()[0]);
      // do re-negotiation ....
      */
    } catch (e) {
      print(e.toString());
    }
    if (!mounted) return;
  }

  void addIceCandidate() async {
    String jsonString = _iceController.text;
    dynamic session = json.decode(jsonString);
    print("Ice : ${session['candidate']}");
    dynamic candidate = new RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);

    await _peerConnection!.addCandidate(candidate);
  }

  void createOffer() {
    if (_peerConnection != null) {
      Signaling().createOffer(_peerConnection!, 'video').then((value) {
        setState(() {
          _offerDescController.text = json.encode(value!.toMap());
        });
      });
    }
  }

  void createAnswer() {
    if (_peerConnection != null) {
      Signaling().createAnswer(_peerConnection!, 'video').then((value) {
        setState(() {
          _answerDescController.text = json.encode(value!.toMap());
        });
      });
    }
  }

  void setRemoteDesc() async {
    var data = json.decode(_setRemoteController.text);
    RTCSessionDescription description =
        RTCSessionDescription(data['sdp'], data['type']);
    print("SetRemote");
    await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(description.sdp, description.type));
  }

  void _sendToSocket() {
    var message = _offerDescController.text;
    SocketClient().sendMessage(message);
  }

  SizedBox videoRenderers() => SizedBox(
      height: 210,
      child: Row(children: [
        _localRenderer == null
            ? SizedBox()
            : Flexible(
                child: new Container(
                    key: new Key("local"),
                    margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
                    decoration: new BoxDecoration(color: Colors.black),
                    child: new RTCVideoView(_localRenderer!)),
              ),
        Flexible(
          child: new Container(
              key: new Key("remote"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_remoteRenderer!)),
        )
      ]));

  Row offerAndAnswerButtons() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
        new MaterialButton(
          onPressed: _sendToSocket,
          child: Text('Offer'),
          color: Colors.blue,
        ),
        MaterialButton(
          onPressed: createAnswer,
          child: Text('Answer'),
          color: Colors.amber,
        ),
      ]);

  Row sdpCandidateButtons() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
        MaterialButton(
          onPressed: setRemoteDesc,
          child: Text('Set Remote Desc'),
          color: Colors.amber,
        ),
        MaterialButton(
          onPressed: addIceCandidate,
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
              controller: _offerDescController,
              keyboardType: TextInputType.multiline,
              maxLines: 4,
              maxLength: TextField.noMaxLength,
            ),
            Text("Session Answer"),
            TextField(
              controller: _answerDescController,
              keyboardType: TextInputType.multiline,
              maxLines: 4,
              maxLength: TextField.noMaxLength,
            ),
            Text("Set Remote"),
            TextField(
              controller: _setRemoteController,
              keyboardType: TextInputType.multiline,
              maxLines: 4,
              maxLength: TextField.noMaxLength,
            ),
            Text("Set ICECandidate"),
            TextField(
              controller: _iceController,
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
          ListView.builder(
              shrinkWrap: true,
              itemCount: _listIceCandidate.length,
              itemBuilder: (c, i) {
                return CopyableText(json.encode(_listIceCandidate[i].toMap()));
              })
        ])));
  }
}
