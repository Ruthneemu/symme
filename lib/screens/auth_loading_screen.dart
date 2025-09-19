import 'package:flutter/material.dart';
import 'package:symme/screens/home_screen.dart';
import 'package:symme/services/call_manager.dart';
import 'package:symme/services/firebase_auth_service.dart';
import 'package:symme/utils/colors.dart';
import 'package:symme/utils/helpers.dart';

class AuthLoadingScreen extends StatefulWidget {
  const AuthLoadingScreen({super.key});

  @override
  State<AuthLoadingScreen> createState() => _AuthLoadingScreenState();
}

class _AuthLoadingScreenState extends State<AuthLoadingScreen> {
  String _status = 'Ready to begin';
  double _progress = 0.0;
  bool _isSettingUp = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _updateProgress(String status, double progress) async {
    if (mounted) {
      setState(() {
        _status = status;
        _progress = progress;
      });
    }
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _initializeApp() async {
    try {
      await _updateProgress('Initializing...', 0.1);

      final currentUser = FirebaseAuthService.getCurrentUser();
      await _updateProgress('Checking for existing session...', 0.4);

      if (currentUser == null) {
        await _updateProgress('Creating secure account...', 0.6);
        final user = await FirebaseAuthService.signInAnonymously();
        if (user == null) {
          throw Exception('Failed to create an anonymous account.');
        }
      }

      await _updateProgress('Verifying account...', 0.8);

      await _updateProgress('Setting up calling service...', 0.9);
      await CallManager.instance.initialize(context);

      await _updateProgress('Finalizing setup...', 1.0);
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Failed to set up account. Please restart the app.';
          _progress = 0.0;
          _isSettingUp = false;
        });
        Helpers.showSnackBar(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: _isSettingUp ? _buildProgressView() : _buildWelcomeView(),
        ),
      ),
    );
  }

  Widget _buildWelcomeView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.security_rounded,
          size: 100,
          color: AppColors.primaryCyan,
        ),
        const SizedBox(height: 24),
        const Text(
          'Welcome to Symme',
          style: TextStyle(
            color: AppColors.primaryCyan,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'A secure and private messaging app where your conversations are always end-to-end encrypted.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonPrimary,
            foregroundColor: AppColors.textOnPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: () {
            setState(() {
              _isSettingUp = true;
            });
            _initializeApp();
          },
          child: const Text('Setup Secure Account'),
        ),
      ],
    );
  }

  Widget _buildProgressView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${(_progress * 100).toInt()}%',
          style: const TextStyle(
            color: AppColors.primaryCyan,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: _progress,
          backgroundColor: AppColors.surfaceCard,
          valueColor: const AlwaysStoppedAnimation<Color>(
            AppColors.primaryCyan,
          ),
          minHeight: 6,
        ),
        const SizedBox(height: 20),
        Text(
          _status,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
