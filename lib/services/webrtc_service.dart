// services/webrtc_service.dart
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call.dart';
import 'firebase_message_service.dart';
import 'storage_service.dart';

class WebRTCService {
  static WebRTCService? _instance;
  static WebRTCService get instance => _instance ??= WebRTCService._();
  
  WebRTCService._();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  final StreamController<MediaStream> _localStreamController = StreamController.broadcast();
  final StreamController<MediaStream> _remoteStreamController = StreamController.broadcast();
  final StreamController<CallStatus> _callStatusController = StreamController.broadcast();
  
  Stream<MediaStream> get localStream => _localStreamController.stream;
  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;
  Stream<CallStatus> get callStatus => _callStatusController.stream;
  
  String? _currentCallId;
  CallType? _currentCallType;
  bool _isInitialized = false;

  // STUN servers configuration
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Request permissions
      await _requestPermissions();
      _isInitialized = true;
    } catch (e) {
      print('WebRTC initialization error: $e');
      throw Exception('Failed to initialize WebRTC: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      // Request camera and microphone permissions
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false, // Start with audio only for permission
      });
      
      // Stop the stream immediately as we just needed permission
      stream.getTracks().forEach((track) => track.stop());
    } catch (e) {
      print('Permission request error: $e');
      throw Exception('Microphone permission required');
    }
  }

  Future<void> startCall({
    required String receiverId,
    required CallType callType,
  }) async {
    try {
      await initialize();
      
      _currentCallType = callType;
      _currentCallId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create peer connection
      await _createPeerConnection();
      
      // Get user media
      await _getUserMedia(callType);
      
      // Create offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      // Send call signal through Firebase
      await FirebaseMessageService.sendCallSignal(
        receiverId: receiverId,
        callId: _currentCallId!,
        type: 'offer',
        data: offer.toMap(),
        callType: callType,
      );
      
      _callStatusController.add(CallStatus.outgoing);
    } catch (e) {
      print('Start call error: $e');
      await endCall();
      throw Exception('Failed to start call: $e');
    }
  }

  Future<void> answerCall({
    required String callId,
    required Map<String, dynamic> offerData,
    required CallType callType,
  }) async {
    try {
      await initialize();
      
      _currentCallId = callId;
      _currentCallType = callType;
      
      // Create peer connection
      await _createPeerConnection();
      
      // Get user media
      await _getUserMedia(callType);
      
      // Set remote description (offer)
      final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
      await _peerConnection!.setRemoteDescription(offer);
      
      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      // Send answer through Firebase
      final currentUserId = await StorageService.getUserId();
      await FirebaseMessageService.sendCallSignal(
        receiverId: callId, // Use callId to identify the caller
        callId: _currentCallId!,
        type: 'answer',
        data: answer.toMap(),
        callType: callType,
      );
      
      _callStatusController.add(CallStatus.connecting);
    } catch (e) {
      print('Answer call error: $e');
      await endCall();
      throw Exception('Failed to answer call: $e');
    }
  }

  Future<void> handleCallAnswer(Map<String, dynamic> answerData) async {
    try {
      if (_peerConnection == null) return;
      
      final answer = RTCSessionDescription(answerData['sdp'], answerData['type']);
      await _peerConnection!.setRemoteDescription(answer);
      
      _callStatusController.add(CallStatus.connecting);
    } catch (e) {
      print('Handle call answer error: $e');
    }
  }

  Future<void> handleIceCandidate(Map<String, dynamic> candidateData) async {
    try {
      if (_peerConnection == null) return;
      
      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );
      
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      print('Handle ICE candidate error: $e');
    }
  }

  Future<void> declineCall(String callId) async {
    try {
      await FirebaseMessageService.sendCallSignal(
        receiverId: callId,
        callId: callId,
        type: 'decline',
        data: {},
        callType: CallType.audio,
      );
      
      await endCall();
    } catch (e) {
      print('Decline call error: $e');
    }
  }

  Future<void> endCall() async {
    try {
      // Send end call signal if there's an active call
      if (_currentCallId != null) {
        await FirebaseMessageService.sendCallSignal(
          receiverId: _currentCallId!,
          callId: _currentCallId!,
          type: 'end',
          data: {},
          callType: _currentCallType ?? CallType.audio,
        );
      }
      
      // Stop local stream
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) => track.stop());
        _localStream = null;
      }
      
      // Stop remote stream
      if (_remoteStream != null) {
        _remoteStream!.getTracks().forEach((track) => track.stop());
        _remoteStream = null;
      }
      
      // Close peer connection
      await _peerConnection?.close();
      _peerConnection = null;
      
      _currentCallId = null;
      _currentCallType = null;
      
      _callStatusController.add(CallStatus.ended);
    } catch (e) {
      print('End call error: $e');
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      _peerConnection = await createPeerConnection(_iceServers);
      
      // Handle ICE candidates
      _peerConnection!.onIceCandidate = (candidate) async {
        if (candidate.candidate != null && _currentCallId != null) {
          await FirebaseMessageService.sendCallSignal(
            receiverId: _currentCallId!,
            callId: _currentCallId!,
            type: 'ice-candidate',
            data: {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
            callType: _currentCallType ?? CallType.audio,
          );
        }
      };
      
      // Handle remote stream
      _peerConnection!.onAddStream = (stream) {
        _remoteStream = stream;
        _remoteStreamController.add(stream);
        _callStatusController.add(CallStatus.connected);
      };
      
      // Handle connection state changes
      _peerConnection!.onConnectionState = (state) {
        print('Connection state: $state');
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _callStatusController.add(CallStatus.connected);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _callStatusController.add(CallStatus.ended);
            break;
          default:
            break;
        }
      };
    } catch (e) {
      print('Create peer connection error: $e');
      throw Exception('Failed to create peer connection: $e');
    }
  }

  Future<void> _getUserMedia(CallType callType) async {
    try {
      final constraints = {
        'audio': true,
        'video': callType == CallType.video ? {
          'width': 640,
          'height': 480,
          'frameRate': 30,
        } : false,
      };
      
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      
      if (_peerConnection != null) {
        await _peerConnection!.addStream(_localStream!);
      }
      
      _localStreamController.add(_localStream!);
    } catch (e) {
      print('Get user media error: $e');
      throw Exception('Failed to access camera/microphone: $e');
    }
  }

  Future<void> toggleMicrophone() async {
    if (_localStream == null) return;
    
    final audioTrack = _localStream!.getAudioTracks().first;
    audioTrack.enabled = !audioTrack.enabled;
  }

  Future<void> toggleCamera() async {
    if (_localStream == null) return;
    
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      final videoTrack = videoTracks.first;
      videoTrack.enabled = !videoTrack.enabled;
    }
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
    }
  }

  bool get isMicrophoneEnabled {
    if (_localStream == null) return false;
    final audioTracks = _localStream!.getAudioTracks();
    return audioTracks.isNotEmpty && audioTracks.first.enabled;
  }

  bool get isCameraEnabled {
    if (_localStream == null) return false;
    final videoTracks = _localStream!.getVideoTracks();
    return videoTracks.isNotEmpty && videoTracks.first.enabled;
  }

  bool get hasActiveCall => _currentCallId != null;

  String? get currentCallId => _currentCallId;
  
  CallType? get currentCallType => _currentCallType;

  void dispose() {
    endCall();
    _localStreamController.close();
    _remoteStreamController.close();
    _callStatusController.close();
  }
}