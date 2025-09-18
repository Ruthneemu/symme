import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeScreen extends StatefulWidget {
  // If you provide a publicId, it will be displayed.
  final String? publicId;
  // If true, the screen will open directly in scanning mode.
  final bool startInScanMode;

  const QrCodeScreen({
    super.key,
    this.publicId,
    this.startInScanMode = false,
  });

  @override
  _QrCodeScreenState createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  late bool _isScanning;

  @override
  void initState() {
    super.initState();
    // If publicId is null, we MUST be scanning.
    _isScanning = widget.startInScanMode || widget.publicId == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isScanning ? 'Scan QR Code' : 'My Secure ID'),
      ),
      body: _isScanning ? _buildScanner() : _buildQrCodeDisplay(),
    );
  }

  Widget _buildQrCodeDisplay() {
    final theme = Theme.of(context);

    if (widget.publicId == null) {
      return Center(
        child: Text(
          'No Secure ID to display.',
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Share this Secure ID',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: widget.publicId!,
              version: QrVersions.auto,
              size: 250.0,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.publicId!,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () => setState(() => _isScanning = true),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Another ID'),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    final theme = Theme.of(context);
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final String? code = barcodes.first.rawValue;
              if (code != null) {
                // Pop with the scanned code as the result
                Navigator.of(context).pop(code);
              }
            }
          },
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary, width: 4),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        // If we didn't start in scan mode, show a button to go back to display mode.
        if (!widget.startInScanMode && widget.publicId != null)
          Positioned(
            top: 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => setState(() => _isScanning = false),
            ),
          ),
      ],
    );
  }
}
