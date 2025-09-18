// screens/call_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call.dart';
import '../services/webrtc_service.dart';
import '../services/call_service.dart';
import '../utils/helpers.dart';

class CallScreen extends StatefulWidget {
  final Call call;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.call,
    required this.isIncoming,
  });

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final WebRTCService _webRTCService = WebRTCService.instance;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerEnabled = false;

  CallStatus _callStatus = CallStatus.connecting;
  Timer? _callTimer;
  int _callDuration = 0;

  StreamSubscription<MediaStream>? _localStreamSubscription;
  StreamSubscription<MediaStream>? _remoteStreamSubscription;
  StreamSubscription<CallStatus>? _callStatusSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _initializeAnimations();
    _initializeCall();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _localStreamSubscription?.cancel();
    _remoteStreamSubscription?.cancel();
    _callStatusSubscription?.cancel();
    _pulseController.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeCall() async {
    try {
      _listenToStreams();
      _listenToCallStatus();

      if (widget.isIncoming) {
        setState(() {
          _callStatus = CallStatus.incoming;
        });
      } else {
        await _webRTCService.startCall(
          receiverId: widget.call.receiverId,
          callType: widget.call.type,
        );
        setState(() {
          _callStatus = CallStatus.outgoing;
        });
      }
    } catch (e) {
      _showError('Failed to initialize call: ${e.toString()}');
      _endCall();
    }
  }

  void _listenToStreams() {
    _localStreamSubscription = _webRTCService.localStream.listen(
      (stream) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
      },
    );

    _remoteStreamSubscription = _webRTCService.remoteStream.listen(
      (stream) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _isConnected = true;
        });
        _startCallTimer();
      },
    );
  }

  void _listenToCallStatus() {
    _callStatusSubscription = _webRTCService.callStatus.listen(
      (status) {
        setState(() {
          _callStatus = status;
        });

        switch (status) {
          case CallStatus.connected:
            _startCallTimer();
            break;
          case CallStatus.ended:
            _endCall();
            break;
          case CallStatus.failed:
            _showError('Call failed');
            _endCall();
            break;
          default:
            break;
        }
      },
    );
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleMute() async {
    await _webRTCService.toggleMicrophone();
    setState(() {
      _isMuted = !_webRTCService.isMicrophoneEnabled;
    });
  }

  Future<void> _toggleVideo() async {
    if (widget.call.type == CallType.video) {
      await _webRTCService.toggleCamera();
      setState(() {
        _isVideoEnabled = _webRTCService.isCameraEnabled;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (widget.call.type == CallType.video) {
      await _webRTCService.switchCamera();
    }
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerEnabled = !_isSpeakerEnabled;
    });
  }

  Future<void> _endCall() async {
    try {
      await _webRTCService.endCall();
      await CallService.endCall(widget.call.id, duration: _callDuration);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _declineCall() async {
    try {
      await _webRTCService.declineCall(widget.call.id);
      await CallService.declineCall(widget.call.id);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      Helpers.showSnackBar(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            _buildVideoBackground(theme),
            _buildTopBar(theme),
            _buildControlButtons(),
            if (widget.call.type == CallType.video && _isVideoEnabled)
              _buildLocalVideoPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoBackground(ThemeData theme) {
    if (widget.call.type == CallType.video && _isConnected) {
      return Positioned.fill(
        child: RTCVideoView(
          _remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.brightness == Brightness.dark
              ? [
                  Colors.deepPurple.shade900,
                  Colors.deepPurple.shade700,
                  Colors.black
                ]
              : [
                  Colors.deepPurple.shade100,
                  Colors.deepPurple.shade200,
                  Colors.white
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _callStatus == CallStatus.connecting ||
                          _callStatus == CallStatus.outgoing
                      ? _pulseAnimation.value
                      : 1.0,
                  child: CircleAvatar(
                    radius: 80,
                    backgroundColor: Helpers.getColorFromId(
                      widget.call.receiverName ?? widget.call.receiverId,
                    ),
                    child: Text(
                      Helpers.getInitials(
                        widget.call.receiverName ?? widget.call.receiverId,
                      ),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              widget.call.receiverName ?? widget.call.receiverId,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getStatusText(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            if (_callDuration > 0) ...[
              const SizedBox(height: 8),
              Text(
                _formatDuration(_callDuration),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.call.type == CallType.video
                      ? Icons.videocam
                      : Icons.call,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.call.type == CallType.video ? 'Video' : 'Audio',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          if (_isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Encrypted',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (widget.isIncoming)
            _buildControlButton(
              icon: Icons.call_end,
              backgroundColor: Colors.red,
              size: 64,
              onPressed: _declineCall,
            ),
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            isActive: _isMuted,
            onPressed: _toggleMute,
          ),
          if (widget.call.type == CallType.video)
            _buildControlButton(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              isActive: !_isVideoEnabled,
              onPressed: _toggleVideo,
            ),
          _buildControlButton(
            icon: Icons.call_end,
            backgroundColor: Colors.red,
            size: 64,
            onPressed: _endCall,
          ),
          _buildControlButton(
            icon: _isSpeakerEnabled ? Icons.volume_up : Icons.volume_down,
            isActive: _isSpeakerEnabled,
            onPressed: _toggleSpeaker,
          ),
          if (widget.call.type == CallType.video)
            _buildControlButton(
              icon: Icons.switch_camera,
              onPressed: _switchCamera,
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
    Color? backgroundColor,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ??
              (isActive
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.5)),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.4,
        ),
      ),
    );
  }

  Widget _buildLocalVideoPreview() {
    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        width: 120,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: RTCVideoView(
            _localRenderer,
            mirror: true,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (_callStatus) {
      case CallStatus.outgoing:
        return 'Calling...';
      case CallStatus.incoming:
        return 'Incoming call';
      case CallStatus.connecting:
        return 'Connecting...';
      case CallStatus.connected:
        return 'Connected';
      case CallStatus.ended:
        return 'Call ended';
      case CallStatus.declined:
        return 'Call declined';
      case CallStatus.failed:
        return 'Call failed';
      default:
        return '';
    }
  }
}
