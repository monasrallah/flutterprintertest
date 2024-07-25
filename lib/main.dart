import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: PrinterScreen(),
    );
  }
}

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  _PrinterScreenState createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  UsbDevice? targetPrinter;

  @override
  void initState() {
    super.initState();
    _listDevices();
  }

  Future<void> _listDevices() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    setState(() {
      targetPrinter = devices.firstWhere(
        (device) => device.productName == "PP-7600 Thermal Printer",
      );
    });
  }

  Future<img.Image?> _loadImageAsset(String path) async {
    final ByteData data = await rootBundle.load(path);
    final Uint8List bytes = data.buffer.asUint8List();
    return img.decodeImage(bytes);
  }

  Future<void> _printReceipt() async {
    if (targetPrinter == null) {
      _showSnackBar("PP-7600 Thermal Printer not found");
      return;
    }

    UsbPort? port = await targetPrinter!.create();
    if (port == null) {
      _showSnackBar("Failed to create port");
      return;
    }

    bool openResult = await port.open();
    if (!openResult) {
      _showSnackBar("Failed to open port");
      return;
    }

    await port.setDTR(true);
    await port.setRTS(true);

    port.setPortParameters(
        9600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    port.inputStream?.listen((Uint8List event) {
      _showSnackBar("Received data: $event");
      port.close();
    });

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    // Load and add logo
    final img.Image? logo = await _loadImageAsset('assets/logo.png');
    if (logo != null) {
      bytes += generator.imageRaster(logo, align: PosAlign.center);
    }

    bytes += generator.text('POS Store',
        styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2));
    bytes += generator.text('NO:12345678',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Tel:(02)2299-1599\n\n',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('                                2013-01-01 13:33');
    bytes += generator.text('Store No:0001                  ECR No:0001');
    bytes += generator.text('Cashier No:0001                Vou No:0003\n\n');
    bytes += generator.text('Grilled Onion Cheese Burger        \$4.0 TX');
    bytes += generator.text('Mac Chicken meal                   \$2.0 TX');
    bytes += generator.text('Red tea                            \$3.0 TX');
    bytes += generator.text('Veggie                             \$3.0 TX');

    for (int i = 0; i < 41; i++) {
      bytes +=
          generator.text('Vegetable juice ${i + 1}                 \$1.0 TX');
    }

    bytes += generator.text('\n');
    bytes += generator.text('Total:                        \$53.0 dollar');

    // Add QR code
    bytes += generator.qrcode('https://www.example.com', size: QRSize.Size4);

    // Add the paper cut command
    bytes += generator.cut();

    await port.write(Uint8List.fromList(bytes));
    await port.close();

    _showSnackBar("Receipt printed and paper cut successfully");
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('USB Printer Test'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _printReceipt,
          child: const Text('Print Receipt'),
        ),
      ),
    );
  }
}
