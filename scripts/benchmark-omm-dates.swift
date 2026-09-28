import Foundation
let values = Array(repeating: "2026-09-15T00:00:00.123456Z", count: 1000)
let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
for variant in 0..<2 {
    var total = 0.0
    for _ in 0..<5 {
        let start = Date()
        for value in values {
            if variant == 0 {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                precondition(f.date(from: value) != nil)
            } else { _ = try fractional.parse(value) }
        }
        total += Date().timeIntervalSince(start)
    }
    print(variant == 0 ? "per-record formatter" : "ISO8601FormatStyle", total / 5 * 1000, "ms / 1000 epochs")
}
