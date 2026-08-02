import Foundation
import Vision
import CoreImage

let args = CommandLine.arguments.dropFirst()
for path in args {
    guard let img = CIImage(contentsOf: URL(fileURLWithPath: path)) else {
        print("\(path)\tLOAD_FAIL"); continue
    }
    let request = VNDetectBarcodesRequest()
    let handler = VNImageRequestHandler(ciImage: img, options: [:])
    do {
        try handler.perform([request])
        let results = request.results ?? []
        if results.isEmpty { print("\(path)\tNO_CODE") }
        for r in results {
            let sym = r.symbology.rawValue.replacingOccurrences(of: "VNBarcodeSymbology", with: "")
            print("\(path)\t\(sym)\t\(r.payloadStringValue ?? "<nil>")")
        }
    } catch {
        print("\(path)\tERROR \(error)")
    }
}
