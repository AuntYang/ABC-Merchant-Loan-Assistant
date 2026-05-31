import Foundation
import UIKit
import SwiftUI

class DocumentViewModel: ObservableObject {
    @Published var selectedImages: [UIImage] = []
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let dataStore = DataStore.shared
    
    func saveImage(_ image: UIImage, for customerId: UUID, documentType: String) -> DocumentItem? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "\u{65E0}\u{6CD5}\u{5904}\u{7406}\u{56FE}\u{7247}"
            return nil
        }
        
        let fileName = "\(documentType)_\(Date().timeIntervalSince1970).jpg"
        let filePath = dataStore.saveFile(data: imageData, customerId: customerId, documentType: documentType, fileName: fileName)
        let thumbnailData = createThumbnail(from: imageData)
        
        return DocumentItem(
            documentType: documentType,
            fileName: fileName,
            filePath: filePath,
            fileData: imageData,
            thumbnailData: thumbnailData
        )
    }
    
    func saveFile(_ data: Data, for customerId: UUID, documentType: String, fileName: String) -> DocumentItem? {
        let filePath = dataStore.saveFile(data: data, customerId: customerId, documentType: documentType, fileName: fileName)
        return DocumentItem(documentType: documentType, fileName: fileName, filePath: filePath, fileData: data)
    }
    
    func addDocument(to customerId: UUID, document: DocumentItem) {
        dataStore.addDocument(to: customerId, document: document)
    }
    
    func deleteDocument(customerId: UUID, documentId: UUID) {
        dataStore.deleteDocument(customerId: customerId, documentId: documentId)
    }
    
    func rotateImage(document: DocumentItem, customerId: UUID) {
        var updatedDoc = document
        updatedDoc.rotationAngle = (updatedDoc.rotationAngle + 90).truncatingRemainder(dividingBy: 360)
        
        if let data = document.fileData, let image = UIImage(data: data) {
            let radians = CGFloat(90 * Double.pi / 180)
            if let rotated = image.rotated(by: radians) {
                updatedDoc.fileData = rotated.jpegData(compressionQuality: 0.8)
                updatedDoc.thumbnailData = createThumbnail(from: updatedDoc.fileData!)
            }
        }
        
        dataStore.updateDocument(customerId: customerId, document: updatedDoc)
    }
    
    func createThumbnail(from imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        let size = CGSize(width: 200, height: 200)
        let ratio = min(size.width / image.size.width, size.height / image.size.height)
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return thumbnail?.jpegData(compressionQuality: 0.5)
    }
}

