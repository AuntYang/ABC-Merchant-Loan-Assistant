import UIKit
import PDFKit
import Compression
import zlib
import WebKit

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
            guard sig == 0x02014B50 else { break }
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
            guard sig == 0x02014B50 else { break }
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
        // Use libz with windowBits=-15 for raw deflate (no zlib header)
        var stream = z_stream()
        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil
        let initResult = inflateInit2_(&stream, -15, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
        guard initResult == Z_OK else { return nil }
        defer { inflateEnd(&stream) }
        
        var srcBytes = [UInt8](data)
        let dstCapacity = max(data.count * 10, 65536)
        var dstBuf = [UInt8](repeating: 0, count: dstCapacity)
        var output = Data()
        
        return srcBytes.withUnsafeMutableBufferPointer { srcBP in
            dstBuf.withUnsafeMutableBufferPointer { dstBP in
                stream.next_in = srcBP.baseAddress!
                stream.avail_in = uInt(srcBP.count)
                
                repeat {
                    stream.next_out = dstBP.baseAddress!
                    stream.avail_out = uInt(dstBP.count)
                    
                    let ret = inflate(&stream, Z_NO_FLUSH)
                    
                    if ret == Z_OK || ret == Z_STREAM_END {
                        let written = dstBP.count - Int(stream.avail_out)
                        if written > 0 {
                            output.append(contentsOf: dstBP[0..<written])
                        }
                    }
                    
                    if ret == Z_STREAM_END { break }
                    if ret != Z_OK { return nil }
                } while stream.avail_out == 0
                
                if let str = String(data: output, encoding: .utf8), !str.isEmpty {
                    return str
                }
                return nil
            }
        }
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



    private static func parseCellRef(_ ref: String) -> (col: Int, row: Int) {
        let colStr = ref.prefix(while: { $0.isLetter })
        let rowStr = ref.drop(while: { $0.isLetter })
        return (colIndex(colStr) ?? 0, Int(rowStr) ?? 0)
    }

    /// Parsed xlsx cell

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


    // MARK: - Cell Reference Parser
    
    private static func parseCellRef(_ ref: String) -> (col: Int, row: Int) {
        let colStr = ref.prefix(while: { $0.isLetter })
        let rowStr = ref.drop(while: { $0.isLetter })
        return (colIndex(colStr) ?? 0, Int(rowStr) ?? 0)
    }
    
    // MARK: - XLSX Placeholder Replacement (Rebuild ZIP from scratch)
    
    private static func replaceXlsxPlaceholders(_ data: Data, customer: Customer) -> Data? {
        let values = customer.autoTemplateValues()
        guard !values.isEmpty else { return data }
        let bytes = [UInt8](data)
        guard bytes.count > 30, bytes[0] == 0x50, bytes[1] == 0x4B else { return nil }
        guard let eocd = findEOCD(in: bytes) else { return nil }
        let cdOffset = Int(UInt32(bytes[eocd+16]) | UInt32(bytes[eocd+17]) << 8 | UInt32(bytes[eocd+18]) << 16 | UInt32(bytes[eocd+19]) << 24)
        let numEntries = Int(UInt16(bytes[eocd+10]) | UInt16(bytes[eocd+11]) << 8)
        
        struct RawEntry {
            let name: String; let compMethod: UInt16; let compSize: Int; let uncompSize: Int
            let localHeaderSize: Int; let localDataStart: Int; let cdNameLen: Int; let cdExtraLen: Int; let cdCommentLen: Int
        }
        var entries: [RawEntry] = []
        var off = cdOffset
        for _ in 0..<numEntries {
            guard off + 46 <= bytes.count else { break }
            let sig = UInt32(bytes[off]) | UInt32(bytes[off+1]) << 8 | UInt32(bytes[off+2]) << 16 | UInt32(bytes[off+3]) << 24
            guard sig == 0x02014B50 else { break }
            let cm = UInt16(bytes[off+10]) | UInt16(bytes[off+11]) << 8
            let cs = Int(UInt32(bytes[off+20]) | UInt32(bytes[off+21]) << 8 | UInt32(bytes[off+22]) << 16 | UInt32(bytes[off+23]) << 24)
            let us = Int(UInt32(bytes[off+24]) | UInt32(bytes[off+25]) << 8 | UInt32(bytes[off+26]) << 16 | UInt32(bytes[off+27]) << 24)
            let nl = Int(UInt16(bytes[off+28]) | UInt16(bytes[off+29]) << 8)
            let el = Int(UInt16(bytes[off+30]) | UInt16(bytes[off+31]) << 8)
            let cl = Int(UInt16(bytes[off+32]) | UInt16(bytes[off+33]) << 8)
            let localOff = Int(UInt32(bytes[off+42]) | UInt32(bytes[off+43]) << 8 | UInt32(bytes[off+44]) << 16 | UInt32(bytes[off+45]) << 24)
            guard localOff + 30 <= bytes.count else { break }
            let lnl = Int(UInt16(bytes[localOff+26]) | UInt16(bytes[localOff+27]) << 8)
            let lel = Int(UInt16(bytes[localOff+28]) | UInt16(bytes[localOff+29]) << 8)
            let nameStart = off + 46
            guard nameStart + nl <= bytes.count else { break }
            let name = String(bytes: bytes[nameStart..<(nameStart + nl)], encoding: .utf8) ?? ""
            entries.append(RawEntry(name: name, compMethod: cm, compSize: cs, uncompSize: us,
                                    localHeaderSize: 30 + lnl + lel, localDataStart: localOff + 30 + lnl + lel,
                                    cdNameLen: nl, cdExtraLen: el, cdCommentLen: cl))
            off += 46 + nl + el + cl
        }
        
        var newZip = Data()
        var newCD = Data()
        var currentOffset = 0
        
        for entry in entries {
            var entryData = Data()
            var newCompSize = entry.compSize
            var newUncompSize = entry.uncompSize
            var newCompMethod = entry.compMethod
            
            if entry.name == "xl/sharedStrings.xml" && entry.compMethod == 8 {
                let src = entry.localDataStart
                guard src + entry.compSize <= bytes.count else { return nil }
                let compData = Data(bytes[src..<(src + entry.compSize)])
                if var xmlStr = inflateRawDeflate(compData) {
                    for (key, value) in values {
                        xmlStr = xmlStr.replacingOccurrences(of: "{{" + key + "}}", with: value)
                    }
                    if let newData = xmlStr.data(using: .utf8) {
                        // Store uncompressed for maximum compatibility
                        newCompSize = newData.count
                        newUncompSize = newData.count
                        newCompMethod = 0
                        var lh = [UInt8](repeating: 0, count: 30)
                        lh[0] = 0x50; lh[1] = 0x4B; lh[2] = 0x03; lh[3] = 0x04
                        lh[4] = 20; lh[5] = 0
                        let nameBytes = [UInt8](entry.name.utf8)
                        lh[26] = UInt8(nameBytes.count & 0xFF); lh[27] = UInt8(nameBytes.count >> 8)
                        lh[18] = UInt8(newCompSize & 0xFF); lh[19] = UInt8((newCompSize >> 8) & 0xFF)
                        lh[20] = UInt8((newCompSize >> 16) & 0xFF); lh[21] = UInt8((newCompSize >> 24) & 0xFF)
                        lh[22] = UInt8(newUncompSize & 0xFF); lh[23] = UInt8((newUncompSize >> 8) & 0xFF)
                        lh[24] = UInt8((newUncompSize >> 16) & 0xFF); lh[25] = UInt8((newUncompSize >> 24) & 0xFF)
                        entryData.append(contentsOf: lh)
                        entryData.append(contentsOf: nameBytes)
                        entryData.append(newData)
                    } else { return nil }
                } else { return nil }
            } else {
                let src = entry.localDataStart - entry.localHeaderSize
                let totalSize = entry.localHeaderSize + entry.compSize
                guard src >= 0 && src + totalSize <= bytes.count else { continue }
                entryData = Data(bytes[src..<(src + totalSize)])
            }
            
            newZip.append(entryData)
            
            var cd = Data()
            cd.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            cd.append(contentsOf: [0x14, 0x00, 0x14, 0x00, 0x00, 0x00])
            cd.append(contentsOf: [UInt8(newCompMethod & 0xFF), UInt8(newCompMethod >> 8)])
            cd.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
            cd.append(contentsOf: [UInt8(newCompSize & 0xFF), UInt8((newCompSize >> 8) & 0xFF), UInt8((newCompSize >> 16) & 0xFF), UInt8((newCompSize >> 24) & 0xFF)])
            cd.append(contentsOf: [UInt8(newUncompSize & 0xFF), UInt8((newUncompSize >> 8) & 0xFF), UInt8((newUncompSize >> 16) & 0xFF), UInt8((newUncompSize >> 24) & 0xFF)])
            let nameBytes = [UInt8](entry.name.utf8)
            cd.append(contentsOf: [UInt8(nameBytes.count & 0xFF), UInt8(nameBytes.count >> 8)])
            cd.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
            cd.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            cd.append(contentsOf: [UInt8(currentOffset & 0xFF), UInt8((currentOffset >> 8) & 0xFF), UInt8((currentOffset >> 16) & 0xFF), UInt8((currentOffset >> 24) & 0xFF)])
            cd.append(contentsOf: nameBytes)
            newCD.append(cd)
            currentOffset += entryData.count
        }
        
        let cdStart = currentOffset
        newZip.append(newCD)
        var eocdBytes = Data()
        eocdBytes.append(contentsOf: [0x50, 0x4B, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00])
        let ne = UInt16(entries.count)
        eocdBytes.append(contentsOf: [UInt8(ne & 0xFF), UInt8(ne >> 8), UInt8(ne & 0xFF), UInt8(ne >> 8)])
        let cdSize = newCD.count
        eocdBytes.append(contentsOf: [UInt8(cdSize & 0xFF), UInt8((cdSize >> 8) & 0xFF), UInt8((cdSize >> 16) & 0xFF), UInt8((cdSize >> 24) & 0xFF)])
        eocdBytes.append(contentsOf: [UInt8(cdStart & 0xFF), UInt8((cdStart >> 8) & 0xFF), UInt8((cdStart >> 16) & 0xFF), UInt8((cdStart >> 24) & 0xFF)])
        eocdBytes.append(contentsOf: [0x00, 0x00])
        newZip.append(eocdBytes)
        return newZip
    }
    
    // MARK: - XLSX to HTML Conversion
    
    private static func convertXlsxToHtml(_ data: Data) -> String? {
        let bytes = [UInt8](data)
        guard bytes.count > 4, bytes[0] == 0x50, bytes[1] == 0x4B else { return nil }
        guard let ssXML = extractXMLFromZip(data, entryName: "xl/sharedStrings.xml") else { return nil }
        let sharedStrings = parseXlsxSharedStrings(ssXML)
        guard let sheetXML = extractXMLFromZip(data, entryName: "xl/worksheets/sheet1.xml") else { return nil }
        
        var fontSizes: [Int: CGFloat] = [:]
        var fontBold: [Int: Bool] = [:]
        var borderDefs: [Int: (Bool, Bool, Bool, Bool)] = [:]
        var cellXfBorder: [Int: Int] = [:]
        var cellXfFont: [Int: Int] = [:]
        var cellXfFill: [Int: Int] = [:]
        var fillColors: [Int: String] = [:]
        
        if let stylesXML = extractXMLFromZip(data, entryName: "xl/styles.xml") {
            for (i, fc) in stylesXML.components(separatedBy: "<font>").dropFirst().enumerated() {
                if let m = fc.range(of: "<sz val=\""), let e = fc.range(of: "\"", range: m.upperBound..<fc.endIndex) {
                    fontSizes[i] = CGFloat(Double(fc[m.upperBound..<e.lowerBound]) ?? 11)
                }
                fontBold[i] = fc.contains("<b/>") || fc.contains("<b ")
            }
            for (i, bc) in stylesXML.components(separatedBy: "<border>").dropFirst().enumerated() {
                borderDefs[i] = (bc.contains("<top style="), bc.contains("<bottom style="), bc.contains("<left style="), bc.contains("<right style="))
            }
            if let xs = stylesXML.range(of: "<cellXfs"), let xe = stylesXML.range(of: "</cellXfs>", range: xs.upperBound..<stylesXML.endIndex) {
                for (i, xc) in String(stylesXML[xs.upperBound..<xe.lowerBound]).components(separatedBy: "<xf ").dropFirst().enumerated() {
                    if let m = xc.range(of: "fontId=\""), let e = xc.range(of: "\"", range: m.upperBound..<xc.endIndex) { cellXfFont[i] = Int(xc[m.upperBound..<e.lowerBound]) ?? 0 }
                    if let m = xc.range(of: "borderId=\""), let e = xc.range(of: "\"", range: m.upperBound..<xc.endIndex) { cellXfBorder[i] = Int(xc[m.upperBound..<e.lowerBound]) ?? 0 }
                    if let m = xc.range(of: "fillId=\""), let e = xc.range(of: "\"", range: m.upperBound..<xc.endIndex) { cellXfFill[i] = Int(xc[m.upperBound..<e.lowerBound]) ?? 0 }
                }
            }
            for (i, fc) in stylesXML.components(separatedBy: "<fill>").dropFirst().enumerated() {
                if let m = fc.range(of: "rgb=\""), let e = fc.range(of: "\"", range: m.upperBound..<fc.endIndex) { fillColors[i] = "#" + String(fc[m.upperBound..<e.lowerBound]).suffix(6) }
            }
        }
        
        var colWidths: [CGFloat] = []
        if let cm = sheetXML.range(of: "<cols>"), let ce = sheetXML.range(of: "</cols>", range: cm.upperBound..<sheetXML.endIndex) {
            var widths: [Int: CGFloat] = [:]
            for cd in String(sheetXML[cm.upperBound..<ce.lowerBound]).components(separatedBy: "<col ").dropFirst() {
                guard let mnR = cd.range(of: "min=\""), let mnE = cd.range(of: "\"", range: mnR.upperBound..<cd.endIndex),
                      let mxR = cd.range(of: "max=\""), let mxE = cd.range(of: "\"", range: mxR.upperBound..<cd.endIndex),
                      let wR = cd.range(of: "width=\""), let wE = cd.range(of: "\"", range: wR.upperBound..<cd.endIndex),
                      let mn = Int(cd[mnR.upperBound..<mnE.lowerBound]), let mx = Int(cd[mxR.upperBound..<mxE.lowerBound]),
                      let w = Double(cd[wR.upperBound..<wE.lowerBound]) else { continue }
                for c in mn...mx { widths[c] = CGFloat(w * 7 + 5) }
            }
            if !widths.isEmpty { let mc = widths.keys.max() ?? 4; colWidths = (1...mc).map { widths[$0] ?? 60 } }
        }
        if colWidths.isEmpty { colWidths = [60, 60, 60, 60] }
        
        var mergeSet = Set<String>()
        var mergeInfo: [String: (Int, Int)] = [:]
        if let mm = sheetXML.range(of: "<mergeCells"), let me = sheetXML.range(of: "</mergeCells>", range: mm.upperBound..<sheetXML.endIndex) {
            for r in String(sheetXML[mm.upperBound..<me.lowerBound]).components(separatedBy: "mergeCell ref=\"").dropFirst() {
                guard let eq = r.range(of: "\"") else { continue }
                let parts = String(r[r.startIndex..<eq.lowerBound]).components(separatedBy: ":")
                guard parts.count == 2 else { continue }
                let (c1, r1) = parseCellRef(parts[0]); let (c2, r2) = parseCellRef(parts[1])
                mergeInfo["\(c1),\(r1)"] = (c2 - c1 + 1, r2 - r1 + 1)
                for mc in c1...c2 { for mr in r1...r2 { if mc != c1 || mr != r1 { mergeSet.insert("\(mc),\(mr)") } } }
            }
        }
        
        struct HtmlCell { let col: Int; let row: Int; let text: String; let styleId: Int }
        var cells: [HtmlCell] = []
        var rowHeights: [Int: CGFloat] = [:]
        
        for rc in sheetXML.components(separatedBy: "<row ").dropFirst() {
            guard let rt = rc.range(of: ">") else { continue }
            let ra = String(rc[rc.startIndex..<rt.lowerBound])
            guard let rm = ra.range(of: "r=\""), let re = ra.range(of: "\"", range: rm.upperBound..<ra.endIndex),
                  let rowNum = Int(ra[rm.upperBound..<re.lowerBound]) else { continue }
            if let hm = ra.range(of: "ht=\""), let he = ra.range(of: "\"", range: hm.upperBound..<ra.endIndex),
               let ht = Double(ra[hm.upperBound..<he.lowerBound]) { rowHeights[rowNum] = CGFloat(ht) }
            
            for cc in rc.components(separatedBy: "<c ").dropFirst() {
                guard let ct = cc.range(of: ">") else { continue }
                let ca = String(cc[cc.startIndex..<ct.lowerBound]); let cb = String(cc[ct.upperBound..<cc.endIndex])
                guard let cr = ca.range(of: "r=\""), let cre = ca.range(of: "\"", range: cr.upperBound..<ca.endIndex) else { continue }
                let (col, _) = parseCellRef(String(ca[cr.upperBound..<cre.lowerBound]))
                var sid = 0
                if let sm = ca.range(of: "s=\""), let se = ca.range(of: "\"", range: sm.upperBound..<ca.endIndex) { sid = Int(ca[sm.upperBound..<se.lowerBound]) ?? 0 }
                let isShared = ca.contains("t=\"s\"")
                var text = ""
                if let vs = cb.range(of: "<v>"), let ve = cb.range(of: "</v>") {
                    let val = String(cb[vs.upperBound..<ve.lowerBound])
                    if isShared, let idx = Int(val), idx < sharedStrings.count { text = sharedStrings[idx] } else { text = val }
                } else if let is = cb.range(of: "<is>"), let ie = cb.range(of: "</is>") {
                    let isc = String(cb[is.upperBound..<ie.lowerBound])
                    if let ts = isc.range(of: "<t"), let te = isc.range(of: "</t>") {
                        let at = isc[ts.upperBound...]; if let gt = at.range(of: ">") { text = String(at[gt.upperBound..<te.lowerBound]) }
                    }
                }
                cells.append(HtmlCell(col: col, row: rowNum, text: text, styleId: sid))
            }
        }
        
        var html = "<!DOCTYPE html><html><head><meta charset='utf-8'><style>"
        html += "body{margin:0;padding:10px;font-family:'SimSun','Songti SC',serif;font-size:11px;}"
        html += "table{border-collapse:collapse;table-layout:fixed;}"
        html += "td{padding:2px 4px;vertical-align:middle;word-wrap:break-word;overflow:hidden;}"
        html += "</style></head><body><table><colgroup>"
        for w in colWidths { html += "<col style='width:\(w)px'>" }
        html += "</colgroup>"
        
        var cellMap: [String: HtmlCell] = [:]
        for c in cells { cellMap["\(c.col),\(c.row)"] = c }
        let maxRow = cells.map { $0.row }.max() ?? 1
        let maxCol = colWidths.count
        
        for r in 1...maxRow {
            let rh = rowHeights[r] ?? 20
            html += "<tr style='height:\(rh)px'>"
            for c in 1...maxCol {
                let key = "\(c),\(r)"
                if mergeSet.contains(key) { continue }
                let cell = cellMap[key]; let text = cell?.text ?? ""; let sid = cell?.styleId ?? 0
                let fid = cellXfFont[sid] ?? 0; let bid = cellXfBorder[sid] ?? 0; let fiid = cellXfFill[sid] ?? 0
                let fs = fontSizes[fid] ?? 11; let bold = fontBold[fid] ?? false
                let bd = borderDefs[bid] ?? (false, false, false, false); let bg = fillColors[fiid]
                var style = "font-size:\(fs)px;"
                if bold { style += "font-weight:bold;" }
                if let b = bg, b != "000000" { style += "background-color:\(b);" }
                if bd.0 { style += "border-top:1px solid #000;" }; if bd.1 { style += "border-bottom:1px solid #000;" }
                if bd.2 { style += "border-left:1px solid #000;" }; if bd.3 { style += "border-right:1px solid #000;" }
                var attrs = ""
                if let mg = mergeInfo[key] {
                    if mg.0 > 1 { attrs += " colspan='\(mg.0)'" }
                    if mg.1 > 1 { attrs += " rowspan='\(mg.1)'" }
                }
                let esc = text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\n", with: "<br>")
                html += "<td\(attrs) style='\(style)'>\(esc)</td>"
            }
            html += "</tr>"
        }
        html += "</table></body></html>"
        return html
    }
    
    // MARK: - HTML to PDF via WebKit
    
    private static func renderHtmlToPdf(_ html: String, pageWidth: CGFloat = 595.2, pageHeight: CGFloat = 841.8) -> Data? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Data?
        DispatchQueue.main.async {
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight * 3))
            webView.loadHTMLString(html, baseURL: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                let renderer = UIPrintPageRenderer()
                renderer.addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)
                let rect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
                renderer.setValue(NSValue(cgRect: rect), forKey: "paperRect")
                renderer.setValue(NSValue(cgRect: rect), forKey: "printableRect")
                let data = NSMutableData()
                UIGraphicsBeginPDFContextToData(data, rect, nil)
                for i in 0..<renderer.numberOfPages {
                    UIGraphicsBeginPDFPage()
                    renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
                }
                UIGraphicsEndPDFContext()
                result = data as Data
                semaphore.signal()
            }
        }
        _ = semaphore.wait(timeout: .now() + 30)
        return result
    }

    // MARK: - Main PDF Generation
    
    static func generateFullPDF(customer: Customer) -> Data? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595.2, height: 841.8))
        return renderer.pdfData { context in
            if let d = generateCoverPage(customer: customer), let doc = PDFDocument(data: d) {
                for i in 0..<doc.pageCount { if let page = doc.page(at: i) { context.beginPage(); drawPDFPage(page, in: context) } }
            }
            if let d = generateTOC(customer: customer), let doc = PDFDocument(data: d) {
                for i in 0..<doc.pageCount { if let page = doc.page(at: i) { context.beginPage(); drawPDFPage(page, in: context) } }
            }
            if let d = generateIdentityTable(customer: customer), let doc = PDFDocument(data: d) {
                for i in 0..<doc.pageCount { if let page = doc.page(at: i) { context.beginPage(); drawPDFPage(page, in: context) } }
            }
            if let d = generateIncomeTable(customer: customer), let doc = PDFDocument(data: d) {
                for i in 0..<doc.pageCount { if let page = doc.page(at: i) { context.beginPage(); drawPDFPage(page, in: context) } }
            }
            
            var debugLines: [String] = []
            debugLines.append("Total documents: \(customer.documents.count)")
            
            for docItem in customer.documents {
                var dataToAppend: Data? = docItem.fileData
                if dataToAppend == nil && !docItem.filePath.isEmpty {
                    dataToAppend = try? Data(contentsOf: URL(fileURLWithPath: docItem.filePath))
                }
                guard let data = dataToAppend else { debugLines.append("[NIL] \(docItem.fileName)"); continue }
                
                let isTemplate = DocumentTypeRegistry.templateTypes.contains(where: { $0.id == docItem.documentType })
                debugLines.append("\(isTemplate ? "[TPL]" : "[DOC]") \(docItem.fileName) size=\(data.count)")
                
                if isTemplate {
                    let isXlsx = data.count > 4 && data[0] == 0x50 && data[1] == 0x4B
                    if isXlsx {
                        let modifiedData = replaceXlsxPlaceholders(data, customer: customer) ?? data
                        debugLines.append("  -> ZIP: \(modifiedData.count) bytes")
                        if let html = convertXlsxToHtml(modifiedData) {
                            debugLines.append("  -> HTML: \(html.count) chars")
                            if let pdfData = renderHtmlToPdf(html), let pdfDoc = PDFDocument(data: pdfData) {
                                for i in 0..<pdfDoc.pageCount { if let page = pdfDoc.page(at: i) { context.beginPage(); drawPDFPage(page, in: context) } }
                                debugLines.append("  -> OK: \(pdfDoc.pageCount) pages")
                            } else {
                                debugLines.append("  -> HTML->PDF FAILED")
                                if let ss = extractXMLFromZip(data, entryName: "xl/sharedStrings.xml") {
                                    let text = parseXlsxSharedStrings(ss).joined(separator: "\n")
                                    if !text.isEmpty { renderTextAsPDFPages(fillPlaceholders(in: text, customer: customer), title: nil, in: context) }
                                }
                            }
                        } else {
                            debugLines.append("  -> HTML FAILED")
                            if let ss = extractXMLFromZip(data, entryName: "xl/sharedStrings.xml") {
                                let text = parseXlsxSharedStrings(ss).joined(separator: "\n")
                                if !text.isEmpty { renderTextAsPDFPages(fillPlaceholders(in: text, customer: customer), title: nil, in: context) }
                            }
                        }
                    } else {
                        let extracted = extractTextFromDocx(data)
                        if let text = extracted, !text.isEmpty {
                            let title = DocumentTypeRegistry.getType(byId: docItem.documentType)?.name
                            renderTextAsPDFPages(fillPlaceholders(in: text, customer: customer), title: title, in: context)
                            debugLines.append("  -> OK: \(text.count) chars")
                        } else {
                            debugLines.append("  -> FAILED, raw")
                            appendDocData(data, fileName: docItem.fileName, in: context)
                        }
                    }
                } else {
                    appendDocData(data, fileName: docItem.fileName, in: context)
                }
            }
            
            renderTextAsPDFPages(debugLines.joined(separator: "\n"), title: "Debug Info", in: context)
        }
    }
}
