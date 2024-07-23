import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PrinterSelectionScreen(),
    );
  }
}

class PrinterSelectionScreen extends StatefulWidget {
  @override
  _PrinterSelectionScreenState createState() => _PrinterSelectionScreenState();
}

class _PrinterSelectionScreenState extends State<PrinterSelectionScreen> {
  List<UsbDevice> devices = [];
  UsbDevice? selectedDevice;

  @override
  void initState() {
    super.initState();
    _listDevices();
  }

  Future<void> _listDevices() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    setState(() {
      this.devices = devices;
    });
  }

  Future<void> _printText(UsbDevice device) async {
    UsbPort? port = await device.create();
    if (port == null) {
      print("Failed to create port");
      return;
    }

    bool openResult = await port.open();
    if (!openResult) {
      print("Failed to open port");
      return;
    }

    await port.setDTR(true);
    await port.setRTS(true);

    port.setPortParameters(9600, UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    port.inputStream?.listen((Uint8List event) {
      print(event);
      port.close();
    });

    String text = "Hello, USB Printer!";
    List<int> bytes = text.codeUnits;
    await port.write(Uint8List.fromList(bytes));
    await port.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('USB Printer Selection'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButton<UsbDevice>(
              hint: Text("Select a printer"),
              value: selectedDevice,
              onChanged: (UsbDevice? newValue) {
                setState(() {
                  selectedDevice = newValue;
                });
              },
              items: devices.map((UsbDevice device) {
                return DropdownMenuItem<UsbDevice>(
                  value: device,
                  child: Text(device.productName ?? 'Unknown Device'),
                );
              }).toList(),
            ),
            ElevatedButton(
              onPressed: selectedDevice == null
                  ? null
                  : () => _printText(selectedDevice!),
              child: const Text('Print'),
            ),
          ],
        ),
      ),
    );
  }
}
