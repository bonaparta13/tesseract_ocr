// part of flutter_tesseract_ocr;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class FlutterTesseractOcr {
  static const String TESS_DATA_CONFIG = 'assets/tessdata_config.json';
  static const String TESS_DATA_PATH = 'assets/tessdata';
  static const MethodChannel _channel = const MethodChannel(
    'flutter_tesseract_ocr',
  );

  /// image to  text
  ///```
  /// String _ocrText = await FlutterTesseractOcr.extractText(url, language: langs, args: {
  ///    "preserve_interword_spaces": "1",});
  ///```
  ///
  /// If assets are bundled in a different package (e.g. a plugin), pass
  /// [package] so the rootBundle keys use the `packages/<name>/` prefix.
  static Future<String> extractText(
    String imagePath, {
    String? language,
    Map? args,
    String? package,
  }) async {
    assert(await File(imagePath).exists(), true);
    final String tessData = await _loadTessData(package: package);
    final String extractText = await _channel.invokeMethod(
      'extractText',
      <String, dynamic>{
        'imagePath': imagePath,
        'tessData': tessData,
        'language': language,
        'args': args,
      },
    );
    return extractText;
  }

  /// image to  html text(hocr)
  ///```
  /// String _ocrHocr = await FlutterTesseractOcr.extractText(url, language: langs, args: {
  ///    "preserve_interword_spaces": "1",});
  ///```
  static Future<String> extractHocr(
    String imagePath, {
    String? language,
    Map? args,
    String? package,
  }) async {
    assert(await File(imagePath).exists(), true);
    final String tessData = await _loadTessData(package: package);
    final String extractText = await _channel.invokeMethod(
      'extractHocr',
      <String, dynamic>{
        'imagePath': imagePath,
        'tessData': tessData,
        'language': language,
        'args': args,
      },
    );
    return extractText;
  }

  /// getTessdataPath
  ///```
  /// print(await FlutterTesseractOcr.getTessdataPath())
  ///```
  static Future<String> getTessdataPath() async {
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String tessdataDirectory = join(appDirectory.path, 'tessdata');
    return tessdataDirectory;
  }

  static Future<String> _loadTessData({String? package}) async {
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String tessdataDirectory = join(appDirectory.path, 'tessdata');

    if (!await Directory(tessdataDirectory).exists()) {
      await Directory(tessdataDirectory).create();
    }
    await _copyTessDataToAppDocumentsDirectory(
      tessdataDirectory,
      package: package,
    );
    return appDirectory.path;
  }

  static Future _copyTessDataToAppDocumentsDirectory(
    String tessdataDirectory, {
    String? package,
  }) async {
    final String configKey = package != null
        ? 'packages/$package/$TESS_DATA_CONFIG'
        : TESS_DATA_CONFIG;
    final String dataPathKey = package != null
        ? 'packages/$package/$TESS_DATA_PATH'
        : TESS_DATA_PATH;

    final String config = await rootBundle.loadString(configKey);
    Map<String, dynamic> files = jsonDecode(config);
    for (var file in files["files"]) {
      if (!await File('$tessdataDirectory/$file').exists()) {
        final ByteData data = await rootBundle.load('$dataPathKey/$file');
        final Uint8List bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File('$tessdataDirectory/$file').writeAsBytes(bytes);
      }
    }
  }
}
