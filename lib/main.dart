import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as mlkit;
import 'package:pdfx/pdfx.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
      home: QrFromPdfPage(fileName: 'test_qr_codes.pdf'),
    );
  }
}

class QrFromPdfPage extends StatefulWidget {
  final String fileName;

  const QrFromPdfPage({Key? key, required this.fileName}) : super(key: key);

  @override
  _QrFromPdfPageState createState() => _QrFromPdfPageState();
}

class _QrFromPdfPageState extends State<QrFromPdfPage> {
  List<String> foundQrCodes = [];
  bool isLoading = false;

  Future<void> loadAndFindAllQrCodes() async {
    setState(() {
      isLoading = true;
      foundQrCodes.clear();
    });

    final doc = await PdfDocument.openAsset('assets/${widget.fileName}');

    for (int i = 1; i <= doc.pagesCount; i++) {
      final page = await doc.getPage(i);
      final pageImage =
          await page.render(width: (page.width * 2), height: (page.height * 2));
      final imgBytes = pageImage!.bytes;

      if (kIsWeb) {
        final int width = (page.width * 2).round();
        final int height = (page.height * 2).round();
        final pixels = Int32List(width * height);
        final int pixelCount = imgBytes.length ~/ 4;
        final int minLength = pixelCount.clamp(0, width * height);

        for (int index = 0; index < minLength; index++) {
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
            foundQrCodes.add(result.text);
            print('Found QR on page $i: ${result.text}');
          }
        } catch (e) {
          // No QR found on this page
        }
      } else {
        final inputImage = mlkit.InputImage.fromBytes(
          bytes: imgBytes,
          metadata: mlkit.InputImageMetadata(
            size: Size((page.width * 2), (page.height * 2)),
            rotation: mlkit.InputImageRotation.rotation0deg,
            format: mlkit.InputImageFormat.bgra8888,
            bytesPerRow: ((page.width * 2).round()) * 4,
          ),
        );

        final barcodeScanner =
            mlkit.BarcodeScanner(formats: [mlkit.BarcodeFormat.qrCode]);
        final barcodes = await barcodeScanner.processImage(inputImage);
        for (var barcode in barcodes) {
          if (barcode.rawValue != null) {
            foundQrCodes.add(barcode.rawValue!);
            print('Found QR on page $i: ${barcode.rawValue!}');
          }
        }
      }

      await page.close();
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
        title: Text('QR from PDF - ${widget.fileName}'),
      ),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : foundQrCodes.isEmpty
                ? Text('No QR codes found.')
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: foundQrCodes.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          QrImageView(
                            data: foundQrCodes[index],
                            version: QrVersions.auto,
                            size: 150.0,
                          ),
                          SizedBox(height: 8),
                          Text(foundQrCodes[index]),
                          Divider(),
                        ],
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: loadAndFindAllQrCodes,
        child: Icon(Icons.qr_code_scanner),
      ),
    );
  }
}
