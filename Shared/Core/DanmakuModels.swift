import SwiftUI

struct DanmakuSegmentResponse: Decodable {
    let elems: [DanmakuElem]?
    let state: Int64?
}

struct DanmakuElem: Decodable {
    let id: Int64?
    let idStr: String?
    let progress: Int64?
    let mode: Int64?
    let fontsize: Int64?
    let color: Int64?
    let content: String?

    enum CodingKeys: String, CodingKey {
        case id
        case idStr = "id_str"
        case progress
        case mode
        case fontsize
        case color
        case content
    }
}

struct DanmakuItem: Identifiable, Hashable {
    let id: String
    let start: Double
    let mode: Int
    let text: String
    let colorValue: UInt32
    let fontSize: Double
    /// Text advance in em units, so rendering can size a line without measuring it every frame.
    let widthUnits: Double
    let laneSeed: Int
    var lane: Int

    init?(elem: DanmakuElem) {
        guard let content = elem.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty,
              let progress = elem.progress,
              progress >= 0 else {
            return nil
        }
        let mode = Int(elem.mode ?? 1)
        guard mode == 1 || mode == 4 || mode == 5 else { return nil }
        self.id = elem.idStr ?? String(elem.id ?? progress)
        start = Double(progress) / 1000
        self.mode = mode
        text = content
        colorValue = UInt32(truncatingIfNeeded: elem.color ?? 0xFFFFFF) & 0xFFFFFF
        fontSize = min(max(Double(elem.fontsize ?? 25), 12), 40)
        widthUnits = Self.measureWidthUnits(content)
        laneSeed = Int((elem.id ?? progress) % 16)
        lane = 0
    }

    init(id: String, start: Double, mode: Int, text: String, colorValue: UInt32 = 0xFFFFFF, fontSize: Double = 25) {
        self.id = id
        self.start = start
        self.mode = mode
        self.text = text
        self.colorValue = colorValue
        self.fontSize = fontSize
        widthUnits = Self.measureWidthUnits(text)
        laneSeed = Int(abs(id.hashValue) % 16)
        lane = 0
    }

    private static func measureWidthUnits(_ text: String) -> Double {
        var units = 0.0
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x20:
                units += 0.35
            case 0x21...0x7E:
                units += 0.58
            case 0x2E80...0x9FFF, 0xAC00...0xD7AF, 0xF900...0xFAFF, 0xFE30...0xFE4F, 0xFF00...0xFFEF:
                units += 1.0
            default:
                units += 0.85
            }
        }
        return max(units, 2)
    }

    var color: Color {
        Color(
            red: Double((colorValue >> 16) & 0xFF) / 255,
            green: Double((colorValue >> 8) & 0xFF) / 255,
            blue: Double(colorValue & 0xFF) / 255
        )
    }
}
