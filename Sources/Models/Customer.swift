import Foundation

struct Customer: Identifiable, Codable {
    var id: UUID
    var name: String
    var phone: String
    var address: String
    var spouseName: String
    var spousePhone: String
    var gender: String
    var spouseGender: String
    var idNumber: String
    var spouseIdNumber: String
    var idExpiry: String
    var spouseIdExpiry: String
    var businessLicenseType: String
    var businessName: String
    var businessLegalRepresentative: String
    var businessAddress: String
    var createdAt: Date
    var documents: [DocumentItem]
    var templateValues: [String: String]
    
    init(id: UUID = UUID(), name: String = "", phone: String = "", address: String = "", spouseName: String = "", spousePhone: String = "", gender: String = "", spouseGender: String = "", idNumber: String = "", spouseIdNumber: String = "", idExpiry: String = "", spouseIdExpiry: String = "", businessLicenseType: String = "", businessName: String = "", businessLegalRepresentative: String = "", businessAddress: String = "", createdAt: Date = Date(), documents: [DocumentItem] = [], templateValues: [String: String] = [:]) {
        self.id = id; self.name = name; self.phone = phone; self.address = address
        self.spouseName = spouseName; self.spousePhone = spousePhone; self.gender = gender; self.spouseGender = spouseGender
        self.idNumber = idNumber; self.spouseIdNumber = spouseIdNumber; self.idExpiry = idExpiry; self.spouseIdExpiry = spouseIdExpiry
        self.businessLicenseType = businessLicenseType; self.businessName = businessName
        self.businessLegalRepresentative = businessLegalRepresentative; self.businessAddress = businessAddress
        self.createdAt = createdAt; self.documents = documents; self.templateValues = templateValues
    }
    
    func autoTemplateValues() -> [String: String] {
        var values = templateValues
        values["CustomerName"] = name; values["CustomerPhone"] = phone; values["CustomerAddress"] = address
        values["CustomerGender"] = gender; values["CustomerIdNumber"] = idNumber; values["CustomerIdExpiry"] = idExpiry
        values["SpouseName"] = spouseName; values["SpousePhone"] = spousePhone; values["SpouseGender"] = spouseGender
        values["SpouseIdNumber"] = spouseIdNumber; values["SpouseIdExpiry"] = spouseIdExpiry
        values["BusinessLicenseType"] = businessLicenseType; values["BusinessName"] = businessName
        values["BusinessLegalRepresentative"] = businessLegalRepresentative; values["BusinessAddress"] = businessAddress
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy'年'MM'月'dd'日'"
        formatter.locale = Locale(identifier: "zh_CN")
        values["CurrentDate"] = formatter.string(from: Date())
        values["CreateDate"] = formatter.string(from: createdAt)
        return values
    }
}