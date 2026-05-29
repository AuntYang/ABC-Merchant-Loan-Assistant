import Vision
import UIKit

struct OCRHelper {
    static func recognizeText(from image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                completion(nil)
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            completion(recognizedStrings.joined(separator: "\n"))
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("OCR错误: \(error)")
            completion(nil)
        }
    }
    
    static func extractIDCardInfo(from text: String) -> IDCardInfo {
        var info = IDCardInfo()
        
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        
        for line in lines {
            if line.contains("姓名") || line.count <= 5 {
                let name = line.replacingOccurrences(of: "姓名", with: "").trimmingCharacters(in: .whitespaces)
                if !name.isEmpty && info.name.isEmpty {
                    info.name = name
                }
            }
            
            if line.contains("性别") {
                if line.contains("男") {
                    info.gender = "男"
                } else if line.contains("女") {
                    info.gender = "女"
                }
            }
            
            if line.contains("民族") {
                info.ethnicity = line.replacingOccurrences(of: "民族", with: "").trimmingCharacters(in: .whitespaces)
            }
            
            let idPattern = "[0-9]{17}[0-9Xx]"
            if let regex = try? NSRegularExpression(pattern: idPattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                info.idNumber = String(line[Range(match.range, in: line)!]).uppercased()
            }
            
            if line.contains("有效期限") || line.contains("有效期") {
                info.expiry = line.replacingOccurrences(of: "有效期限", with: "")
                    .replacingOccurrences(of: "有效期", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            
            let datePattern = "\\d{4}[.]\\d{2}[.]\\d{2}"
            if let regex = try? NSRegularExpression(pattern: datePattern) {
                let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
                for match in matches {
                    let dateStr = String(line[Range(match.range, in: line)!])
                    if info.expiry.isEmpty {
                        info.expiry = dateStr
                    }
                }
            }
        }
        
        return info
    }
    
    static func extractBusinessLicenseInfo(from text: String) -> BusinessLicenseInfo {
        var info = BusinessLicenseInfo()
        
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        
        for (index, line) in lines.enumerated() {
            if line.contains("名称") && !line.contains("类型") {
                let name = line.replacingOccurrences(of: "名称", with: "").trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    info.name = name
                } else if index + 1 < lines.count {
                    info.name = lines[index + 1]
                }
            }
            
            if line.contains("类型") {
                let type = line.replacingOccurrences(of: "类型", with: "").trimmingCharacters(in: .whitespaces)
                if !type.isEmpty {
                    info.type = type
                } else if index + 1 < lines.count {
                    info.type = lines[index + 1]
                }
            }
            
            if line.contains("法定代表人") || line.contains("经营者") {
                let rep = line.replacingOccurrences(of: "法定代表人", with: "")
                    .replacingOccurrences(of: "经营者", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !rep.isEmpty {
                    info.legalRepresentative = rep
                } else if index + 1 < lines.count {
                    info.legalRepresentative = lines[index + 1]
                }
            }
            
            if line.contains("住所") || line.contains("经营场所") {
                let addr = line.replacingOccurrences(of: "住所", with: "")
                    .replacingOccurrences(of: "经营场所", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !addr.isEmpty {
                    info.address = addr
                } else if index + 1 < lines.count {
                    info.address = lines[index + 1]
                }
            }
        }
        
        return info
    }
}

struct IDCardInfo {
    var name: String = ""
    var gender: String = ""
    var ethnicity: String = ""
    var idNumber: String = ""
    var expiry: String = ""
}

struct BusinessLicenseInfo {
    var name: String = ""
    var type: String = ""
    var legalRepresentative: String = ""
    var address: String = ""
}
