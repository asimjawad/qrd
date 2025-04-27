import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as mlkit;
import 'package:pdfx/pdfx.dart';
import 'package:zxing2/qrcode.dart' as zxing;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR from PDF',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: QrFromPdfPage(),
    );
  }
}

class QrFromPdfPage extends StatefulWidget {
  @override
  _QrFromPdfPageState createState() => _QrFromPdfPageState();
}

class _QrFromPdfPageState extends State<QrFromPdfPage> {
  String? foundQrCode;
  bool isLoading = false;

  Future<void> loadAndFindFirstQrCode() async {
    setState(() => isLoading = true);

    final doc = await PdfDocument.openAsset('assets/sample.pdf');

    for (int i = 1; i <= doc.pagesCount; i++) {
      final page = await doc.getPage(i);
      final pageImage =
          await page.render(width: page.width, height: page.height);
      final imgBytes = pageImage!.bytes;

      if (kIsWeb) {
        final int width = page.width.toInt();
        final int height = page.height.toInt();

        final pixels = Int32List(width * height);
        for (int index = 0; index < width * height; index++) {
          final byteOffset = index * 4;
          final b = imgBytes[byteOffset];
          final g = imgBytes[byteOffset + 1];
          final r = imgBytes[byteOffset + 2];
          final a = imgBytes[byteOffset + 3];

          pixels[index] = (a << 24) | (r << 16) | (g << 8) | b;
        }

        final zxing.LuminanceSource source =
            zxing.RGBLuminanceSource(width, height, pixels);
        final zxing.BinaryBitmap bitmap =
            zxing.BinaryBitmap(zxing.HybridBinarizer(source));
        final zxing.QRCodeReader reader = zxing.QRCodeReader();

        try {
          final result = reader.decode(bitmap);
          if (result.text.isNotEmpty) {
            foundQrCode = result.text;
            await page.close();
            break;
          }
        } catch (e) {
          // No QR found on this page
        }
      } else {
        final inputImage = mlkit.InputImage.fromBytes(
          bytes: imgBytes,
          metadata: mlkit.InputImageMetadata(
            size: Size(page.width.toDouble(), page.height.toDouble()),
            rotation: mlkit.InputImageRotation.rotation0deg,
            format: mlkit.InputImageFormat.bgra8888,
            bytesPerRow: page.width.toInt() * 4,
          ),
        );

        final barcodeScanner =
            mlkit.BarcodeScanner(formats: [mlkit.BarcodeFormat.qrCode]);
        final barcodes = await barcodeScanner.processImage(inputImage);
        for (var barcode in barcodes) {
          if (barcode.rawValue != null) {
            foundQrCode = barcode.rawValue!;
            await page.close();
            break;
          }
        }
      }

      await page.close();

      if (foundQrCode != null) break;
    }

    await doc.close();

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR from PDF'),
      ),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  foundQrCode == null
                      ? Text('No QR code found.')
                      : ListTile(
                          leading: Icon(Icons.qr_code),
                          title: Text(foundQrCode!),
                        ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: loadAndFindFirstQrCode,
                    child: Text('Scan PDF for QR Code'),
                  ),
                ],
              ),
      ),
    );
  }
}
