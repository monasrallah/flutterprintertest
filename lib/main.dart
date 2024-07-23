import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usb_serial/usb_serial.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('USB Printer Example'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              List<UsbDevice> devices = await UsbSerial.listDevices();
              print(devices);

              UsbPort port;
              if (devices.isEmpty) {
                return;
              }
              port = (await devices[0].create())!;

              bool openResult = await port.open();
              if (!openResult) {
                print("Failed to open");
                return;
              }

              await port.setDTR(true);
              await port.setRTS(true);

              port.setPortParameters(001, UsbPort.DATABITS_8,
                  UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

              // print first result and close port.
              port.inputStream?.listen((Uint8List event) {
                print(event);
                port.close();
              });

              await port.write(Uint8List.fromList([0x001, 0x003]));
            },
            child: const Text('Print'),
          ),
        ),
      ),
    );
  }
}

class UsbPrinter {
  static const MethodChannel _channel = MethodChannel('usb_printer');

  static Future<String?> printText(String text) async {
    final String? result =
        await _channel.invokeMethod('printText', {'data': text});
    return result;
  }
}
