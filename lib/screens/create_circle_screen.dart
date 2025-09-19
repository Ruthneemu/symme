import 'package:flutter/material.dart';
import 'package:symme/services/firebase_circle_service.dart';
import 'package:symme/utils/colors.dart';
import 'package:symme/utils/helpers.dart';

class CreateCircleScreen extends StatefulWidget {
  final String userSecureId;
  const CreateCircleScreen({super.key, required this.userSecureId});

  @override
  _CreateCircleScreenState createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final _circleNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createCircle() async {
    if (_circleNameController.text.isEmpty) {
      Helpers.showSnackBar(context, 'Please enter a name for your circle.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseCircleService.createCircle(
        _circleNameController.text,
        widget.userSecureId,
      );
      Helpers.showSnackBar(context, 'Circle created successfully!');
      Navigator.of(context).pop();
    } catch (e) {
      Helpers.showSnackBar(context, 'Failed to create circle: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a new Circle'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient:
                AppGradients.appBarGradient, // 👈 gradient instead of solid
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.backgroundMain, // 👈 adaptive background
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _circleNameController,
              decoration: InputDecoration(
                labelText: 'Circle Name',
                labelStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator(color: theme.colorScheme.primary)
                : ElevatedButton(
                    onPressed: _createCircle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Create Circle'),
                  ),
          ],
        ),
      ),
    );
  }
}
