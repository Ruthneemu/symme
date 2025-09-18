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
      final circleId = await FirebaseCircleService.createCircle(
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a new Circle'),
        backgroundColor: AppColors.backgroundDark,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _circleNameController,
              decoration: const InputDecoration(
                labelText: 'Circle Name',
                labelStyle: TextStyle(color: AppColors.greyLight),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.greyLight),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator(color: AppColors.primary)
                : ElevatedButton(
                    onPressed: _createCircle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Create Circle',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
