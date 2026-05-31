import Foundation

struct Validator {
    static func validatePhoneNumber(_ phone: String) -> (isValid: Bool, message: String) {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
        if cleaned.isEmpty {
            return (false, "电话号码不能为空")
        }
        let phoneRegex = "^1[3-9]\\d{9}$"
        if cleaned.range(of: phoneRegex, options: .regularExpression) == nil {
            return (false, "电话号码格式不正确，应为11位手机号")
        }
        return (true, "")
    }
    
    static func validateIDNumber(_ id: String) -> (isValid: Bool, message: String) {
        let cleaned = id.replacingOccurrences(of: " ", with: "").uppercased()
        if cleaned.isEmpty {
            return (false, "身份证号码不能为空")
        }
        if cleaned.count == 18 {
            let pattern = "^[0-9]{17}[0-9X]$"
            if cleaned.range(of: pattern, options: .regularExpression) == nil {
                return (false, "18位身份证号码格式不正确")
            }
            let weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2]
            let checkCodes = ["1", "0", "X", "9", "8", "7", "6", "5", "4", "3", "2"]
            var sum = 0
            for i in 0..<17 {
                let char = String(cleaned[cleaned.index(cleaned.startIndex, offsetBy: i)])
                if let num = Int(char) {
                    sum += num * weights[i]
                } else {
                    return (false, "身份证号码包含非法字符")
                }
            }
            let expectedCheck = checkCodes[sum % 11]
            let actualCheck = String(cleaned[cleaned.index(cleaned.startIndex, offsetBy: 17)])
            if actualCheck != expectedCheck {
                return (false, "身份证号码校验位不正确")
            }
            return (true, "")
        } else if cleaned.count == 15 {
            let pattern = "^[0-9]{15}$"
            if cleaned.range(of: pattern, options: .regularExpression) == nil {
                return (false, "15位身份证号码格式不正确")
            }
            return (true, "")
        } else {
            return (false, "身份证号码长度应为15位或18位")
        }
    }
    
    static func validateName(_ name: String) -> (isValid: Bool, message: String) {
        let cleaned = name.replacingOccurrences(of: " ", with: "")
        if cleaned.isEmpty {
            return (false, "姓名不能为空")
        }
        if cleaned.count < 2 {
            return (false, "姓名至少2个字符")
        }
        return (true, "")
    }
    
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    static func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
