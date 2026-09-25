// Optional macOS Vision review for ellipsized text in native widget contact sheets.
// Heuristic only: review the flagged images and keep the pixel-bounds test separate.
// Run: swift scripts/review-widget-text.swift /absolute/path/to/locale-matrix
import Foundation
import Vision
let folder = URL(fileURLWithPath: CommandLine.arguments[1])
var flags = [[String: String]]()
var checked = 0
for url in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter({ $0.pathExtension == "png" }).sorted(by: { $0.path < $1.path }) {
    let language: String
    if url.lastPathComponent.hasPrefix("zh_") { language = "zh-Hans" }
    else if url.lastPathComponent.hasPrefix("ja_") { language = "ja-JP" }
    else if url.lastPathComponent.hasPrefix("ko_") { language = "ko-KR" }
    else if url.lastPathComponent.hasPrefix("ru_") { language = "ru-RU" }
    else if url.lastPathComponent.hasPrefix("fr_") { language = "fr-FR" }
    else if url.lastPathComponent.hasPrefix("es_") { language = "es-ES" }
    else if url.lastPathComponent.hasPrefix("pt_") { language = "pt-BR" }
    else { language = "en-US" }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = [language, "en-US"]
    request.usesLanguageCorrection = false
    do {
        try VNImageRequestHandler(url: url).perform([request])
        checked += 1
        for line in request.results ?? [] {
            guard let text = line.topCandidates(1).first?.string else { continue }
            if text.contains("…") || text.contains("...") { flags.append(["image": url.lastPathComponent, "text": text]) }
        }
    } catch { flags.append(["image": url.lastPathComponent, "error": String(describing: error)]) }
}
let data = try JSONSerialization.data(withJSONObject: ["imagesChecked": checked, "flags": flags], options: [.prettyPrinted, .sortedKeys])
try data.write(to: folder.appendingPathComponent("ocr-review.json"))
print(String(data: data, encoding: .utf8)!)
