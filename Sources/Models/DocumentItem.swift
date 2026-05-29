import Foundation

struct DocumentItem: Identifiable, Codable {
    var id: UUID
    var documentType: String
    var fileName: String
    var filePath: String
    var fileData: Data?
    var thumbnailData: Data?
    var rotationAngle: Double
    var extractedText: String?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        documentType: String,
        fileName: String = "",
        filePath: String = "",
        fileData: Data? = nil,
        thumbnailData: Data? = nil,
        rotationAngle: Double = 0,
        extractedText: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.documentType = documentType
        self.fileName = fileName
        self.filePath = filePath
        self.fileData = fileData
        self.thumbnailData = thumbnailData
        self.rotationAngle = rotationAngle
        self.extractedText = extractedText
        self.createdAt = createdAt
    }
}
