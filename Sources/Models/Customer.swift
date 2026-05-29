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
    
    init(
        id: UUID = UUID(),
        name: String = "",
        phone: String = "",
        address: String = "",
        spouseName: String = "",
        spousePhone: String = "",
        gender: String = "",
        spouseGender: String = "",
        idNumber: String = "",
        spouseIdNumber: String = "",
        idExpiry: String = "",
        spouseIdExpiry: String = "",
        businessLicenseType: String = "",
        businessName: String = "",
        businessLegalRepresentative: String = "",
        businessAddress: String = "",
        createdAt: Date = Date(),
        documents: [DocumentItem] = []
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.address = address
        self.spouseName = spouseName
        self.spousePhone = spousePhone
        self.gender = gender
        self.spouseGender = spouseGender
        self.idNumber = idNumber
        self.spouseIdNumber = spouseIdNumber
        self.idExpiry = idExpiry
        self.spouseIdExpiry = spouseIdExpiry
        self.businessLicenseType = businessLicenseType
        self.businessName = businessName
        self.businessLegalRepresentative = businessLegalRepresentative
        self.businessAddress = businessAddress
        self.createdAt = createdAt
        self.documents = documents
    }
}
