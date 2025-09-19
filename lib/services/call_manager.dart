// services/call_manager.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:symme/screens/call_screen.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock/wakelock.dart';
import '../models/call.dart';
import '../services/call_service.dart';
import '../services/webrtc_service.dart';
import '../services/firebase_message_service.dart';
import '../services/navigation_service.dart'; // Import NavigationService

class CallManager {
  static CallManager? _instance;
  static CallManager get instance => _instance ??= CallManager._();

  CallManager._();

  final WebRTCService _webRTCService = WebRTCService.instance;

  StreamSubscription<Call>? _incomingCallSubscription;
  StreamSubscription<Map<String, dynamic>>? _callSignalSubscription;

  Call? _currentCall;
  Timer? _ringtoneTimer;

  bool get hasActiveCall => _currentCall != null;
  Call? get currentCall => _currentCall;

  Future<void> initialize(BuildContext context) async {
    await CallService.initialize();
    await _webRTCService.initialize();

    _listenForIncomingCalls();
    _listenForCallSignals();
  }

  void _listenForIncomingCalls() {
    _incomingCallSubscription = CallService.incomingCalls.listen(
      (call) {
        _handleIncomingCall(call);
      },
      onError: (error) {
        print('Error listening for incoming calls: $error');
      },
    );
  }

  void _listenForCallSignals() {
    _callSignalSubscription = FirebaseMessageService.listenForCallSignals()
        .listen(
          (signal) {
            _handleCallSignal(signal);
          },
          onError: (error) {
            print('Error listening for call signals: $error');
          },
        );
  }

  void _handleIncomingCall(Call call) {
    _currentCall = call;
    _startRingtone();
    _showIncomingCallScreen(call);
  }

  void _handleCallSignal(Map<String, dynamic> signal) async {
    final type = signal['type'] as String;
    final callId = signal['callId'] as String;
    final data = signal['data'] as Map<String, dynamic>;

    try {
      switch (type) {
        case 'offer':
          // Handle incoming call offer
          final callType = signal['callType'] == 'video'
              ? CallType.video
              : CallType.audio;
          final call = Call(
            id: callId,
            callerId: signal['senderId'],
            receiverId: signal['receiverId'],
            type: callType,
            status: CallStatus.incoming,
            timestamp: DateTime.now(),
          );
          _handleIncomingCall(call);
          break;

        case 'answer':
          // Handle call answer
          await _webRTCService.handleCallAnswer(data);
          break;

        case 'ice-candidate':
          // Handle ICE candidate
          await _webRTCService.handleIceCandidate(data);
          break;

        case 'decline':
          // Handle call decline
          _handleCallDeclined();
          break;

        case 'end':
          // Handle call end
          _handleCallEnded();
          break;
      }
    } catch (e) {
      print('Error handling call signal: $e');
    }
  }

  Future<void> startCall({
    required String receiverSecureId,
    required CallType callType,
  }) async {
    try {
      if (hasActiveCall) {
        throw Exception('Another call is already in progress');
      }

      // Enable wakelock to keep screen on
      await Wakelock.enable();

      final call = await CallService.initiateCall(
        receiverSecureId: receiverSecureId,
        callType: callType,
      );

      if (call != null) {
        _currentCall = call.copyWith(status: CallStatus.outgoing);
        _showCallScreen(_currentCall!, isIncoming: false);

        await _webRTCService.startCall(
          receiverId: call.receiverId,
          callType: call.type,
        );
      } else {
        throw Exception('Failed to initiate call');
      }
    } catch (e) {
      await Wakelock.disable();
      rethrow;
    }
  }

  Future<void> answerCall(Call call) async {
    try {
      _stopRingtone();
      await Wakelock.enable();

      _currentCall = call;
      await CallService.answerCall(call.id);
      _showCallScreen(call, isIncoming: true);

      // The WebRTC answer will be handled by the call signal
    } catch (e) {
      await Wakelock.disable();
      rethrow;
    }
  }

  Future<void> declineCall(Call call) async {
    try {
      _stopRingtone();
      await CallService.declineCall(call.id);
      await _webRTCService.declineCall(call.id);
      _currentCall = null;
    } catch (e) {
      print('Error declining call: $e');
    }
  }

  Future<void> endCall() async {
    try {
      _stopRingtone();
      await Wakelock.disable();

      if (_currentCall != null) {
        await CallService.endCall(_currentCall!.id);
        await _webRTCService.endCall();
        _currentCall = null;
      }
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  void _handleCallDeclined() {
    _stopRingtone();
    _currentCall = null;

    ScaffoldMessenger.of(
      NavigationService.currentContext,
    ).showSnackBar(const SnackBar(content: Text('Call declined')));
  }

  void _handleCallEnded() async {
    _stopRingtone();
    await Wakelock.disable();
    _currentCall = null;
  }

  void _showIncomingCallScreen(Call call) {
    NavigationService.push(CallScreen(call: call, isIncoming: true));
  }

  void _showCallScreen(Call call, {required bool isIncoming}) {
    NavigationService.push(CallScreen(call: call, isIncoming: isIncoming));
  }

  void _startRingtone() {
    _ringtoneTimer?.cancel();

    // Start vibration pattern
    _vibrate();

    // Repeat vibration every 3 seconds
    _ringtoneTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _vibrate();
    });
  }

  void _stopRingtone() {
    _ringtoneTimer?.cancel();
    _ringtoneTimer = null;
  }

  void _vibrate() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 1000);
      }
    } catch (e) {
      print('Error vibrating: $e');
    }
  }

  void dispose() {
    _incomingCallSubscription?.cancel();
    _callSignalSubscription?.cancel();
    _stopRingtone();
    _webRTCService.dispose();
    CallService.dispose();
    Wakelock.disable();
  }
}
