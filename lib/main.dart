import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';

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

    List<int> bytes = [];
    bytes.addAll("POS Store\n".codeUnits);
    bytes.addAll("NO:12345678\nTel:(02)2299-1599\n\n".codeUnits);
    bytes
        .addAll("                                2013-01-01 13:33\n".codeUnits);
    bytes.addAll("Store No:0001                  ECR No:0001\n".codeUnits);
    bytes.addAll("Cashier No:0001                Vou No:0003\n\n".codeUnits);
    bytes.addAll("Grilled Onion Cheese Burger        \$4.0 TX\n".codeUnits);
    bytes.addAll("Mac Chicken meal                   \$2.0 TX\n".codeUnits);
    bytes.addAll("Red tea                            \$3.0 TX\n".codeUnits);
    bytes.addAll("Veggie                             \$3.0 TX\n".codeUnits);

    for (int i = 0; i < 41; i++) {
      bytes.addAll(
          "Vegetable juice ${i + 1}                 \$1.0 TX\n".codeUnits);
    }

    bytes.addAll("\n".codeUnits);
    bytes.addAll("Total:                        \$53.0 dollar\n".codeUnits);

    // Add the paper cut command
    bytes.addAll([0x1D, 0x56, 0x41, 0x10]);

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
