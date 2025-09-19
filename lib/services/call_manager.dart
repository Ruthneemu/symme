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
import '../utils/helpers.dart';

class CallManager {
  static CallManager? _instance;
  static CallManager get instance => _instance ??= CallManager._();

  CallManager._();

  final WebRTCService _webRTCService = WebRTCService.instance;

  StreamSubscription<Call>? _incomingCallSubscription;
  StreamSubscription<Map<String, dynamic>>? _callSignalSubscription;
  StreamSubscription<CallStatus>? _callStatusSubscription;

  Call? _currentCall;
  Timer? _ringtoneTimer;
  BuildContext? _context;

  bool get hasActiveCall => _currentCall != null;
  Call? get currentCall => _currentCall;

  Future<void> initialize(BuildContext context) async {
    _context = context;
    print('Initializing CallManager...');

    try {
      await CallService.initialize();
      await _webRTCService.initialize();

      _listenForIncomingCalls();
      _listenForCallSignals();
      _listenForCallStatus();

      print('CallManager initialized successfully');
    } catch (e) {
      print('CallManager initialization error: $e');
      throw Exception('Failed to initialize CallManager: $e');
    }
  }

  void _listenForIncomingCalls() {
    _incomingCallSubscription = CallService.incomingCalls.listen(
      (call) {
        print('Incoming call received: ${call.id}');
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
            print('Call signal received: ${signal['type']}');
            _handleCallSignal(signal);
          },
          onError: (error) {
            print('Error listening for call signals: $error');
          },
        );
  }

  void _listenForCallStatus() {
    _callStatusSubscription = _webRTCService.callStatus.listen(
      (status) {
        print('Call status changed: $status');
        _handleCallStatusChange(status);
      },
      onError: (error) {
        print('Error listening for call status: $error');
      },
    );
  }

  void _handleCallStatusChange(CallStatus status) {
    if (_currentCall == null) return;

    switch (status) {
      case CallStatus.failed:
        _showError('Call failed to connect');
        _handleCallEnded();
        break;
      case CallStatus.ended:
        _handleCallEnded();
        break;
      case CallStatus.connected:
        _stopRingtone();
        // Update call status in UI if needed
        break;
      default:
        break;
    }
  }

  void _handleIncomingCall(Call call) {
    if (hasActiveCall) {
      print('Rejecting incoming call - already in a call');
      declineCall(call);
      return;
    }

    _currentCall = call;
    _startRingtone();
    _showIncomingCallScreen(call);
  }

  void _handleCallSignal(Map<String, dynamic> signal) async {
    final type = signal['type'] as String;
    final callId = signal['callId'] as String;
    final senderId = signal['senderId'] as String?;
    final data = signal['data'] as Map<String, dynamic>? ?? {};

    try {
      switch (type) {
        case 'offer':
          // Handle incoming call offer
          final callType = signal['callType'] == 'video'
              ? CallType.video
              : CallType.audio;
          final call = Call(
            id: callId,
            callerId: senderId ?? 'unknown',
            receiverId: signal['receiverId'] ?? '',
            type: callType,
            status: CallStatus.incoming,
            timestamp: DateTime.now(),
            callerName: senderId,
          );
          _handleIncomingCall(call);
          break;

        case 'answer':
          // Handle call answer
          print('Processing call answer...');
          await _webRTCService.handleCallAnswer(data);
          break;

        case 'ice-candidate':
          // Handle ICE candidate
          print('Processing ICE candidate...');
          await _webRTCService.handleIceCandidate(data);
          break;

        case 'decline':
          // Handle call decline
          print('Call declined by remote party');
          _handleCallDeclined();
          break;

        case 'end':
          // Handle call end
          print('Call ended by remote party');
          _handleCallEnded();
          break;

        default:
          print('Unknown call signal type: $type');
      }
    } catch (e) {
      print('Error handling call signal: $e');
      _handleCallError('Signal processing failed: $e');
    }
  }

  Future<void> startCall({
    required String receiverSecureId,
    required CallType callType,
  }) async {
    try {
      print('Starting call to $receiverSecureId, type: $callType');

      if (hasActiveCall) {
        throw Exception('Another call is already in progress');
      }

      // Show calling indicator immediately
      _showCallingIndicator(receiverSecureId, callType);

      // Enable wakelock to keep screen on
      await Wakelock.enable();

      // Create call record in Firebase
      final call = await CallService.initiateCall(
        receiverSecureId: receiverSecureId,
        callType: callType,
      );

      if (call == null) {
        throw Exception('Failed to create call record');
      }

      _currentCall = call.copyWith(status: CallStatus.outgoing);

      // Start WebRTC call
      await _webRTCService.startCall(
        receiverId: call.receiverId,
        callType: callType,
      );

      // Navigate to call screen
      _showCallScreen(_currentCall!, isIncoming: false);

      print('Call started successfully');
    } catch (e) {
      print('Start call error: $e');
      await Wakelock.disable();
      _hideCallingIndicator();
      _currentCall = null;
      _showError('Failed to start call: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> answerCall(Call call) async {
    try {
      print('Answering call: ${call.id}');

      _stopRingtone();
      await Wakelock.enable();

      _currentCall = call.copyWith(status: CallStatus.connecting);

      // Update call status in Firebase
      await CallService.answerCall(call.id);

      // Answer via WebRTC - need to pass the offer data
      // This should be handled by the call signal processing

      print('Call answered successfully');
    } catch (e) {
      print('Answer call error: $e');
      await Wakelock.disable();
      _showError('Failed to answer call: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> declineCall(Call call) async {
    try {
      print('Declining call: ${call.id}');

      _stopRingtone();

      await CallService.declineCall(call.id);
      await _webRTCService.declineCall(call.id);

      _currentCall = null;

      if (_context != null && Navigator.canPop(_context!)) {
        Navigator.pop(_context!);
      }
    } catch (e) {
      print('Error declining call: $e');
      _showError('Failed to decline call');
    }
  }

  Future<void> endCall() async {
    try {
      print('Ending call...');

      _stopRingtone();
      await Wakelock.disable();

      if (_currentCall != null) {
        await CallService.endCall(_currentCall!.id);
        await _webRTCService.endCall();
      }

      _currentCall = null;
      _hideCallingIndicator();

      // Close call screen if open
      if (_context != null && Navigator.canPop(_context!)) {
        Navigator.pop(_context!);
      }
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  void _handleCallDeclined() {
    _stopRingtone();
    _currentCall = null;
    _hideCallingIndicator();

    if (_context != null) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        const SnackBar(
          content: Text('Call declined'),
          duration: Duration(seconds: 2),
        ),
      );

      if (Navigator.canPop(_context!)) {
        Navigator.pop(_context!);
      }
    }
  }

  void _handleCallEnded() async {
    _stopRingtone();
    await Wakelock.disable();
    _currentCall = null;
    _hideCallingIndicator();

    if (_context != null && Navigator.canPop(_context!)) {
      Navigator.pop(_context!);
    }
  }

  void _handleCallError(String error) {
    print('Call error: $error');
    _showError(error);
    _handleCallEnded();
  }

  void _showIncomingCallScreen(Call call) {
    if (_context == null) return;

    Navigator.of(_context!)
        .push(
          MaterialPageRoute(
            builder: (context) => CallScreen(call: call, isIncoming: true),
            fullscreenDialog: true,
          ),
        )
        .then((_) {
          // Cleanup when call screen is closed
          if (_currentCall != null) {
            endCall();
          }
        });
  }

  void _showCallScreen(Call call, {required bool isIncoming}) {
    if (_context == null) return;

    _hideCallingIndicator(); // Hide calling indicator when showing call screen

    Navigator.of(_context!)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                CallScreen(call: call, isIncoming: isIncoming),
            fullscreenDialog: true,
          ),
        )
        .then((_) {
          // Cleanup when call screen is closed
          if (_currentCall != null) {
            endCall();
          }
        });
  }

  void _showCallingIndicator(String receiverId, CallType callType) {
    if (_context == null) return;

    // Show a simple dialog or overlay indicating the call is being placed
    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Calling ${receiverId.substring(0, 4)}...'),
            const SizedBox(height: 8),
            Text(callType == CallType.video ? 'Video Call' : 'Voice Call'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              endCall();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _hideCallingIndicator() {
    if (_context != null && Navigator.canPop(_context!)) {
      Navigator.pop(_context!);
    }
  }

  void _showError(String message) {
    if (_context != null) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
    print('Disposing CallManager');
    _incomingCallSubscription?.cancel();
    _callSignalSubscription?.cancel();
    _callStatusSubscription?.cancel();
    _stopRingtone();
    _webRTCService.dispose();
    CallService.dispose();
    Wakelock.disable();
  }
}
