import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/websocket.dart'
    if (dart.library.js) '../utils/websocket_web.dart';

enum SignalingState {
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

enum CallState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye
}

/*
* Callbacks for Signaling API
*/

typedef void SignalingStateCallback(SignalingState state);
typedef void CallStateCallback(Session session, MediaStream stream);
typedef void StreamStateCallback(Session? session, MediaStream? stream);
typedef void OtherEventCallback(dynamic event);
typedef void DataChannelMessageCallback(
    Session session, RTCDataChannel dc, RTCDataChannelMessage data);
typedef void DataChannelCallback(Session sesion, RTCDataChannel dc);

class Session {
  String? sid;
  String? pid;
  RTCPeerConnection? pc;
  RTCDataChannel? dc;
  List<RTCIceCandidate> remoteCandidates = [];
  Session({this.sid, this.pid});
}

class Signaling {
  JsonEncoder _encoder = JsonEncoder();
  JsonDecoder _decoder = JsonDecoder();
  MediaStream? _localStream;
  List<MediaStream> _remoteStreams = <MediaStream>[];
  Map<String, Session> _sessions = {};
  StreamStateCallback? onLocalStream;
  StreamStateCallback? onAddRemoteStream;
  StreamStateCallback? onRemoveRemoteStream;
  OtherEventCallback? onPeersUpdate;
  DataChannelMessageCallback? onDataChannelMessage;
  DataChannelCallback? onDataChannel;
  SimpleWebSocket? _socket;

  String get sdpSemantics =>
      WebRTC.platformIsWindows ? 'plan-b' : 'unified-plan';

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      /*
       * turn server configuration example.
      {
        'url': 'turn:123.45.67.89:3478',
        'username': 'change_to_real_user',
        'credential': 'change_to_real_secret'
      },
      */
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  close() async {
    await _cleanSessions();
    /* Close Socket 
    *if (_socket != null) _socket?.close();
    */
  }

  Future<void> socketConnect() async {
    var _port = 8086;
    var url = 'ws://echo.websocket.org';
    _socket = SimpleWebSocket(url);

    _socket!.onOpen = () {
      print('onOpen');
      //onSignalingStateChange?.call(SignalingState.ConnectionOpen);
      // _send('new', {
      //   'name': DeviceInfo.label,
      //   'id': _selfId,
      //   'user_agent': DeviceInfo.userAgent
      // });
    };

    _socket!.onMessage = (message) {
      print('Received data: ' + message);
      //onMessage(_decoder.convert(message));
    };

    _socket!.onClose = (int code, String reason) {
      print('Closed by server [$code => $reason]!');
      //onSignalingStateChange?.call(SignalingState.ConnectionClosed);
    };

    await _socket?.connect();
  }

  _send(event, data) {
    var request = Map();
    request["type"] = event;
    request["data"] = data;
    //_socket!.send(_encoder.convert(request));
  }

  Future<MediaStream> createStream(String media, bool? userScreen,
      {Session? session}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'width': '1280',
        'height': '720',
        // 'mandatory': {
        //   'minWidth':
        //       '640', // Provide your own width, height and frame rate here
        //   'minHeight': '480',
        //   'minFrameRate': '30',
        // },
        'facingMode': 'user',
      }
    };

    MediaStream? stream = userScreen!
        ? await navigator.mediaDevices.getDisplayMedia(mediaConstraints)
        : await navigator.mediaDevices.getUserMedia(mediaConstraints);
    //onLocalStream!.call(null, stream);
    return stream;
  }

  Future<Session> createSession(
      {Session? session,
      String? peerId,
      String? sessionId,
      String? media,
      bool? screenSharing}) async {
    var newSession = session ?? Session(sid: sessionId, pid: peerId);
    if (media != 'data') {
      _localStream =
          await createStream(media!, screenSharing, session: newSession);
    }
    print(_iceServers);
    RTCPeerConnection pc = await createPeerConnection({
      ..._iceServers,
      ...{'sdpSemantics': sdpSemantics}
    }, _config);
    if (media != 'data') {
      switch (sdpSemantics) {
        case 'plan-b':
          pc.onAddStream = (MediaStream stream) {
            onAddRemoteStream?.call(newSession, stream);
            _remoteStreams.add(stream);
          };
          await pc.addStream(_localStream!);
          break;
        case 'unified-plan':

          // Unified-Plan
          pc.onTrack = (event) {
            if (event.track.kind == 'video') {
              onAddRemoteStream?.call(newSession, event.streams[0]);
            }
          };
          _localStream!.getTracks().forEach((track) {
            pc.addTrack(track, _localStream!);
          });
          break;
      }

      // Unified-Plan: Simuclast
      /*
      await pc.addTransceiver(
        track: _localStream.getAudioTracks()[0],
        init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendOnly, streams: [_localStream]),
      );

      await pc.addTransceiver(
        track: _localStream.getVideoTracks()[0],
        init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendOnly,
            streams: [
              _localStream
            ],
            sendEncodings: [
              RTCRtpEncoding(rid: 'f', active: true),
              RTCRtpEncoding(
                rid: 'h',
                active: true,
                scaleResolutionDownBy: 2.0,
                maxBitrate: 150000,
              ),
              RTCRtpEncoding(
                rid: 'q',
                active: true,
                scaleResolutionDownBy: 4.0,
                maxBitrate: 100000,
              ),
            ]),
      );*/
      /*
        var sender = pc.getSenders().find(s => s.track.kind == "video");
        var parameters = sender.getParameters();
        if(!parameters)
          parameters = {};
        parameters.encodings = [
          { rid: "h", active: true, maxBitrate: 900000 },
          { rid: "m", active: true, maxBitrate: 300000, scaleResolutionDownBy: 2 },
          { rid: "l", active: true, maxBitrate: 100000, scaleResolutionDownBy: 4 }
        ];
        sender.setParameters(parameters);
      */
    }
    pc.onIceCandidate = (candidate) {
      if (candidate == null) {
        print('onIceCandidate: complete!');
        return;
      }
      addCandidate(newSession, candidate);
      /*  Send to Socket
      *_send('candidate', {
      //   'to': peerId,
      //   'from': _selfId,
      //   'candidate': {
      //     'sdpMLineIndex': candidate.sdpMlineIndex,
      //     'sdpMid': candidate.sdpMid,
      //     'candidate': candidate.candidate,
      //   },
      //   'session_id': sessionId,
      // });
      */
    };

    pc.onIceConnectionState = (state) {};

    pc.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(newSession, stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(newSession, channel);
    };

    newSession.pc = pc;
    return newSession;
  }

  void _addDataChannel(Session session, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {};
    channel.onMessage = (RTCDataChannelMessage data) {
      onDataChannelMessage?.call(session, channel, data);
    };
    session.dc = channel;
    onDataChannel?.call(session, channel);
  }

  Future<RTCSessionDescription?> createOffer(
      RTCPeerConnection pc, String media) async {
    try {
      RTCSessionDescription s =
          await pc.createOffer(media == 'data' ? _dcConstraints : {});
      await pc.setLocalDescription(s);

      return s;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  void sendToSocket(String? message) {
    _send('Message', {'to': 'axxx', 'from': 'fsdasda', 'message': message!});
  }

  Future<RTCSessionDescription?> createAnswer(
      RTCPeerConnection pc, String media) async {
    try {
      RTCSessionDescription s =
          await pc.createAnswer(media == 'data' ? _dcConstraints : {});
      await pc.setLocalDescription(s);
      // _send('answer', {
      //   'to': session.pid,
      //   'from': _selfId,
      //   'description': {'sdp': s.sdp, 'type': s.type},
      //   'session_id': session.sid,
      // });
      return s;
    } catch (e) {
      print(e.toString());
    }
  }

  // void setRemoteDesc(
  //     RTCPeerConnection pc, RTCSessionDescription description) async {
  //   await pc!.setRemoteDescription(
  //       RTCSessionDescription(description.sdp, description.type));

  //   if (remoteCandidates.length > 0) {
  //     session.remoteCandidates.forEach((candidate) async {
  //       await pc!.addCandidate(candidate);
  //     });
  //     session.remoteCandidates.clear();
  //   }
  // }

  Future<void> addCandidate(Session? session, RTCIceCandidate candidate) async {
    if (session != null) {
      if (session.pc != null) {
        await session.pc!.addCandidate(candidate);
      } else {
        session.remoteCandidates.add(candidate);
      }
    } else {
      // _sessions[sessionId] = Session(pid: peerId, sid: sessionId)
      //   ..remoteCandidates.add(candidate);
    }
  }

  void bye(String? sessionId) {
    _closeSession(_sessions[sessionId]);
  }

  Future<void> _cleanSessions() async {
    if (_localStream != null) {
      _localStream!.getTracks().forEach((element) async {
        await element.stop();
      });
      await _localStream!.dispose();
      _localStream = null;
    }
    // _sessions.forEach((key, sess) async {
    //   await sess.pc?.close();
    //   await sess.dc?.close();
    // });
    // _sessions.clear();
  }

  Future<void> _closeSession(Session? session) async {
    _localStream!.getTracks().forEach((element) async {
      await element.stop();
    });
    await _localStream?.dispose();
    _localStream = null;

    await session?.pc?.close();
    await session?.dc?.close();
  }
}
