import UIKit
import PDFKit
import Compression

struct PDFGenerator {

    // MARK: - PDF Page Drawing Helpers

    private static func drawPDFPage(_ page: PDFPage, in context: UIGraphicsPDFRendererContext) {
        let pageBounds = page.bounds(for: .mediaBox)
        let ctx = context.cgContext
        ctx.saveGState()
        ctx.translateBy(x: 0, y: pageBounds.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        page.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()
    }

    private static func drawImageAsPDFPage(_ image: UIImage, in context: UIGraphicsPDFRendererContext) {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        context.beginPage()
        let ratio = min(pageRect.width / image.size.width, pageRect.height / image.size.height)
        let drawW = image.size.width * ratio
        let drawH = image.size.height * ratio
        image.draw(in: CGRect(x: (pageRect.width - drawW) / 2, y: (pageRect.height - drawH) / 2, width: drawW, height: drawH))
    }

    private static func appendDocData(_ data: Data, fileName: String, in context: UIGraphicsPDFRendererContext) {
        if let pdfDoc = PDFDocument(data: data) {
            for i in 0..<pdfDoc.pageCount {
                guard let page = pdfDoc.page(at: i) else { continue }
                context.beginPage()
                drawPDFPage(page, in: context)
            }
        } else if let image = UIImage(data: data) {
            drawImageAsPDFPage(image, in: context)
        }
    }

    // MARK: - Template Placeholder Rendering

    static func fillPlaceholders(in text: String, customer: Customer) -> String {
        var result = text
        let values = customer.autoTemplateValues()
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{" + key + "}}", with: value)
        }
        return result
    }

    private static func extractTextFromDocx(_ data: Data) -> String? {
        let bytes = [UInt8](data)
        guard bytes.count > 4 else { return nil }
        let isZIP = bytes[0] == 0x50 && bytes[1] == 0x4B
        let isOLE2 = bytes.count >= 4 && bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11 && bytes[3] == 0xE0
        if isZIP {
            if let xml = extractXMLFromZip(data, entryName: "word/document.xml") {
                if let text = extractTextFromXMLContent(xml), !text.isEmpty { return text }
            }
            if let sharedXML = extractXMLFromZip(data, entryName: "xl/sharedStrings.xml") {
                let strings = parseXlsxSharedStrings(sharedXML)
                for i in 1...20 {
                    if let sheetXML = extractXMLFromZip(data, entryName: "xl/worksheets/sheet\(i).xml") {
                        let text = parseXlsxSheet(sheetXML, strings: strings)
                        if !text.isEmpty { return text }
                    }
                }
                if !strings.isEmpty { return strings.joined(separator: "\n") }
            }
            return extractTextFromRawXML(data)
        } else if isOLE2 {
            return extractTextFromOLE2(data)
        } else {
            return extractTextFromRawXML(data)
        }
    }

    // MARK: - ZIP Parsing (Robust)

    private static func findEOCD(in bytes: [UInt8]) -> Int? {
        guard bytes.count >= 22 else { return nil }
        var i = bytes.count - 22
        while i >= 0 {
            if bytes[i] == 0x50 && bytes[i+1] == 0x4B && bytes[i+2] == 0x05 && bytes[i+3] == 0x06 {
                return i
            }
            i -= 1
        }
        return nil
    }

    private static func listZipEntries(withPrefix prefix: String, suffix: String, in data: Data) -> [String]? {
        let bytes = [UInt8](data)
        guard let eocd = findEOCD(in: bytes) else { return nil }
        let cdOffset = Int(UInt32(bytes[eocd+16]) | UInt32(bytes[eocd+17]) << 8 | UInt32(bytes[eocd+18]) << 16 | UInt32(bytes[eocd+19]) << 24)
        var offset = cdOffset
        var names: [String] = []
        while offset + 46 <= bytes.count {
            let sig = UInt32(bytes[offset]) | UInt32(bytes[offset+1]) << 8 | UInt32(bytes[offset+2]) << 16 | UInt32(bytes[offset+3]) << 24
            guard sig == 0x02014B45 else { break }
            let nameLen = Int(UInt16(bytes[offset+28]) | UInt16(bytes[offset+29]) << 8)
            let extraLen = Int(UInt16(bytes[offset+30]) | UInt16(bytes[offset+31]) << 8)
            let commentLen = Int(UInt16(bytes[offset+32]) | UInt16(bytes[offset+33]) << 8)
            let nameStart = offset + 46
            guard nameStart + nameLen <= bytes.count else { break }
            let name = String(bytes: bytes[nameStart..<(nameStart + nameLen)], encoding: .utf8) ?? ""
            if name.hasPrefix(prefix) && name.hasSuffix(suffix) {
                names.append(name)
            }
            offset += 46 + nameLen + extraLen + commentLen
        }
        return names.isEmpty ? nil : names
    }

    private static func extractXMLFromZip(_ data: Data, entryName: String) -> String? {
        let bytes = [UInt8](data)
        guard bytes.count > 30 else { return nil }
        guard let eocd = findEOCD(in: bytes) else { return nil }
        let cdOffset = Int(UInt32(bytes[eocd+16]) | UInt32(bytes[eocd+17]) << 8 | UInt32(bytes[eocd+18]) << 16 | UInt32(bytes[eocd+19]) << 24)
        var offset = cdOffset
        while offset + 46 <= bytes.count {
            let sig = UInt32(bytes[offset]) | UInt32(bytes[offset+1]) << 8 | UInt32(bytes[offset+2]) << 16 | UInt32(bytes[offset+3]) << 24
            guard sig == 0x02014B45 else { break }
            let flags = UInt16(bytes[offset+8]) | UInt16(bytes[offset+9]) << 8
            let compMethod = UInt16(bytes[offset+10]) | UInt16(bytes[offset+11]) << 8
            let compSize = Int(UInt32(bytes[offset+20]) | UInt32(bytes[offset+21]) << 8 | UInt32(bytes[offset+22]) << 16 | UInt32(bytes[offset+23]) << 24)
            let uncompSize = Int(UInt32(bytes[offset+24]) | UInt32(bytes[offset+25]) << 8 | UInt32(bytes[offset+26]) << 16 | UInt32(bytes[offset+27]) << 24)
            let nameLen = Int(UInt16(bytes[offset+28]) | UInt16(bytes[offset+29]) << 8)
            let extraLen = Int(UInt16(bytes[offset+30]) | UInt16(bytes[offset+31]) << 8)
            let commentLen = Int(UInt16(bytes[offset+32]) | UInt16(bytes[offset+33]) << 8)
            let localOff = Int(UInt32(bytes[offset+42]) | UInt32(bytes[offset+43]) << 8 | UInt32(bytes[offset+44]) << 16 | UInt32(bytes[offset+45]) << 24)
            let nameStart = offset + 46
            guard nameStart + nameLen <= bytes.count else { break }
            let name = String(bytes: bytes[nameStart..<(nameStart + nameLen)], encoding: .utf8) ?? ""
            if name == entryName {
                guard localOff + 30 <= bytes.count else { return nil }
                let localNameLen = Int(UInt16(bytes[localOff+26]) | UInt16(bytes[localOff+27]) << 8)
                let localExtraLen = Int(UInt16(bytes[localOff+28]) | UInt16(bytes[localOff+29]) << 8)
                let dataStart = localOff + 30 + localNameLen + localExtraLen
                let hasDataDescriptor = (flags & 0x0008) != 0
                let actualCompSize: Int
                if hasDataDescriptor {
                    actualCompSize = compSize > 0 ? compSize : uncompSize
                } else {
                    actualCompSize = compSize
                }
                guard actualCompSize > 0, dataStart + actualCompSize <= bytes.count else { return nil }
                let compData = Data(bytes[dataStart..<(dataStart + actualCompSize)])
                if compMethod == 0 { return String(data: compData, encoding: .utf8) }
                if compMethod == 8 { return inflateRawDeflate(compData) }
                return nil
            }
            offset += 46 + nameLen + extraLen + commentLen
        }
        return nil
    }

    private static func inflateRawDeflate(_ data: Data) -> String? {
        let dstBufSize = max(data.count * 10, 65536)
        var dstBuf = [UInt8](repeating: 0, count: dstBufSize)
        let srcBuf = [UInt8](data)
        let decompressed = data.withUnsafeBytes { (_ srcRaw: UnsafeRawBufferPointer) -> Int in
            guard let srcPtr = srcRaw.baseAddress else { return -1 }
            return dstBuf.withUnsafeMutableBytes { (_ dstRaw: UnsafeMutableRawBufferPointer) -> Int in
                guard let dstPtr = dstRaw.baseAddress else { return -1 }
                var stream = compression_stream()
                var status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
                guard status == COMPRESSION_STATUS_OK else { return -1 }
                defer { compression_stream_destroy(&stream) }
                stream.src_ptr = srcPtr
                stream.src_size = srcBuf.count
                stream.dst_ptr = dstPtr
                stream.dst_size = dstBufSize
                status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                if status == COMPRESSION_STATUS_OK || status == COMPRESSION_STATUS_END {
                    return dstBufSize - stream.dst_size
                }
                return -1
            }
        }
        if decompressed > 0, let str = String(bytes: dstBuf[0..<decompressed], encoding: .utf8) {
            return str
        }
        var wrapped = Data([0x78, 0x9C])
        wrapped.append(data)
        if let result = try? (wrapped as NSData).decompressed(using: .zlib) as Data,
           let str = String(data: result, encoding: .utf8), !str.isEmpty {
            return str
        }
        if let result = try? (data as NSData).decompressed(using: .zlib) as Data,
           let str = String(data: result, encoding: .utf8), !str.isEmpty {
            return str
        }
        if let str = String(data: data, encoding: .utf8), str.contains("<") {
            return str
        }
        return nil
    }

    // MARK: - OLE2 (.et WPS) Support

    private static func extractTextFromOLE2(_ data: Data) -> String? {
        let bytes = [UInt8](data)
        guard bytes.count >= 512,
              bytes[0] == 0xD0, bytes[1] == 0xCF, bytes[2] == 0x11, bytes[3] == 0xE0 else {
            return nil
        }
        let sectorShift = Int(UInt16(bytes[30]) | UInt16(bytes[31]) << 8)
        let sectorSize = 1 << sectorShift
        let firstDirSecID = Int(Int32(bitPattern: UInt32(bytes[48]) | UInt32(bytes[49]) << 8 | UInt32(bytes[50]) << 16 | UInt32(bytes[51]) << 24))
        let firstFATSector = Int(Int32(bitPattern: UInt32(bytes[76]) | UInt32(bytes[77]) << 8 | UInt32(bytes[78]) << 16 | UInt32(bytes[79]) << 24))
        let numFATSectors = Int(UInt32(bytes[72]) | UInt32(bytes[73]) << 8 | UInt32(bytes[74]) << 16 | UInt32(bytes[75]) << 24)
        var fat = [Int32]()
        var currentFATSector = firstFATSector
        for _ in 0..<numFATSectors {
            let secOffset = (currentFATSector + 1) * sectorSize
            guard secOffset + sectorSize <= bytes.count else { break }
            var pos = secOffset
            while pos + 4 <= secOffset + sectorSize {
                let entry = Int32(bitPattern: UInt32(bytes[pos]) | UInt32(bytes[pos+1]) << 8 | UInt32(bytes[pos+2]) << 16 | UInt32(bytes[pos+3]) << 24)
                fat.append(entry)
                pos += 4
            }
            break // simplified: only use first FAT sector
        }
        guard !fat.isEmpty else { return nil }
        func readSectorChain(startSecID: Int) -> Data {
            var result = Data()
            var secID = startSecID
            var visited = Set<Int>()
            while secID >= 0 && secID < fat.count && !visited.contains(secID) {
                visited.insert(secID)
                let offset = (secID + 1) * sectorSize
                guard offset + sectorSize <= bytes.count else { break }
                result.append(contentsOf: bytes[offset..<(offset + sectorSize)])
                secID = Int(fat[secID])
            }
            return result
        }
        let dirData = readSectorChain(startSecID: firstDirSecID)
        var allText: [String] = []
        var entryPos = 0
        while entryPos + 128 <= dirData.count {
            let nameLenBytes = Int(UInt16(dirData[entryPos+64]) | UInt16(dirData[entryPos+65]) << 8)
            let objType = dirData[entryPos+66]
            if objType == 2 && nameLenBytes > 0 && nameLenBytes <= 64 {
                let nameData = dirData[entryPos..<(entryPos + min(nameLenBytes, 64))]
                let name = String(data: nameData, encoding: .utf16LittleEndian)?.trimmingCharacters(in: .controlCharacters) ?? ""
                let childSecID = Int(Int32(bitPattern: UInt32(dirData[entryPos+116]) | UInt32(dirData[entryPos+117]) << 8 | UInt32(dirData[entryPos+118]) << 16 | UInt32(dirData[entryPos+119]) << 24))
                let streamSize = Int(UInt32(dirData[entryPos+120]) | UInt32(dirData[entryPos+121]) << 8 | UInt32(dirData[entryPos+122]) << 16 | UInt32(dirData[entryPos+123]) << 24)
                if streamSize > 0 && childSecID >= 0 {
                    let streamData = readSectorChain(startSecID: childSecID)
                    let actualSize = min(streamSize, streamData.count)
                    let trimmed = streamData.prefix(actualSize)
                    if let text = extractReadableText(from: trimmed) {
                        allText.append(contentsOf: text)
                    }
                }
            }
            entryPos += 128
        }
        return allText.isEmpty ? nil : allText.joined(separator: "\n")
    }

    private static func extractReadableText(from data: Data) -> [String]? {
        var results: [String] = []
        let bytes = [UInt8](data)
        if let str = String(data: data, encoding: .utf8), str.contains("<") {
            if let text = extractTextFromXMLContent(str), !text.isEmpty {
                return text.components(separatedBy: "\n").filter { !$0.isEmpty }
            }
        }
        if let str = String(data: data, encoding: .utf16LittleEndian) {
            let cleaned = str.components(separatedBy: CharacterSet.controlCharacters)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count >= 2 }
            if !cleaned.isEmpty { return cleaned }
        }
        var textStart = -1
        for i in stride(from: 0, to: bytes.count - 1, by: 2) {
            let codeUnit = UInt16(bytes[i]) | UInt16(bytes[i+1]) << 8
            let isPrintable = (codeUnit >= 0x20 && codeUnit < 0x7F) ||
                              (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||
                              (codeUnit >= 0x3000 && codeUnit <= 0x303F) ||
                              (codeUnit >= 0xFF00 && codeUnit <= 0xFFEF)
            if isPrintable {
                if textStart < 0 { textStart = i }
            } else {
                if textStart >= 0 && i - textStart >= 4 {
                    let segData = data[textStart..<i]
                    if let seg = String(data: segData, encoding: .utf16LittleEndian) {
                        let trimmed = seg.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.count >= 2 { results.append(trimmed) }
                    }
                }
                textStart = -1
            }
        }
        if textStart >= 0 && bytes.count - textStart >= 4 {
            let segData = data[textStart..<bytes.count]
            if let seg = String(data: segData, encoding: .utf16LittleEndian) {
                let trimmed = seg.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count >= 2 { results.append(trimmed) }
            }
        }
        return results.isEmpty ? nil : results
    }

    // MARK: - XLSX Parsing

    private static func parseXlsxSharedStrings(_ xml: String) -> [String] {
        var strings: [String] = []
        let components = xml.components(separatedBy: "<si>")
        for comp in components.dropFirst() {
            if let tStart = comp.range(of: "<t"), let tEnd = comp.range(of: "</t>") {
                let afterT = comp[tStart.upperBound...]
                if let closeBracket = afterT.range(of: ">") {
                    let text = String(afterT[closeBracket.upperBound..<tEnd.lowerBound])
                        .replacingOccurrences(of: "&amp;", with: "&")
                        .replacingOccurrences(of: "&lt;", with: "<")
                        .replacingOccurrences(of: "&gt;", with: ">")
                    strings.append(text)
                }
            }
        }
        return strings
    }

    private static func parseXlsxSheet(_ xml: String, strings: [String]) -> String {
        var rows: [Int: [Int: String]] = [:]
        let cellComponents = xml.components(separatedBy: "<c ")
        for comp in cellComponents.dropFirst() {
            guard let rStart = comp.range(of: "r=\""), let rEnd = comp.range(of: "\"", range: rStart.upperBound..<comp.endIndex) else { continue }
            let cellRef = String(comp[rStart.upperBound..<rEnd.lowerBound])
            let colStr = cellRef.prefix(while: { $0.isLetter })
            let rowStr = cellRef.drop(while: { $0.isLetter })
            guard let row = Int(rowStr), let col = colIndex(colStr) else { continue }
            let isShared = comp.contains("t=\"s\"")
            if let vStart = comp.range(of: "<v>"), let vEnd = comp.range(of: "</v>") {
                let value = String(comp[vStart.upperBound..<vEnd.lowerBound])
                if isShared, let idx = Int(value), idx < strings.count {
                    rows[row, default: [:]][col] = strings[idx]
                } else {
                    rows[row, default: [:]][col] = value
                }
            }
            if let isStart = comp.range(of: "<is>"), let isEnd = comp.range(of: "</is>") {
                let isContent = String(comp[isStart.upperBound..<isEnd.lowerBound])
                if let tStart = isContent.range(of: "<t"), let tEnd = isContent.range(of: "</t>") {
                    let afterT = isContent[tStart.upperBound...]
                    if let closeBracket = afterT.range(of: ">") {
                        let text = String(afterT[closeBracket.upperBound..<tEnd.lowerBound])
                        rows[row, default: [:]][col] = text
                    }
                }
            }
        }
        var result: [String] = []
        for row in rows.keys.sorted() {
            let cols = rows[row]!
            let line = cols.keys.sorted().map { cols[$0] ?? "" }.joined(separator: " | ")
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                result.append(line)
            }
        }
        return result.joined(separator: "\n")
    }

    private static func colIndex(_ col: some StringProtocol) -> Int? {
        var idx = 0
        for ch in col.uppercased() {
            guard let v = ch.asciiValue, v >= 65, v <= 90 else { return nil }
            idx = idx * 26 + Int(v - 64)
        }
        return idx - 1
    }

    private static func extractTextFromRawXML(_ data: Data) -> String? {
        let bodyStart = "<w:body".data(using: .utf8)!
        let bodyEnd = "</w:body>".data(using: .utf8)!
        if let sr = data.range(of: bodyStart), let er = data.range(of: bodyEnd, in: sr.lowerBound..<data.count) {
            if let xml = String(data: data.subdata(in: sr.lowerBound..<er.upperBound), encoding: .utf8) {
                return extractTextFromXMLContent(xml)
            }
        }
        let sstStart = "<sst".data(using: .utf8)!
        let sstEnd = "</sst>".data(using: .utf8)!
        if let sr = data.range(of: sstStart), let er = data.range(of: sstEnd, in: sr.lowerBound..<data.count) {
            if let xml = String(data: data.subdata(in: sr.lowerBound..<er.upperBound), encoding: .utf8) {
                let strings = parseXlsxSharedStrings(xml)
                if !strings.isEmpty { return strings.joined(separator: "\n") }
            }
        }
        return nil
    }

    private static func extractTextFromXMLContent(_ xml: String) -> String? {
        var text = xml
        text = text.replacingOccurrences(of: "</w:p>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<w:tab[^>]*/>", with: "    ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<w:br[^>]*/>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#x0A;", with: "\n")
        let lines = text.components(separatedBy: "\n").map { line -> String in
            line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        }
        let result = lines.filter { !$0.isEmpty }.joined(separator: "\n")
        return result.isEmpty ? nil : result
    }

    // MARK: - Text Rendering

    private static func renderTextAsPDFPages(_ text: String, title: String?, in context: UIGraphicsPDFRendererContext) {
        let pageW: CGFloat = 595.2, pageH: CGFloat = 841.8, margin: CGFloat = 40
        let contentW = pageW - margin * 2
        let titleFont = UIFont.boldSystemFont(ofSize: 16)
        let bodyFont = UIFont.systemFont(ofSize: 11)
        let titleHeight: CGFloat = title != nil ? 30 : 0
        let lineHeight: CGFloat = 16
        let lines = text.components(separatedBy: "\n")
        var pageNum = 0
        var lineIdx = 0
        while lineIdx < lines.count || pageNum == 0 {
            context.beginPage()
            pageNum += 1
            var y: CGFloat = margin
            if let t = title, pageNum == 1 {
                (t as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: titleFont])
                y += titleHeight
            }
            let maxY = pageH - margin
            while lineIdx < lines.count && y + lineHeight <= maxY {
                let line = lines[lineIdx] as NSString
                let paraStyle = NSMutableParagraphStyle()
                paraStyle.lineBreakMode = .byWordWrapping
                let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .paragraphStyle: paraStyle]
                let boundingRect = line.boundingRect(with: CGSize(width: contentW, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
                if y + boundingRect.height <= maxY {
                    line.draw(in: CGRect(x: margin, y: y, width: contentW, height: boundingRect.height), withAttributes: attrs)
                    y += boundingRect.height + 2
                } else {
                    break
                }
                lineIdx += 1
            }
        }
    }

    // MARK: - Auto-generated Template Pages

    private static func generateCoverPage(customer: Customer) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            let titleFont = UIFont.boldSystemFont(ofSize: 28)
            let subtitleFont = UIFont.systemFont(ofSize: 18)
            let infoFont = UIFont.systemFont(ofSize: 16)
            let title = "商户贷款资料" as NSString
            let titleSize = title.size(withAttributes: [.font: titleFont])
            title.draw(at: CGPoint(x: (pageRect.width - titleSize.width) / 2, y: 200), withAttributes: [.font: titleFont])
            let subtitle = "封面" as NSString
            let subtitleSize = subtitle.size(withAttributes: [.font: subtitleFont])
            subtitle.draw(at: CGPoint(x: (pageRect.width - subtitleSize.width) / 2, y: 250), withAttributes: [.font: subtitleFont])
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy年MM月dd日"
            dateFormatter.locale = Locale(identifier: "zh_CN")
            let infoLines = [
                "客户姓名：\(customer.name)",
                "建档日期：\(dateFormatter.string(from: customer.createdAt))"
            ]
            var y: CGFloat = 350
            for line in infoLines {
                let nsLine = line as NSString
                nsLine.draw(at: CGPoint(x: 100, y: y), withAttributes: [.font: infoFont])
                y += 40
            }
        }
    }

    private static func generateTOC(customer: Customer) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            let titleFont = UIFont.boldSystemFont(ofSize: 22)
            let checkFont = UIFont.systemFont(ofSize: 12)
            let title = "资料清单目录" as NSString
            let titleSize = title.size(withAttributes: [.font: titleFont])
            title.draw(at: CGPoint(x: (pageRect.width - titleSize.width) / 2, y: 50), withAttributes: [.font: titleFont])
            let customerInfo = "客户：\(customer.name)" as NSString
            customerInfo.draw(at: CGPoint(x: 50, y: 90), withAttributes: [.font: UIFont.systemFont(ofSize: 15)])
            var y: CGFloat = 130
            for docType in DocumentTypeRegistry.allTypes {
                let hasDoc = customer.documents.contains { $0.documentType == docType.id }
                let checkmark = hasDoc ? "☑" : "☐"
                let line = "\(checkmark) \(docType.index). \(docType.name)"
                let nsLine = line as NSString
                nsLine.draw(at: CGPoint(x: 50, y: y), withAttributes: [
                    .font: checkFont,
                    .foregroundColor: hasDoc ? UIColor.black : UIColor.gray
                ])
                y += 22
                if y > 780 {
                    context.beginPage()
                    y = 50
                }
            }
        }
    }

    private static func generateIdentityTable(customer: Customer) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let headerFont = UIFont.boldSystemFont(ofSize: 12)
            let cellFont = UIFont.systemFont(ofSize: 11)
            let title = "个人客户身份识别和尽职调查信息表" as NSString
            let titleSize = title.size(withAttributes: [.font: titleFont])
            title.draw(at: CGPoint(x: (pageRect.width - titleSize.width) / 2, y: 40), withAttributes: [.font: titleFont])
            let tableData: [(String, String, String, String)] = [
                ("客户姓名", customer.name, "配偶姓名", customer.spouseName),
                ("客户性别", customer.gender, "配偶性别", customer.spouseGender),
                ("身份证号", customer.idNumber, "配偶身份证号", customer.spouseIdNumber),
                ("证件有效期", customer.idExpiry, "配偶证件有效期", customer.spouseIdExpiry),
                ("联系电话", customer.phone, "配偶电话", customer.spousePhone),
                ("现住址", customer.address, "", ""),
                ("营业执照类型", customer.businessLicenseType, "", "")
            ]
            var y: CGFloat = 90
            let col1X: CGFloat = 40; let col2X: CGFloat = 160; let col3X: CGFloat = 320; let col4X: CGFloat = 440
            let rowHeight: CGFloat = 35
            for (header1, value1, header2, value2) in tableData {
                let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.darkGray]
                let valueAttrs: [NSAttributedString.Key: Any] = [.font: cellFont]
                (header1 as NSString).draw(at: CGPoint(x: col1X, y: y + 10), withAttributes: headerAttrs)
                (value1 as NSString).draw(at: CGPoint(x: col2X, y: y + 10), withAttributes: valueAttrs)
                if !header2.isEmpty {
                    (header2 as NSString).draw(at: CGPoint(x: col3X, y: y + 10), withAttributes: headerAttrs)
                    (value2 as NSString).draw(at: CGPoint(x: col4X, y: y + 10), withAttributes: valueAttrs)
                }
                let path = UIBezierPath()
                path.move(to: CGPoint(x: col1X, y: y + rowHeight))
                path.addLine(to: CGPoint(x: 555, y: y + rowHeight))
                UIColor.lightGray.setStroke()
                path.stroke()
                y += rowHeight
            }
        }
    }

    private static func generateIncomeTable(customer: Customer) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let headerFont = UIFont.boldSystemFont(ofSize: 12)
            let cellFont = UIFont.systemFont(ofSize: 11)
            let title = "经营收入认定表" as NSString
            let titleSize = title.size(withAttributes: [.font: titleFont])
            title.draw(at: CGPoint(x: (pageRect.width - titleSize.width) / 2, y: 40), withAttributes: [.font: titleFont])
            let rows: [(String, String)] = [
                ("客户姓名", customer.name), ("营业执照名称", customer.businessName),
                ("营业执照类型", customer.businessLicenseType), ("法定代表人", customer.businessLegalRepresentative),
                ("经营地址", customer.businessAddress)
            ]
            var y: CGFloat = 90
            for (label, value) in rows {
                (label as NSString).draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: headerFont])
                (value as NSString).draw(at: CGPoint(x: 180, y: y), withAttributes: [.font: cellFont])
                let p = UIBezierPath(); p.move(to: CGPoint(x: 40, y: y + 25)); p.addLine(to: CGPoint(x: 555, y: y + 25))
                UIColor.lightGray.setStroke(); p.stroke()
                y += 30
            }
        }
    }

    // MARK: - Main PDF Generation

    static func generateFullPDF(customer: Customer) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            // 1. Cover page
            if let coverData = generateCoverPage(customer: customer),
               let coverPage = PDFDocument(data: coverData) {
                for i in 0..<coverPage.pageCount {
                    if let page = coverPage.page(at: i) {
                        context.beginPage()
                        drawPDFPage(page, in: context)
                    }
                }
            }
            // 2. TOC
            if let tocData = generateTOC(customer: customer),
               let tocPage = PDFDocument(data: tocData) {
                for i in 0..<tocPage.pageCount {
                    if let page = tocPage.page(at: i) {
                        context.beginPage()
                        drawPDFPage(page, in: context)
                    }
                }
            }
            // 3. Identity table
            if let tableData = generateIdentityTable(customer: customer),
               let tablePage = PDFDocument(data: tableData) {
                for i in 0..<tablePage.pageCount {
                    if let page = tablePage.page(at: i) {
                        context.beginPage()
                        drawPDFPage(page, in: context)
                    }
                }
            }
            // 4. Income table
            if let incomeData = generateIncomeTable(customer: customer),
               let incomePage = PDFDocument(data: incomeData) {
                for i in 0..<incomePage.pageCount {
                    if let page = incomePage.page(at: i) {
                        context.beginPage()
                        drawPDFPage(page, in: context)
                    }
                }
            }
            // 5. Append ALL customer documents (including imported templates)
            for docItem in customer.documents {
                var dataToAppend: Data? = docItem.fileData
                if dataToAppend == nil && !docItem.filePath.isEmpty {
                    dataToAppend = try? Data(contentsOf: URL(fileURLWithPath: docItem.filePath))
                }
                guard let data = dataToAppend else {
                    renderTextAsPDFPages("[data nil] \(docItem.fileName) type=\(docItem.documentType)", title: "Debug", in: context)
                    continue
                }
                if DocumentTypeRegistry.templateTypes.contains(where: { $0.id == docItem.documentType }) {
                    let extractedText = extractTextFromDocx(data)
                    if let text = extractedText, !text.isEmpty {
                        let filled = fillPlaceholders(in: text, customer: customer)
                        let title = DocumentTypeRegistry.getType(byId: docItem.documentType)?.name
                        renderTextAsPDFPages(filled, title: title, in: context)
                    } else {
                        appendDocData(data, fileName: docItem.fileName, in: context)
                    }
                } else {
                    appendDocData(data, fileName: docItem.fileName, in: context)
                }
            }
        }
    }
}
