import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrVentaScreen extends StatefulWidget {
  const QrVentaScreen({super.key});

  @override
  State<QrVentaScreen> createState() => _QrVentaScreenState();
}

class _QrVentaScreenState extends State<QrVentaScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _procesando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _manejarDeteccion(BarcodeCapture capture) {
    if (_procesando) return;

    final codigo = capture.barcodes
        .map((item) => item.rawValue)
        .whereType<String>()
        .firstWhere(
          (item) => item.trim().isNotEmpty,
          orElse: () => '',
        );

    if (codigo.isEmpty) return;

    _procesando = true;
    Navigator.pop(context, codigo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Escanear QR del punto'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _manejarDeteccion,
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Apunta al QR del punto de compra para registrar kilos, dinero ganado y puntos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
