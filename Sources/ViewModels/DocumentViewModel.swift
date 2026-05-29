import Foundation
import UIKit
import PhotosUI
import SwiftUI

class DocumentViewModel: ObservableObject {
    @Published var selectedImages: [UIImage] = []
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let dataStore = DataStore.shared
    
    func saveImage(_ image: UIImage, for customerId: UUID, documentType: String) -> DocumentItem? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "无法处理图片"
            return nil
        }
        
        let fileName = "\(documentType)_\(Date().timeIntervalSince1970).jpg"
        let filePath = dataStore.saveFile(data: imageData, customerId: customerId, documentType: documentType, fileName: fileName)
        
        let thumbnail = resizeImage(image, targetSize: CGSize(width: 200, height: 200))
        let thumbnailData = thumbnail?.jpegData(compressionQuality: 0.5)
        
        return DocumentItem(
            documentType: documentType,
            fileName: fileName,
            filePath: filePath,
            fileData: imageData,
            thumbnailData: thumbnailData
        )
    }
    
    func savePDF(_ data: Data, for customerId: UUID, documentType: String, fileName: String) -> DocumentItem? {
        let filePath = dataStore.saveFile(data: data, customerId: customerId, documentType: documentType, fileName: fileName)
        
        return DocumentItem(
            documentType: documentType,
            fileName: fileName,
            filePath: filePath,
            fileData: data
        )
    }
    
    func saveFile(_ data: Data, for customerId: UUID, documentType: String, fileName: String) -> DocumentItem? {
        let filePath = dataStore.saveFile(data: data, customerId: customerId, documentType: documentType, fileName: fileName)
        
        return DocumentItem(
            documentType: documentType,
            fileName: fileName,
            filePath: filePath,
            fileData: data
        )
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
                let thumbnail = resizeImage(rotated, targetSize: CGSize(width: 200, height: 200))
                updatedDoc.thumbnailData = thumbnail?.jpegData(compressionQuality: 0.5)
            }
        }
        
        dataStore.updateDocument(customerId: customerId, document: updatedDoc)
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

extension UIImage {
    func rotated(by radians: CGFloat) -> UIImage? {
        var newSize = CGRect(origin: .zero, size: self.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .size
        newSize.width = abs(newSize.width)
        newSize.height = abs(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        self.draw(in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
