import Flutter
import UIKit
import SwiftyTesseract

/// Custom data source that points SwiftyTesseract to the app's Documents directory
/// instead of Bundle.main (which is read-only on iOS).
struct DocumentsTessDataSource: LanguageModelDataSource {
    let pathToTrainedData: String
}

public class SwiftFlutterTesseractOcrPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_tesseract_ocr", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterTesseractOcrPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "extractText" {

            guard let args = call.arguments else {
                result("iOS could not recognize flutter arguments in method: (sendParams)")
                return
            }

            let params: [String : Any] = args as! [String : Any]
            let language: String? = params["language"] as? String
            let tessDataPath: String? = params["tessData"] as? String
            let ocrArgs: [String: String]? = params["args"] as? [String: String]

            let dataSource: LanguageModelDataSource
            if let tessDataPath = tessDataPath {
                let tessdataPath = (tessDataPath as NSString).appendingPathComponent("tessdata")
                dataSource = DocumentsTessDataSource(pathToTrainedData: tessdataPath)
            } else {
                dataSource = Bundle.main
            }

            var swiftyTesseract: SwiftyTesseract
            if let language = language {
                swiftyTesseract = SwiftyTesseract(language: .custom(language), dataSource: dataSource)
            } else {
                swiftyTesseract = SwiftyTesseract(language: .english, dataSource: dataSource)
            }

            // Apply OCR args (whitelist, preserve_interword_spaces, etc.)
            if let ocrArgs = ocrArgs {
                if let whitelist = ocrArgs["tessedit_char_whitelist"] {
                    swiftyTesseract.whiteList = whitelist
                }
                if let blacklist = ocrArgs["tessedit_char_blacklist"] {
                    swiftyTesseract.blackList = blacklist
                }
                if let preserveSpaces = ocrArgs["preserve_interword_spaces"] {
                    swiftyTesseract.preserveInterwordSpaces = (preserveSpaces == "1")
                }
                if let minHeight = ocrArgs["textord_min_xheight"], let val = Int(minHeight) {
                    swiftyTesseract.minimumCharacterHeight = val
                }
            }

            let imagePath = params["imagePath"] as! String
            guard let image = UIImage(contentsOfFile: imagePath) else { return }

            swiftyTesseract.performOCR(on: image) { recognizedString in
                guard let extractText = recognizedString else { return }
                result(extractText)
            }
        }
    }
}
