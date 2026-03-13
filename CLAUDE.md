# Instructions for Forked flutter_tesseract_ocr

## Context

This document provides instructions for a new Claude Code session in the forked `flutter_tesseract_ocr` repository. The goal is to fix two critical issues that force end users of plugins (like `mrz_scanner`) to do manual asset setup.

## Parent Project

- **Repository**: `/Users/anas/Documents/GitHub/mrz_scanner`
- **What it does**: Flutter plugin for scanning MRZ (Machine Readable Zone) from passports/IDs using Tesseract OCR
- **Dependency**: Uses `flutter_tesseract_ocr` for OCR functionality
- **Assets**: Has `assets/tessdata_config.json` and `assets/tessdata/eng.traineddata` (3.9MB) declared in its `pubspec.yaml`

## The Two Problems

### Problem 1: Dart Asset Loading Uses Root Bundle Keys Without Package Prefix

**File**: `lib/android_ios.dart`

The package loads assets using hardcoded root-level keys:
```dart
static const String TESS_DATA_CONFIG = 'assets/tessdata_config.json';
static const String TESS_DATA_PATH = 'assets/tessdata';
```

And loads them via:
```dart
final String config = await rootBundle.loadString(TESS_DATA_CONFIG);
// and
final data = await rootBundle.load('assets/tessdata/$file');
```

**The issue**: When a Flutter plugin (like `mrz_scanner`) declares assets in its own `pubspec.yaml`, those assets are available in the host app's `rootBundle` under the key `packages/<plugin_name>/<asset_path>`. For example:
- `mrz_scanner` declares `assets/tessdata_config.json` in its pubspec
- In the host app, this is accessible as `packages/mrz_scanner/assets/tessdata_config.json`
- But `flutter_tesseract_ocr` looks for `assets/tessdata_config.json` (without prefix) — NOT FOUND

**Current workaround**: Users must manually copy tessdata files into their own app's `assets/` folder and declare them in their `pubspec.yaml`. This is bad UX.

### Problem 2: iOS Creates Symlink in Read-Only Bundle (Permission Error)

**File**: `ios/Classes/SwiftFlutterTesseractOcrPlugin.swift`

The iOS code tries to create a symbolic link inside `Bundle.main`:
```swift
let sourceURL = Bundle.main.bundleURL.appendingPathComponent("tessdata")
let destURL = documentsURL!.appendingPathComponent("tessdata")
try fileManager.createSymbolicLink(at: sourceURL, withDestinationURL: destURL)
```

**The issue**: `Bundle.main` is **read-only** on iOS. Creating a symlink there fails with:
```
Error Domain=NSCocoaErrorDomain Code=513 "You don't have permission to save the file "tessdata" in the folder..."
```

This forces users to manually add the `tessdata` folder as an Xcode folder reference in their iOS project — terrible DX.

## Required Changes

### Change 1: Add `package` Parameter to Dart API

In `lib/android_ios.dart`:

1. Add an optional `package` parameter to `extractText()` and any other public methods that trigger asset loading.

2. When `package` is provided, prefix asset keys with `packages/$package/`:
   ```dart
   // Before:
   rootBundle.loadString('assets/tessdata_config.json')
   rootBundle.load('assets/tessdata/$file')

   // After (when package is provided):
   rootBundle.loadString('packages/$package/assets/tessdata_config.json')
   rootBundle.load('packages/$package/assets/tessdata/$file')
   ```

3. When `package` is null, keep the current behavior (backward compatible).

**Usage from mrz_scanner**:
```dart
FlutterTesseractOcr.extractText(imagePath, args: _ocrArgs, package: 'mrz_scanner');
```

This way, `mrz_scanner` declares the assets in its own `pubspec.yaml`, and `flutter_tesseract_ocr` loads them with the correct `packages/mrz_scanner/` prefix. End users just add `mrz_scanner` to their pubspec — no manual asset setup.

### Change 2: Fix iOS Tessdata Initialization

In `ios/Classes/SwiftFlutterTesseractOcrPlugin.swift`:

1. **Remove the symlink approach entirely** — it doesn't work because Bundle.main is read-only.

2. **Instead**: The Dart side already copies tessdata files to `Documents/tessdata/`. SwiftyTesseract should be initialized with the documents directory path, not Bundle.main.

3. SwiftyTesseract supports a custom `RecognitionLanguage` and `dataSource`. Modify the initialization to use a custom `LanguageModelDataSource` that points to the documents directory:
   ```swift
   // Instead of using Bundle.main, create a custom data source
   // that points to the app's documents directory
   let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
   // Use documentsPath as the tessdata parent directory
   ```

4. Alternatively, pass the tessdata path from Dart to Swift via the method channel and use it directly when initializing TessBaseAPI/SwiftyTesseract.

5. The Android side (`FlutterTesseractOcrPlugin.java`) already receives the path from Dart and works correctly — no changes needed there.

## File Structure of flutter_tesseract_ocr

```
lib/
  android_ios.dart          ← Main Dart file, asset loading + method channel calls
  flutter_tesseract_ocr.dart ← Barrel/export file
ios/
  Classes/
    SwiftFlutterTesseractOcrPlugin.swift  ← iOS native, symlink issue
    FlutterTesseractOcrPlugin.h
    FlutterTesseractOcrPlugin.m
android/
  src/main/java/io/paratoner/flutter_tesseract_ocr/
    FlutterTesseractOcrPlugin.java  ← Android native (works fine)
```

## Key Constants in android_ios.dart

```dart
static const String TESS_DATA_CONFIG = 'assets/tessdata_config.json';
static const String TESS_DATA_PATH = 'assets/tessdata';
```

The `_loadTessData()` method:
1. Gets documents directory
2. Creates `tessdata` subdirectory
3. Calls `_copyTessDataToAppDocumentsDirectory()` which loads config JSON, then copies each listed file from rootBundle to documents

The `extractText()` method:
1. Calls `_loadTessData()` to ensure files are copied
2. Calls the platform channel with the documents path and other args
3. Returns the recognized text

## After Forking: Changes Needed in mrz_scanner

Once the fork is ready, `mrz_scanner` needs these updates:

1. **pubspec.yaml**: Change dependency from pub.dev to git:
   ```yaml
   dependencies:
     flutter_tesseract_ocr:
       git:
         url: https://github.com/<your-username>/flutter_tesseract_ocr.git
   ```

2. **lib/src/ocr_service.dart**: Pass `package: 'mrz_scanner'` to extractText:
   ```dart
   static Future<String> extractText(String imagePath) {
     return FlutterTesseractOcr.extractText(imagePath, args: _ocrArgs, package: 'mrz_scanner');
   }
   ```

3. **example/pubspec.yaml**: Remove the manual `assets:` section (no longer needed)

4. **example/ios/Runner/tessdata/**: Delete (no longer needed)

5. **example/assets/**: Delete (no longer needed)

6. **README.md**: Remove the "copy assets" installation step — just add the dependency and platform permissions

## Testing

After making changes, test with the mrz_scanner example app:
1. Remove all manual asset declarations from example/pubspec.yaml
2. Remove tessdata from example/ios/Runner/
3. Remove example/assets/ folder
4. Run on iOS device — should OCR without permission errors
5. Run on Android device — should OCR without missing asset errors
6. Test both camera scanning and gallery image scanning
