import Vision
import UIKit
import CoreImage

// MARK: - Data Models
struct IDCardInfo {
    var name: String = ""
    var gender: String = ""
    var ethnicity: String = ""
    var idNumber: String = ""
    var birthDate: String = ""
    var address: String = ""
    var expiry: String = ""
    var issuingAuthority: String = ""
}

struct BusinessLicenseInfo {
    var creditCode: String = ""
    var name: String = ""
    var type: String = ""
    var legalRepresentative: String = ""
    var registeredCapital: String = ""
    var establishDate: String = ""
    var address: String = ""
    var businessScope: String = ""
}

/// A recognized text block with its spatial position in the image.
struct TextBlock {
    let text: String
    let box: CGRect  // Normalized coordinates: (0,0)=bottom-left, (1,1)=top-right
    var centerX: CGFloat { box.origin.x + box.width / 2 }
    var centerY: CGFloat { box.origin.y + box.height / 2 }
    var minX: CGFloat { box.origin.x }
    var maxX: CGFloat { box.origin.x + box.width }
    var minY: CGFloat { box.origin.y }
    var maxY: CGFloat { box.origin.y + box.height }
}

// MARK: - OCR Engine
struct OCRHelper {

    // ── Image Preprocessing ──────────────────────────────────────────
    static func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return image }
        let ci = CIImage(cgImage: cg)
        guard let f = CIFilter(name: "CIColorControls") else { return image }
        f.setValue(ci, forKey: kCIInputImageKey); f.setValue(1.4, forKey: kCIInputContrastKey)
        f.setValue(0.0, forKey: kCIInputSaturationKey); f.setValue(0.08, forKey: kCIInputBrightnessKey)
        guard let out = f.outputImage else { return image }
        let ctx = CIContext(); guard let o = ctx.createCGImage(out, from: out.extent) else { return image }
        return UIImage(cgImage: o)
    }

    static func preprocessImageStrong(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return image }
        let ci = CIImage(cgImage: cg)
        guard let f = CIFilter(name: "CIColorControls") else { return image }
        f.setValue(ci, forKey: kCIInputImageKey); f.setValue(2.0, forKey: kCIInputContrastKey)
        f.setValue(0.0, forKey: kCIInputSaturationKey); f.setValue(0.12, forKey: kCIInputBrightnessKey)
        guard let mid = f.outputImage else { return image }
        guard let s = CIFilter(name: "CISharpenLuminance") else {
            let ctx = CIContext(); guard let o = ctx.createCGImage(mid, from: mid.extent) else { return image }; return UIImage(cgImage: o)
        }
        s.setValue(mid, forKey: kCIInputImageKey); s.setValue(0.6, forKey: kCIInputSharpnessKey)
        guard let out = s.outputImage else { let ctx = CIContext(); guard let o = ctx.createCGImage(mid, from: mid.extent) else { return image }; return UIImage(cgImage: o) }
        let ctx = CIContext(); guard let o = ctx.createCGImage(out, from: out.extent) else { return image }; return UIImage(cgImage: o)
    }

    // ── Vision Recognition: returns TextBlocks with positions ────────
    static func recognizeBlocksRaw(from image: UIImage, completion: @escaping ([TextBlock]) -> Void) {
        guard let cg = image.cgImage else { completion([]); return }
        let req = VNRecognizeTextRequest { r, _ in
            guard let obs = r.results as? [VNRecognizedTextObservation] else { completion([]); return }
            let blocks = obs.compactMap { o -> TextBlock? in
                guard let candidate = o.topCandidates(1).first else { return nil }
                return TextBlock(text: candidate.string, box: o.boundingBox)
            }
            completion(blocks)
        }
        req.recognitionLevel = .accurate
        req.recognitionLanguages = ["zh-Hans", "en"]
        req.usesLanguageCorrection = true
        req.customWords = [
            "居民身份证","中华人民共和国","签发机关","有效期限","长期",
            "营业执照","统一社会信用代码","法定代表人","经营者","注册资本",
            "成立日期","经营范围","住所","经营场所","个体工商户",
            "有限责任公司","股份有限公司","个人独资企业","合伙企业",
            "姓名","性别","民族","住址","公民身份号码","名称","类型",
            "岳阳","经济技术","开发区"
        ]
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
    }

    /// Try original → preprocessed → strong-preprocessed; return best blocks.
    static func recognizeBlocks(from image: UIImage, completion: @escaping ([TextBlock]) -> Void) {
        recognizeBlocksRaw(from: image) { blocks in
            if blocks.count >= 5 { completion(blocks); return }
            guard let p1 = preprocessImage(image) else { completion(blocks); return }
            recognizeBlocksRaw(from: p1) { b2 in
                if b2.count >= 5 { completion(b2); return }
                guard let p2 = preprocessImageStrong(image) else { completion(maxBlocks(blocks, b2)); return }
                recognizeBlocksRaw(from: p2) { b3 in completion(maxBlocks(blocks, maxBlocks(b2, b3))) }
            }
        }
    }

    /// Try with rotations, return best result.
    static func recognizeBlocksRobust(from image: UIImage, completion: @escaping ([TextBlock]) -> Void) {
        recognizeBlocks(from: image) { blocks in
            if blocks.count >= 8 { completion(blocks); return }
            tryAnglesBlocks(image, [90, 180, 270], 0, blocks, completion)
        }
    }

    private static func tryAnglesBlocks(_ img: UIImage, _ angles: [CGFloat], _ i: Int, _ best: [TextBlock], _ done: @escaping ([TextBlock]) -> Void) {
        guard i < angles.count else { done(best); return }
        guard let r = img.rotated(by: angles[i] * .pi / 180) else { tryAnglesBlocks(img, angles, i+1, best, done); return }
        recognizeBlocks(from: r) { blocks in
            let b = maxBlocks(best, blocks)
            if b.count >= 10 { done(b) } else { tryAnglesBlocks(img, angles, i+1, b, done) }
        }
    }

    // ── Legacy text-based recognition (kept for compatibility) ───────
    static func recognizeTextRaw(from image: UIImage, completion: @escaping (String?) -> Void) {
        recognizeBlocksRaw(from: image) { blocks in
            completion(blocks.map { $0.text }.joined(separator: "\n"))
        }
    }

    static func recognizeText(from image: UIImage, completion: @escaping (String?) -> Void) {
        recognizeBlocks(from: image) { blocks in
            let text = blocks.map { $0.text }.joined(separator: "\n")
            completion(text.isEmpty ? nil : text)
        }
    }

    static func recognizeTextRobust(from image: UIImage, completion: @escaping (String?) -> Void) {
        recognizeBlocksRobust(from: image) { blocks in
            let text = blocks.map { $0.text }.joined(separator: "\n")
            completion(text.isEmpty ? nil : text)
        }
    }

    // ── Helper functions ─────────────────────────────────────────────
    private static func maxBlocks(_ a: [TextBlock], _ b: [TextBlock]) -> [TextBlock] {
        a.count >= b.count ? a : b
    }

    static func validateIDChecksum(_ id: String) -> Bool {
        let c = id.uppercased(); guard c.count == 18 else { return false }
        let w = [7,9,10,5,8,4,2,1,6,3,7,9,10,5,8,4,2]
        let ck = ["1","0","X","9","8","7","6","5","4","3","2"]
        var s = 0
        for i in 0..<17 { let idx = c.index(c.startIndex, offsetBy: i); guard let n = Int(String(c[idx])) else { return false }; s += n * w[i] }
        return String(c[c.index(c.startIndex, offsetBy: 17)]) == ck[s % 11]
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - ID Card Front (身份证正面) — Spatial Analysis
    // ═══════════════════════════════════════════════════════════════════
    static func extractIDCardFront(from blocks: [TextBlock]) -> IDCardInfo {
        var info = IDCardInfo()
        let joined = blocks.map { $0.text }.joined(separator: " ")
        let raw = joined.replacingOccurrences(of: " ", with: "")

        // ID Number: 18-digit pattern (works well with text-based)
        if let id = findIDNumber(in: raw) { info.idNumber = id }

        // Gender: find block containing "男" or "女" near "性别" block
        if let genderBlock = blocks.first(where: { $0.text.contains("男") || $0.text.contains("女") }) {
            let text = genderBlock.text
            if text.contains("男") { info.gender = "男" }
            else if text.contains("女") { info.gender = "女" }
        }

        // Name: find block that is "姓名" label, then look for value block below/next to it
        info.name = extractIDNameFromBlocks(blocks, raw: raw)

        // Ethnicity: find "民族" label block, value is in same or adjacent block
        for block in blocks {
            if block.text.contains("民族") {
                let after = block.text.components(separatedBy: "民族").last ?? ""
                let cleaned = after.components(separatedBy: CharacterSet(charactersIn: " :：")).filter { !$0.isEmpty }.first ?? ""
                let cjk = cleaned.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
                if cjk.count >= 1 && cjk.count <= 5 { info.ethnicity = String(cjk.map { Character(UnicodeScalar($0)) }) }
            }
        }

        // Birth date
        let datePattern = "(?:19|20)\\d{2}[年.\\-/](?:0[1-9]|1[0-2])[月.\\-/](?:0[1-9]|[12]\\d|3[01])[日]?"
        if let regex = try? NSRegularExpression(pattern: datePattern),
           let m = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            info.birthDate = (raw as NSString).substring(with: m.range)
        }

        // Address: find "住址" block, value may be in same or next block(s)
        info.address = extractAddressFromBlocks(blocks, label: "住址", raw: raw)

        return info
    }

    // Legacy text-based API
    static func extractIDCardFront(from text: String) -> IDCardInfo {
        let raw = text.replacingOccurrences(of: " ", with: "")
        var info = IDCardInfo()
        if let id = findIDNumber(in: raw) { info.idNumber = id }
        info.name = extractIDNameFromText(raw)
        if let g = findGender(in: raw) { info.gender = g }
        if let e = findEthnicity(in: raw) { info.ethnicity = e }
        if let b = findBirthDate(in: raw) { info.birthDate = b }
        info.address = extractAddressFromText(raw, label: "住址")
        return info
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - ID Card Back (身份证背面)
    // ═══════════════════════════════════════════════════════════════════
    static func extractIDCardBack(from text: String) -> IDCardInfo {
        var info = IDCardInfo()
        let raw = text.replacingOccurrences(of: " ", with: "")
        // Validity period
        if let rx = try? NSRegularExpression(pattern: "(\\d{4}[.\\-/]\\d{2}[.\\-/]\\d{2})\\s*[-\u{2014}\u{2013}]\\s*(\\d{4}[.\\-/]\\d{2}[.\\-/]\\d{2}|长期)"),
           let m = rx.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)), m.numberOfRanges > 2 {
            info.expiry = "\((raw as NSString).substring(with: m.range(at: 1)))-\((raw as NSString).substring(with: m.range(at: 2)))"
        }
        if info.expiry.isEmpty {
            if let rx = try? NSRegularExpression(pattern: "\\d{4}[.\\-/]\\d{2}[.\\-/]\\d{2}") {
                let ms = rx.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
                if ms.count >= 2 { info.expiry = "\((raw as NSString).substring(with: ms[0].range))-\((raw as NSString).substring(with: ms[1].range))" }
            }
        }
        return info
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Business License (营业执照) — Spatial Analysis
    // ═══════════════════════════════════════════════════════════════════
    static func extractBusinessLicenseInfo(from blocks: [TextBlock]) -> BusinessLicenseInfo {
        var info = BusinessLicenseInfo()
        let joined = blocks.map { $0.text }.joined(separator: "\n")
        let raw = joined.replacingOccurrences(of: " ", with: "")

        // Credit code: 18-char alphanumeric pattern
        if let rx = try? NSRegularExpression(pattern: "[0-9A-HJ-NP-RTUW-Y]{2}\\d{6}[0-9A-HJ-NP-RTUW-Y]{10}"),
           let m = rx.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            info.creditCode = (raw as NSString).substring(with: m.range)
        }

        // ── Spatial field extraction ──
        // For each field, find the label block and extract the value from nearby blocks
        
        // Name: find block containing "称" (OCR may drop "名"), value is nearby
        info.name = extractBizNameFromBlocks(blocks, raw: raw, creditCode: info.creditCode)

        // Type: find "类型" block
        info.type = extractFieldAfterLabel(blocks, labels: ["类型"], raw: raw)

        // Legal representative: find "法定代表人" or "经营者" block
        info.legalRepresentative = extractFieldAfterLabel(blocks, labels: ["法定代表人", "经营者", "负责人"], raw: raw)

        // Address: find "住所" block
        info.address = extractBizAddressFromBlocks(blocks, raw: raw)

        // Registered capital
        info.registeredCapital = extractFieldAfterLabel(blocks, labels: ["注册资本"], raw: raw)

        // Establish date
        info.establishDate = extractFieldAfterLabel(blocks, labels: ["成立日期"], raw: raw)

        // Business scope
        info.businessScope = extractFieldAfterLabel(blocks, labels: ["经营范围"], raw: raw)

        return info
    }

    // Legacy text-based API
    static func extractBusinessLicenseInfo(from text: String) -> BusinessLicenseInfo {
        let raw = text.replacingOccurrences(of: " ", with: "")
        var info = BusinessLicenseInfo()
        if let rx = try? NSRegularExpression(pattern: "[0-9A-HJ-NP-RTUW-Y]{2}\\d{6}[0-9A-HJ-NP-RTUW-Y]{10}"),
           let m = rx.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            info.creditCode = (raw as NSString).substring(with: m.range)
        }
        info.name = extractBizNameFromText(raw, creditCode: info.creditCode)
        info.type = extractFieldFromText(raw, labels: ["类型"])
        info.legalRepresentative = extractFieldFromText(raw, labels: ["法定代表人", "经营者", "负责人"])
        info.address = extractBizAddressFromText(raw)
        info.registeredCapital = extractFieldFromText(raw, labels: ["注册资本"])
        info.establishDate = extractFieldFromText(raw, labels: ["成立日期"])
        info.businessScope = extractFieldFromText(raw, labels: ["经营范围"])
        return info
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Spatial Extraction Helpers
    // ═══════════════════════════════════════════════════════════════════

    /// Find a label block and extract the value from the same block (after label) or adjacent blocks.
    private static func extractFieldAfterLabel(_ blocks: [TextBlock], labels: [String], raw: String) -> String {
        // Strategy 1: Find label in a block, extract value after label in same block
        for block in blocks {
            for label in labels {
                if let range = block.text.range(of: label) {
                    let after = String(block.text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if after.count >= 2 { return after }
                }
            }
        }
        // Strategy 2: Find label block, look for value in blocks below it
        for block in blocks {
            for label in labels {
                if block.text.contains(label) {
                    // Find blocks that are below this label block and close in X position
                    let candidates = blocks.filter { b in
                        b.centerY < block.centerY - 0.02 && // below
                        abs(b.centerX - block.centerX) < 0.3 && // similar X
                        b.text != block.text
                    }.sorted { $0.centerY > $1.centerY } // closest first (Vision Y is bottom-up)
                    if let closest = candidates.first {
                        let cleaned = closest.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if cleaned.count >= 2 { return cleaned }
                    }
                }
            }
        }
        // Strategy 3: Fallback to raw text search
        return extractFieldFromText(raw, labels: labels)
    }

    /// Extract business name using spatial analysis.
    private static func extractBizNameFromBlocks(_ blocks: [TextBlock], raw: String, creditCode: String) -> String {
        // Strategy 1: Find block containing "称" (OCR often drops "名")
        for block in blocks {
            if block.text.hasPrefix("称") || block.text.contains("名称") || block.text.contains("企业名称") {
                var after = block.text
                for label in ["企业名称", "公司名称", "名称", "称"] {
                    if let r = after.range(of: label) { after = String(after[r.upperBound...]); break }
                }
                let cleaned = after.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count >= 2 && !cleaned.contains("类型") { return cleaned }
            }
        }

        // Strategy 2: Find "称" block, look for value in blocks nearby (below or right)
        for block in blocks {
            if block.text.trimmingCharacters(in: .whitespaces) == "称" || block.text.hasPrefix("称 ") {
                // Look for nearby blocks with CJK content
                let candidates = blocks.filter { b in
                    b.text != block.text &&
                    !b.text.contains("类型") &&
                    !b.text.contains("法定代表") &&
                    !b.text.contains("注册资本") &&
                    b.text.unicodeScalars.filter({ $0.value >= 0x4E00 && $0.value <= 0x9FFF }).count >= 2
                }.sorted { b1, b2 in
                    // Sort by distance to the "称" block
                    let d1 = hypot(b1.centerX - block.centerX, b1.centerY - block.centerY)
                    let d2 = hypot(b2.centerX - block.centerX, b2.centerY - block.centerY)
                    return d1 < d2
                }
                if let closest = candidates.first {
                    let cleaned = closest.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.count >= 2 && cleaned.count <= 30 { return cleaned }
                }
            }
        }

        // Strategy 3: Fallback to text-based
        return extractBizNameFromText(raw, creditCode: creditCode)
    }

    /// Extract address from "住所" label, with spatial awareness.
    private static func extractBizAddressFromBlocks(_ blocks: [TextBlock], raw: String) -> String {
        // Find "住所" block
        for block in blocks {
            if block.text.contains("住所") || block.text.contains("经营场所") || block.text.contains("营业场所") {
                // Extract text after label in same block
                var after = block.text
                for label in ["经营场所", "营业场所", "住所"] {
                    if let r = after.range(of: label) { after = String(after[r.upperBound...]); break }
                }
                let cleaned = after.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count >= 3 { return cleaned }
                
                // Look for blocks below this one
                let below = blocks.filter { b in
                    b.centerY < block.centerY - 0.01 &&
                    abs(b.centerX - block.centerX) < 0.4 &&
                    b.text != block.text
                }.sorted { $0.centerY > $1.centerY }
                
                var addr = ""
                for b in below {
                    let t = b.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Stop at next field label
                    if t.contains("经营范围") || t.contains("登记机关") || t.contains("成立日期") { break }
                    addr += t
                }
                if addr.count >= 3 { return addr }
            }
        }
        return extractBizAddressFromText(raw)
    }

    /// Extract ID card name from blocks using spatial analysis.
    private static func extractIDNameFromBlocks(_ blocks: [TextBlock], raw: String) -> String {
        // Find "姓名" block
        for block in blocks {
            if block.text.contains("姓名") {
                // Extract text after "姓名" in same block
                if let r = block.text.range(of: "姓名") {
                    let after = String(block.text[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                    let cjk = String(after.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.prefix(4).map { Character($0) })
                    if cjk.count >= 2 { return cjk }
                }
                // Look for blocks nearby
                let candidates = blocks.filter { b in
                    b.text != block.text &&
                    abs(b.centerX - block.centerX) < 0.3 &&
                    b.text.unicodeScalars.filter({ $0.value >= 0x4E00 && $0.value <= 0x9FFF }).count >= 2 &&
                    b.text.count <= 6
                }.sorted { hypot($0.centerX - block.centerX, $0.centerY - block.centerY) < hypot($1.centerX - block.centerX, $1.centerY - block.centerY) }
                if let c = candidates.first { return c.text }
            }
        }
        return extractIDNameFromText(raw)
    }

    /// Extract address from "住址" label blocks.
    private static func extractAddressFromBlocks(_ blocks: [TextBlock], label: String, raw: String = "") -> String {
        for block in blocks {
            if block.text.contains(label) {
                if let r = block.text.range(of: label) {
                    let after = String(block.text[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if after.count >= 3 { return after }
                }
                // Collect blocks below
                let below = blocks.filter { b in
                    b.centerY < block.centerY - 0.01 && abs(b.centerX - block.centerX) < 0.4 && b.text != block.text
                }.sorted { $0.centerY > $1.centerY }
                var addr = ""
                for b in below {
                    let t = b.text.trimmingCharacters(in: .whitespaces)
                    if t.contains("公民") || t.contains("身份") { break }
                    addr += t
                }
                if addr.count >= 3 { return addr }
            }
        }
        return extractAddressFromText(raw, label: label)
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Text-based Fallback Extraction (legacy)
    // ═══════════════════════════════════════════════════════════════════
    private static func findIDNumber(in raw: String) -> String? {
        if let rx = try? NSRegularExpression(pattern: "([1-9]\\d{5}(?:19|20)\\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\\d|3[01])\\d{3}[\\dXx])"),
           let m = rx.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            let id = (raw as NSString).substring(with: m.range(at: 1)).uppercased()
            if validateIDChecksum(id) { return id }
        }
        if let rx = try? NSRegularExpression(pattern: "[1-9]\\d{16}[\\dXx]"),
           let m = rx.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            return (raw as NSString).substring(with: m.range).uppercased()
        }
        return nil
    }

    private static func findGender(in raw: String) -> String? {
        let males = raw.filter { $0 == "男" }.count
        let females = raw.filter { $0 == "女" }.count
        if males == 1 && females == 0 { return "男" }
        if females == 1 && males == 0 { return "女" }
        return nil
    }

    private static func findEthnicity(in raw: String) -> String? {
        if let rx = try? NSRegularExpression(pattern: "民族\\s*[:\\s]*([\\u{4E00}-\\u{9FFF}]+)"),
           let m = rx.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)), m.numberOfRanges > 1 {
            let e = (raw as NSString).substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if e.count >= 1 && e.count <= 5 { return e }
        }
        return nil
    }

    private static func findBirthDate(in raw: String) -> String? {
        if let rx = try? NSRegularExpression(pattern: "((?:19|20)\\d{2}[年.\\-/](?:0[1-9]|1[0-2])[月.\\-/](?:0[1-9]|[12]\\d|3[01])[日]?)"),
           let m = rx.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)), m.numberOfRanges > 1 {
            return (raw as NSString).substring(with: m.range(at: 1))
        }
        return nil
    }

    private static func extractIDNameFromText(_ raw: String) -> String {
        let nextLabels = ["性别", "民族", "出生", "住址", "公民身份"]
        // S1: Find "姓名" and extract until next label
        for label in ["姓名", "牲名", "性名", "娃名"] {
            guard let r = raw.range(of: label) else { continue }
            var endIdx = raw.endIndex
            for nl in nextLabels { if let nr = raw.range(of: nl, range: r.upperBound..<raw.endIndex), nr.lowerBound < endIdx { endIdx = nr.lowerBound } }
            let between = String(raw[r.upperBound..<endIdx])
            let cjk = String(between.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.prefix(4).map { Character($0) })
            if cjk.count >= 2 && cjk.count <= 4 { return cjk }
        }
        return ""
    }

    private static func extractAddressFromText(_ raw: String, label: String) -> String {
        guard let r = raw.range(of: label) else { return "" }
        var endIdx = raw.endIndex
        for stop in ["公民", "身份号码"] { if let sr = raw.range(of: stop, range: r.upperBound..<raw.endIndex), sr.lowerBound < endIdx { endIdx = sr.lowerBound } }
        var segment = String(raw[r.upperBound..<endIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove trailing ID number
        segment = segment.replacingOccurrences(of: "[1-9]\\d{16}[\\dXx]$", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        return segment.count >= 3 ? segment : ""
    }

    private static func extractFieldFromText(_ raw: String, labels: [String]) -> String {
        for label in labels {
            guard let r = raw.range(of: label) else { continue }
            let after = String(raw[r.upperBound...]).prefix(100)
            var result = ""
            for ch in after {
                let cp = ch.unicodeScalars.first!
                if (cp.value >= 0x4E00 && cp.value <= 0x9FFF) || (cp.value >= 0x30 && cp.value <= 0x39) || cp.value == 0x28 || cp.value == 0x29 || cp.value == 0xFF08 || cp.value == 0xFF09 || cp.value == 0x2E {
                    result.append(ch)
                } else if !result.isEmpty { break }
            }
            if result.count >= 2 { return result }
        }
        return ""
    }

    private static func extractBizNameFromText(_ raw: String, creditCode: String) -> String {
        let nextFields = ["类型", "法定代表", "注册资本", "成立日期", "经营范围", "住所", "登记机关"]
        // S1: "名称" label
        for label in ["企业名称", "公司名称", "名称"] {
            guard let lr = raw.range(of: label) else { continue }
            var endIdx = raw.endIndex
            for nf in nextFields { if let nr = raw.range(of: nf, range: lr.upperBound..<raw.endIndex), nr.lowerBound < endIdx { endIdx = nr.lowerBound } }
            let segment = String(raw[lr.upperBound..<endIdx])
            var result = ""
            for ch in segment {
                let cp = ch.unicodeScalars.first!
                if (cp.value >= 0x4E00 && cp.value <= 0x9FFF) || (cp.value >= 0x30 && cp.value <= 0x39) || (cp.value >= 0x41 && cp.value <= 0x5A) || cp.value == 0x28 || cp.value == 0x29 || cp.value == 0xFF08 || cp.value == 0xFF09 { result.append(ch) }
                else if !result.isEmpty { break }
            }
            if result.count >= 2 && !result.contains("类型") { return result }
        }
        // S2: "称" label (OCR drops "名")
        guard let cr = raw.range(of: "称") else { return "" }
        var endIdx = raw.endIndex
        for nf in nextFields { if let nr = raw.range(of: nf, range: cr.upperBound..<raw.endIndex), nr.lowerBound < endIdx { endIdx = nr.lowerBound } }
        let segment = String(raw[cr.upperBound..<endIdx])
        var result = ""
        for ch in segment {
            let cp = ch.unicodeScalars.first!
            if (cp.value >= 0x4E00 && cp.value <= 0x9FFF) || (cp.value >= 0x30 && cp.value <= 0x39) || (cp.value >= 0x41 && cp.value <= 0x5A) || cp.value == 0x28 || cp.value == 0x29 || cp.value == 0xFF08 || cp.value == 0xFF09 { result.append(ch) }
            else if !result.isEmpty { break }
        }
        let skipWords = ["营业执照", "统一社会信用", "名称", "类型", "法定代表", "注册资本", "成立日期", "经营范围", "住所", "登记机关", "中华人民共和国", "工商行政", "信用代码", "副本"]
        if result.count >= 2 && !skipWords.contains(where: { result.contains($0) }) { return result }
        return ""
    }

    private static func extractBizAddressFromText(_ raw: String) -> String {
        for addrLabel in ["住所", "经营场所", "营业场所"] {
            guard let ar = raw.range(of: addrLabel) else { continue }
            var endIdx = raw.endIndex
            for stop in ["经营范围", "登记机关", "成立日期", "营业期限", "国家企业"] {
                if let sr = raw.range(of: stop, range: ar.upperBound..<raw.endIndex), sr.lowerBound < endIdx { endIdx = sr.lowerBound }
            }
            var segment = String(raw[ar.upperBound..<endIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
            var earliestCut = segment.endIndex
            for cutMarker in ["(", "（", "。", "依法", "服务", "不含", "须经"] {
                if let cutRange = segment.range(of: cutMarker), cutRange.lowerBound < earliestCut { earliestCut = cutRange.lowerBound }
            }
            if earliestCut < segment.endIndex { segment = String(segment[segment.startIndex..<earliestCut]) }
            let cleaned = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count >= 3 { return cleaned }
        }
        return ""
    }
}

// MARK: - UIImage Rotation
extension UIImage {
    func rotated(by radians: CGFloat) -> UIImage? {
        var ns = CGRect(origin: .zero, size: self.size).applying(CGAffineTransform(rotationAngle: radians)).size
        ns.width = abs(ns.width); ns.height = abs(ns.height)
        UIGraphicsBeginImageContextWithOptions(ns, false, self.scale)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.translateBy(x: ns.width / 2, y: ns.height / 2)
        ctx.rotate(by: radians)
        self.draw(in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}