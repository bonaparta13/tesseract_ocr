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

            let dataSource: LanguageModelDataSource
            if let tessDataPath = tessDataPath {
                // Use the documents directory path passed from Dart
                dataSource = DocumentsTessDataSource(pathToTrainedData: tessDataPath)
            } else {
                dataSource = Bundle.main
            }

            var swiftyTesseract: SwiftyTesseract
            if let language = language {
                swiftyTesseract = SwiftyTesseract(language: .custom(language), dataSource: dataSource)
            } else {
                swiftyTesseract = SwiftyTesseract(language: .english, dataSource: dataSource)
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
